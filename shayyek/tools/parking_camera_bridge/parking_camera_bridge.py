#!/usr/bin/env python3
import argparse
import io
import os
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple

import numpy as np
import requests
from PIL import Image

try:
    import firebase_admin
    from firebase_admin import credentials, db
    import torch
    from torchvision import transforms
    from torchvision.models import (
        EfficientNet_V2_S_Weights,
        efficientnet_v2_s,
    )
    from ultralytics import YOLO
except ImportError as exc:  # pragma: no cover - runtime dependency guard
    raise SystemExit(
        "Missing dependency. Install requirements from "
        "tools/parking_camera_bridge/requirements.txt\n"
        f"Original error: {exc}"
    )


ROOT = Path(__file__).resolve().parents[2]
MODEL_DIR = ROOT / "assets" / "models"
DEFAULT_DETECTOR = MODEL_DIR / "parking_detector_fast.pt"
DEFAULT_CLASSIFIER = MODEL_DIR / "parking_slot_classifier_efficientnetv2s.pt"
DEFAULT_DATABASE_URL = "https://smartpasrk-default-rtdb.firebaseio.com"

CLASSIFIER_TO_STATE = {
    "free_parking_space": "free",
    "not_free_parking_space": "occupied",
    "partially_free_parking_space": "occupied",
}
DETECTOR_TO_STATE = {
    "space-empty": "free",
    "space-occupied": "occupied",
}


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run parking occupancy inference on an ESP32 camera stream "
        "and write results to Firebase Realtime Database.",
    )
    parser.add_argument("--camera-id", required=True)
    parser.add_argument("--lot-id", default="")
    parser.add_argument("--camera-base-url", default=os.getenv("CAMERA_BASE_URL", ""))
    parser.add_argument("--snapshot-url", default=os.getenv("CAMERA_SNAPSHOT_URL", ""))
    parser.add_argument("--service-account", default=os.getenv("FIREBASE_SERVICE_ACCOUNT", ""))
    parser.add_argument(
        "--database-url",
        default=os.getenv("FIREBASE_DATABASE_URL", DEFAULT_DATABASE_URL),
    )
    parser.add_argument("--detector-model", default=str(DEFAULT_DETECTOR))
    parser.add_argument("--classifier-model", default=str(DEFAULT_CLASSIFIER))
    parser.add_argument("--loop-seconds", type=float, default=3.0)
    parser.add_argument("--once", action="store_true")
    return parser.parse_args()


@dataclass
class StallResult:
    stall_id: str
    state: str
    confidence: float
    label: str


class DatabaseNode:
    def child(self, key: str) -> "DatabaseNode":
        raise NotImplementedError

    def get(self):
        raise NotImplementedError

    def update(self, payload: Dict) -> None:
        raise NotImplementedError

    def set(self, payload: Dict) -> None:
        raise NotImplementedError


class FirebaseAdminNode(DatabaseNode):
    def __init__(self, ref):
        self._ref = ref

    def child(self, key: str) -> "FirebaseAdminNode":
        return FirebaseAdminNode(self._ref.child(key))

    def get(self):
        return self._ref.get()

    def update(self, payload: Dict) -> None:
        self._ref.update(payload)

    def set(self, payload: Dict) -> None:
        self._ref.set(payload)


class FirebaseRestNode(DatabaseNode):
    def __init__(self, database_url: str, segments: Optional[List[str]] = None):
        self._database_url = database_url.rstrip("/")
        self._segments = segments or []

    def child(self, key: str) -> "FirebaseRestNode":
        return FirebaseRestNode(self._database_url, [*self._segments, key])

    def get(self):
        response = requests.get(self._url(), timeout=20)
        response.raise_for_status()
        return response.json()

    def update(self, payload: Dict) -> None:
        response = requests.patch(self._url(), json=payload, timeout=20)
        response.raise_for_status()

    def set(self, payload: Dict) -> None:
        response = requests.put(self._url(), json=payload, timeout=20)
        response.raise_for_status()

    def _url(self) -> str:
        path = "/".join(segment.strip("/") for segment in self._segments if segment)
        if path:
            return f"{self._database_url}/{path}.json"
        return f"{self._database_url}/.json"


class ParkingCameraBridge:
    def __init__(self, args: argparse.Namespace) -> None:
        self.args = args
        self.root_ref = self._init_database()
        self.detector = YOLO(str(Path(args.detector_model)))
        self.classifier, self.class_names, self.classifier_transform = (
            self._load_classifier(Path(args.classifier_model))
        )

    def _init_database(self) -> DatabaseNode:
        service_account = self.args.service_account.strip() or os.getenv(
            "GOOGLE_APPLICATION_CREDENTIALS", ""
        )
        database_url = self.args.database_url.strip()
        if not database_url:
            raise SystemExit(
                "Provide --database-url or set FIREBASE_DATABASE_URL."
            )

        if service_account:
            if not firebase_admin._apps:
                cred = credentials.Certificate(service_account)
                firebase_admin.initialize_app(cred, {"databaseURL": database_url})
            return FirebaseAdminNode(db.reference("/"))

        return FirebaseRestNode(database_url)

    def _load_classifier(self, model_path: Path):
        checkpoint = torch.load(model_path, map_location="cpu", weights_only=True)
        if not isinstance(checkpoint, dict) or "model_state" not in checkpoint:
            raise SystemExit(
                f"Unexpected classifier payload in {model_path}. "
                "Expected a checkpoint with model_state and class_names."
            )

        class_names = list(checkpoint.get("class_names", []))
        if not class_names:
            raise SystemExit("Classifier checkpoint is missing class_names.")

        weights = EfficientNet_V2_S_Weights.IMAGENET1K_V1
        model = efficientnet_v2_s(weights=weights)
        in_features = model.classifier[1].in_features
        model.classifier[1] = torch.nn.Linear(in_features, len(class_names))
        model.load_state_dict(checkpoint["model_state"])
        model.eval()

        transform = transforms.Compose(
            [
                transforms.Resize((224, 224)),
                transforms.ToTensor(),
                transforms.Normalize(
                    mean=weights.transforms().mean,
                    std=weights.transforms().std,
                ),
            ]
        )
        return model, class_names, transform

    def run(self) -> None:
        while True:
            started_at = time.perf_counter()
            try:
                self.run_once()
            except Exception as exc:  # pragma: no cover - runtime path
                self._write_camera_health(status="degraded", note=str(exc))
                print(f"[bridge] inference failed: {exc}")

            if self.args.once:
                return

            elapsed = time.perf_counter() - started_at
            sleep_for = max(0.5, self.args.loop_seconds - elapsed)
            time.sleep(sleep_for)

    def run_once(self) -> None:
        camera = self._get_camera()
        lot_id = self.args.lot_id.strip() or str(camera.get("lot_id", "")).strip()
        if not lot_id:
            raise RuntimeError("Lot id was not provided and cameras/<id>/lot_id is empty.")

        image = self._fetch_frame(camera)
        stalls = self._get_stalls_for_lot(lot_id)
        if not stalls:
            raise RuntimeError(f"No stalls found for lot {lot_id}.")

        detector_hits = self._detect_spaces(image)
        stall_results = self._infer_stalls(image, stalls, detector_hits)
        fps = 1.0 / max(0.001, self.args.loop_seconds)
        self._write_results(
            camera_id=self.args.camera_id,
            lot_id=lot_id,
            stall_results=stall_results,
            fps=fps,
        )

    def _get_camera(self) -> Dict:
        camera = self.root_ref.child("cameras").child(self.args.camera_id).get()
        if not isinstance(camera, dict):
            raise RuntimeError(f"Camera {self.args.camera_id} was not found in cameras.")
        return camera

    def _fetch_frame(self, camera: Dict) -> Image.Image:
        snapshot_url = self.args.snapshot_url.strip()
        base_url = self.args.camera_base_url.strip()
        if not snapshot_url and base_url:
            snapshot_url = f"{base_url.rstrip('/')}/capture"
        if not snapshot_url:
            stream_field = str(camera.get("rtsp_url", "")).strip()
            if stream_field.startswith("http"):
                snapshot_url = (
                    stream_field
                    if stream_field.endswith("/capture")
                    else f"{stream_field.rstrip('/')}/capture"
                )
        if not snapshot_url:
            raise RuntimeError(
                "No snapshot URL was found. Pass --camera-base-url or --snapshot-url, "
                "or populate cameras/<camera_id>/rtsp_url with the ESP32 base URL."
            )

        response = requests.get(snapshot_url, timeout=15)
        response.raise_for_status()
        return Image.open(io.BytesIO(response.content)).convert("RGB")

    def _get_stalls_for_lot(self, lot_id: str) -> List[Dict]:
        stalls_root = self.root_ref.child("stalls").get() or {}
        results: List[Dict] = []
        for key, raw in stalls_root.items():
            if not isinstance(raw, dict):
                continue
            if str(raw.get("lot_id", "")).strip() != lot_id:
                continue
            results.append({"key": key, **raw})
        return results

    def _detect_spaces(self, image: Image.Image) -> List[Dict]:
        predictions = self.detector.predict(np.array(image), verbose=False)
        if not predictions:
            return []

        result = predictions[0]
        names = result.names if hasattr(result, "names") else {}
        hits: List[Dict] = []
        for box in result.boxes:
            coords = box.xyxy[0].tolist()
            class_id = int(box.cls[0].item())
            confidence = float(box.conf[0].item())
            label = str(names.get(class_id, class_id))
            hits.append(
                {
                    "bbox": coords,
                    "label": label,
                    "state": DETECTOR_TO_STATE.get(label, "occupied"),
                    "confidence": confidence,
                }
            )
        return hits

    def _infer_stalls(
        self,
        image: Image.Image,
        stalls: Iterable[Dict],
        detector_hits: List[Dict],
    ) -> List[StallResult]:
        width, height = image.size
        results: List[StallResult] = []

        for stall in stalls:
            stall_id = str(stall.get("id") or stall.get("key"))
            bbox = self._stall_bbox(stall, width, height)
            crop = image.crop(bbox)
            state, confidence, label = self._classify_crop(crop)

            detector_match = self._match_detector_hit(bbox, detector_hits)
            if detector_match and detector_match["confidence"] >= confidence:
                state = str(detector_match["state"])
                confidence = float(detector_match["confidence"])
                label = str(detector_match["label"])

            results.append(
                StallResult(
                    stall_id=stall_id,
                    state=state,
                    confidence=confidence,
                    label=label,
                )
            )
        return results

    def _stall_bbox(self, stall: Dict, width: int, height: int) -> Tuple[int, int, int, int]:
        polygon = stall.get("polygon") or []
        xs: List[float] = []
        ys: List[float] = []
        for point in polygon:
            if not isinstance(point, dict):
                continue
            px = float(point.get("x", 0))
            py = float(point.get("y", 0))
            xs.append(px * width if 0 <= px <= 1 else px)
            ys.append(py * height if 0 <= py <= 1 else py)

        if not xs or not ys:
            return (0, 0, width, height)

        left = max(0, int(min(xs)))
        top = max(0, int(min(ys)))
        right = min(width, int(max(xs)))
        bottom = min(height, int(max(ys)))
        if right <= left:
            right = min(width, left + 1)
        if bottom <= top:
            bottom = min(height, top + 1)
        return (left, top, right, bottom)

    def _classify_crop(self, crop: Image.Image) -> Tuple[str, float, str]:
        tensor = self.classifier_transform(crop).unsqueeze(0)
        with torch.no_grad():
            logits = self.classifier(tensor)
            probabilities = torch.softmax(logits, dim=1)[0]
        index = int(torch.argmax(probabilities).item())
        label = self.class_names[index]
        confidence = float(probabilities[index].item())
        state = CLASSIFIER_TO_STATE.get(label, "occupied")
        return state, confidence, label

    def _match_detector_hit(
        self,
        bbox: Tuple[int, int, int, int],
        detector_hits: List[Dict],
    ) -> Optional[Dict]:
        left, top, right, bottom = bbox
        cx = (left + right) / 2
        cy = (top + bottom) / 2
        for hit in detector_hits:
            hx1, hy1, hx2, hy2 = hit["bbox"]
            if hx1 <= cx <= hx2 and hy1 <= cy <= hy2:
                return hit
        return None

    def _write_results(
        self,
        camera_id: str,
        lot_id: str,
        stall_results: List[StallResult],
        fps: float,
    ) -> None:
        now = utc_now_iso()
        free_count = sum(1 for item in stall_results if item.state == "free")
        occupied_count = sum(1 for item in stall_results if item.state != "free")

        live_map_ref = self.root_ref.child("live_map").child(lot_id)
        live_map_ref.update(
            {
                "free": free_count,
                "occupied": occupied_count,
                "total": len(stall_results),
                "ts": now,
                "degraded_mode": False,
            }
        )

        for item in stall_results:
            live_map_ref.child("stalls").child(item.stall_id).update(
                {
                    "state": item.state,
                    "last_seen": now,
                    "confidence": round(item.confidence, 4),
                    "confidince": round(item.confidence, 4),
                }
            )
            self.root_ref.child("stalls").child(item.stall_id).update(
                {
                    "state": item.state,
                    "last_seen": now,
                    "last_confidence": round(item.confidence, 4),
                    "update_at": now,
                }
            )

        self._write_camera_health(
            status="online",
            note="inference_ok",
            fps=fps,
            lot_id=lot_id,
            camera_id=camera_id,
        )

    def _write_camera_health(
        self,
        status: str,
        note: str,
        fps: float = 0.0,
        lot_id: str = "",
        camera_id: str = "",
    ) -> None:
        target_camera_id = camera_id or self.args.camera_id
        payload = {
            "id": target_camera_id,
            "status": status,
            "note": note,
            "last_heartbeat": utc_now_iso(),
        }
        if fps > 0:
            payload["fps"] = round(fps, 2)
        if lot_id:
            payload["lot_id"] = lot_id
        self.root_ref.child("CameraHealth").child(target_camera_id).update(payload)


def main() -> None:
    bridge = ParkingCameraBridge(parse_args())
    bridge.run()


if __name__ == "__main__":
    main()
