from __future__ import annotations

import argparse
import math
import tempfile
import time
import urllib.request
from functools import lru_cache
from pathlib import Path
from typing import Any, Optional

import cv2
import numpy as np
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from ultralytics import YOLO


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MODEL = ROOT / "assets" / "models" / "parking_detector_fast.pt"
DEFAULT_VEHICLE_MODEL = ROOT / "yolov8n.pt"

app = FastAPI(title="Shayyek Parking AI Bridge", version="1.2.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

MODEL_PATH = DEFAULT_MODEL
VEHICLE_MODEL_PATH = DEFAULT_VEHICLE_MODEL
CONFIDENCE = 0.25
IOU = 0.45
IMAGE_SIZE = 960


class AnalyzeUrlRequest(BaseModel):
    url: str
    lot_id: str = ""


def _normalize_state(name: str) -> str:
    value = name.strip().lower().replace("_", "-")
    if "empty" in value or "free" in value or "vacant" in value:
        return "free"
    if "occupied" in value or "busy" in value or "taken" in value:
        return "occupied"
    return "unknown"


@lru_cache(maxsize=1)
def _model() -> YOLO:
    if not MODEL_PATH.exists():
        raise RuntimeError(f"Model not found: {MODEL_PATH}")
    return YOLO(str(MODEL_PATH))


@lru_cache(maxsize=1)
def _vehicle_model() -> Optional[YOLO]:
    if not VEHICLE_MODEL_PATH.exists():
        return None
    return YOLO(str(VEHICLE_MODEL_PATH))


def _box_iou(a: list[float], b: list[float]) -> float:
    ax1, ay1, ax2, ay2 = a
    bx1, by1, bx2, by2 = b
    ix1, iy1 = max(ax1, bx1), max(ay1, by1)
    ix2, iy2 = min(ax2, bx2), min(ay2, by2)
    iw, ih = max(0.0, ix2 - ix1), max(0.0, iy2 - iy1)
    inter = iw * ih
    if inter <= 0:
        return 0.0
    area_a = max(0.0, ax2 - ax1) * max(0.0, ay2 - ay1)
    area_b = max(0.0, bx2 - bx1) * max(0.0, by2 - by1)
    return inter / max(area_a + area_b - inter, 1.0)


def _dark_ratio(image: np.ndarray, bbox: list[float]) -> float:
    h, w = image.shape[:2]
    x1, y1, x2, y2 = [int(round(v)) for v in bbox]
    x1, y1 = max(0, x1), max(0, y1)
    x2, y2 = min(w, x2), min(h, y2)
    if x2 <= x1 or y2 <= y1:
        return 0.0
    crop = image[y1:y2, x1:x2]
    gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)
    hsv = cv2.cvtColor(crop, cv2.COLOR_BGR2HSV)
    mask = (gray < 95) | ((hsv[:, :, 1] > 50) & (hsv[:, :, 2] < 235))
    return float(mask.mean())


def _detections_from_result(result: Any, image: np.ndarray) -> list[dict[str, Any]]:
    names = result.names or {}
    detections: list[dict[str, Any]] = []
    if result.boxes is None:
        return detections

    for index, box in enumerate(result.boxes):
        cls_id = int(box.cls.item()) if box.cls is not None else -1
        class_name = str(names.get(cls_id, cls_id))
        xyxy = [float(v) for v in box.xyxy[0].tolist()]
        detections.append(
            {
                "id": f"stall_{index + 1:03d}",
                "state": _normalize_state(class_name),
                "class_id": cls_id,
                "class_name": class_name,
                "confidence": float(box.conf.item()) if box.conf is not None else 0.0,
                "bbox": [round(v, 2) for v in xyxy],
                "center": [
                    round((xyxy[0] + xyxy[2]) / 2, 2),
                    round((xyxy[1] + xyxy[3]) / 2, 2),
                ],
                "dark_ratio": round(_dark_ratio(image, xyxy), 4),
            }
        )
    return detections


def _adaptive_parking_detections(
    image_path: Path,
    image: np.ndarray,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    model = _model()
    h, w = image.shape[:2]
    candidates = [
        (CONFIDENCE, IMAGE_SIZE),
        (0.10, 640),
        (0.05, 640),
        (0.03, 640),
        (0.02, 640),
        (0.015, 640),
        (0.012, 640),
        (0.01, 640),
        (0.008, 640),
    ]
    if min(h, w) >= 550:
        candidates.append((0.005, 640))
    best: list[dict[str, Any]] = []
    best_meta: dict[str, Any] = {"conf": CONFIDENCE, "imgsz": IMAGE_SIZE}

    for conf, imgsz in candidates:
        iou = IOU if conf == CONFIDENCE else max(IOU, 0.70)
        result = model(
            str(image_path),
            conf=conf,
            iou=iou,
            imgsz=imgsz,
            verbose=False,
        )[0]
        detections = _detections_from_result(result, image)
        # Very low confidence may create duplicates on aerial photos. Keep the
        # richest result in the realistic range for a single visible lot.
        if len(detections) > len(best) and len(detections) <= 70:
            best = detections
            best_meta = {"conf": conf, "imgsz": imgsz}

    best.sort(key=lambda item: (item["center"][1], item["center"][0]))
    for index, item in enumerate(best):
        item["id"] = f"stall_{index + 1:03d}"
    return best, best_meta


def _vehicle_boxes(image_path: Path, image: np.ndarray) -> list[list[float]]:
    model = _vehicle_model()
    if model is None:
        return []
    h = image.shape[0]
    try:
        result = model(
            str(image_path),
            conf=0.02,
            iou=0.45,
            imgsz=1280,
            classes=[2, 3, 5, 7],
            verbose=False,
        )[0]
    except Exception:
        return []
    if result.boxes is None:
        return []

    boxes: list[list[float]] = []
    for box in result.boxes:
        xyxy = [float(v) for v in box.xyxy[0].tolist()]
        cy = (xyxy[1] + xyxy[3]) / 2.0
        if cy < h * 0.18:
            continue
        if any(_box_iou(xyxy, other) > 0.30 for other in boxes):
            continue
        boxes.append(xyxy)
    return boxes


def _projection_vehicle_count(image: np.ndarray) -> int:
    h, w = image.shape[:2]
    hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    row_ranges = [
        (int(h * 0.20), int(h * 0.36)),
        (int(h * 0.47), int(h * 0.68)),
        (int(h * 0.67), int(h * 0.86)),
    ]
    total = 0
    for y0, y1 in row_ranges:
        if y1 <= y0:
            continue
        cg = gray[y0:y1]
        ch = hsv[y0:y1]
        mask = ((cg < 95) | ((ch[:, :, 1] > 55) & (ch[:, :, 2] < 235))).astype(
            np.uint8
        )
        col = mask.sum(axis=0)
        smooth = np.convolve(col, np.ones(15) / 15, mode="same")
        threshold = max(8, (y1 - y0) * 0.10)
        active = smooth > threshold
        clusters: list[tuple[int, int]] = []
        start: Optional[int] = None
        for x, value in enumerate(active):
            if value and start is None:
                start = x
            if (not value or x == w - 1) and start is not None:
                end = x if not value else x + 1
                if 15 <= end - start <= 125:
                    clusters.append((start, end))
                start = None

        merged: list[tuple[int, int]] = []
        for cluster in clusters:
            if merged and cluster[0] - merged[-1][1] < 12:
                merged[-1] = (merged[-1][0], cluster[1])
            else:
                merged.append(cluster)
        total += len(merged)
    return total


def _component_vehicle_count(image: np.ndarray) -> int:
    """Estimate visible cars in aerial lots when the slot model misses cars.

    The YOLO slot model is good at finding empty painted spaces but can miss
    small parked vehicles in high aerial photos. This OpenCV fallback counts
    vehicle-shaped colored/dark components inside the parking area and splits
    wide merged components that usually represent two adjacent cars.
    """
    h = image.shape[0]
    hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    mask = (
        ((gray < 125) & (hsv[:, :, 1] > 15))
        | ((hsv[:, :, 1] > 55) & (hsv[:, :, 2] < 245))
    ).astype(np.uint8) * 255

    # Ignore the road/sky margins; parking analysis happens in the lot body.
    mask[: int(h * 0.18), :] = 0
    mask[int(h * 0.90) :, :] = 0
    mask = cv2.morphologyEx(
        mask,
        cv2.MORPH_CLOSE,
        cv2.getStructuringElement(cv2.MORPH_RECT, (21, 7)),
        iterations=1,
    )
    mask = cv2.morphologyEx(
        mask,
        cv2.MORPH_OPEN,
        cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3)),
        iterations=1,
    )

    count = 0
    components = cv2.connectedComponentsWithStats(mask, 8)
    _num, _labels, stats, _centroids = components
    for stat in stats[1:]:
        x, _y, width, height, area = [int(v) for v in stat]
        aspect = height / max(width, 1)
        if x <= 20:
            continue
        if area < 250 or area > 7500:
            continue
        if width < 8 or height < 8 or width > 130 or height > 160:
            continue
        if not 0.30 <= aspect <= 5.0:
            continue
        if height < 18 and area < 700:
            continue

        merged_cars = 1
        if width >= 82 and height >= 55:
            merged_cars = max(1, round(width / 48))
        count += merged_cars

    # Dense aerial rows frequently merge or crop one small car; apply only in
    # busy scenes so small uploads are not over-counted.
    if count >= 18:
        return int(math.ceil(count * 1.05))
    return count


def _append_synthetic_occupied(
    detections: list[dict[str, Any]],
    amount: int,
) -> None:
    if amount <= 0:
        return
    start = len(detections) + 1
    for offset in range(amount):
        detections.append(
            {
                "id": f"stall_{start + offset:03d}",
                "state": "occupied",
                "class_id": 1,
                "class_name": "occupied-visual-estimate",
                "confidence": 0.5,
                "bbox": [],
                "center": [],
                "dark_ratio": 0.0,
                "estimated": True,
            }
        )


def _apply_occupancy_fallback(
    image_path: Path,
    image: np.ndarray,
    detections: list[dict[str, Any]],
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    total = len(detections)
    if total == 0:
        return detections, {
            "vehicle_boxes": 0,
            "projection_count": 0,
            "occupied_estimate": 0,
        }

    vehicle_boxes = _vehicle_boxes(image_path, image)
    projection_count = _projection_vehicle_count(image)
    component_count = _component_vehicle_count(image)

    for item in detections:
        bbox = item["bbox"]
        item["_vehicle_overlap"] = False
        for vehicle in vehicle_boxes:
            cx = (vehicle[0] + vehicle[2]) / 2.0
            cy = (vehicle[1] + vehicle[3]) / 2.0
            inside = bbox[0] <= cx <= bbox[2] and bbox[1] <= cy <= bbox[3]
            if inside or _box_iou(bbox, vehicle) > 0.05:
                item["state"] = "occupied"
                item["class_name"] = "vehicle-overlap"
                item["_vehicle_overlap"] = True
                break

    model_occupied = sum(1 for item in detections if item["state"] == "occupied")
    if total <= 15 and vehicle_boxes:
        occupied_estimate = min(total, len(vehicle_boxes))
        ranked = sorted(
            range(len(detections)),
            key=lambda idx: (
                not bool(detections[idx].get("_vehicle_overlap", False)),
                -float(detections[idx].get("dark_ratio", 0.0)),
                -float(detections[idx].get("confidence", 0.0)),
            ),
        )
        occupied_ids = set(ranked[:occupied_estimate])
        for idx, item in enumerate(detections):
            if idx in occupied_ids:
                item["state"] = "occupied"
                item["class_name"] = "vehicle-overlap"
            else:
                item["state"] = "free"
                item["class_name"] = "space-empty"
    else:
        occupied_estimate = min(
            total,
            max(model_occupied, len(vehicle_boxes), projection_count),
        )

    model_occupied = sum(1 for item in detections if item["state"] == "occupied")
    should_relabel_free_slots = (
        total > 15
        and occupied_estimate > model_occupied
        and (model_occupied / max(total, 1)) < 0.25
    )
    if should_relabel_free_slots:
        ranked = sorted(
            range(len(detections)),
            key=lambda idx: (
                detections[idx]["state"] != "occupied",
                -float(detections[idx].get("dark_ratio", 0.0)),
                -float(detections[idx].get("confidence", 0.0)),
            ),
        )
        for idx in ranked[:occupied_estimate]:
            detections[idx]["state"] = "occupied"
            detections[idx]["class_name"] = "occupied-estimate"
        for idx in ranked[occupied_estimate:]:
            if detections[idx]["state"] != "occupied":
                detections[idx]["state"] = "free"

    for item in detections:
        item.pop("_vehicle_overlap", None)

    occupied_after_slots = sum(
        1 for item in detections if item["state"] == "occupied"
    )
    visual_occupied_estimate = max(occupied_after_slots, component_count)
    synthetic_occupied = 0
    if (
        component_count > occupied_after_slots
        and total >= 35
        and sum(1 for item in detections if item["state"] == "free") >= 20
    ):
        synthetic_occupied = component_count - occupied_after_slots
        _append_synthetic_occupied(detections, synthetic_occupied)

    return detections, {
        "vehicle_boxes": len(vehicle_boxes),
        "projection_count": projection_count,
        "component_count": component_count,
        "occupied_estimate": occupied_estimate,
        "visual_occupied_estimate": visual_occupied_estimate,
        "synthetic_occupied": synthetic_occupied,
    }


def _analyze_image(image_path: Path, lot_id: str = "") -> dict[str, Any]:
    started = time.time()
    image = cv2.imread(str(image_path))
    if image is None:
        raise RuntimeError(f"Unable to read image: {image_path}")

    detections, detector_meta = _adaptive_parking_detections(image_path, image)
    detections, fallback_meta = _apply_occupancy_fallback(
        image_path,
        image,
        detections,
    )

    free = sum(1 for item in detections if item["state"] == "free")
    occupied = sum(1 for item in detections if item["state"] == "occupied")
    unknown = len(detections) - free - occupied
    height, width = image.shape[:2]

    return {
        "ok": True,
        "lot_id": lot_id,
        "model": MODEL_PATH.name,
        "class_names": {0: "space-empty", 1: "space-occupied"},
        "free": free,
        "occupied": occupied,
        "unknown": unknown,
        "total": len(detections),
        "stalls": detections,
        "image_width": width,
        "image_height": height,
        "detector_meta": detector_meta,
        "fallback_meta": fallback_meta,
        "elapsed_ms": round((time.time() - started) * 1000, 1),
    }


@app.get("/health")
def health() -> dict[str, Any]:
    return {
        "ok": True,
        "model_path": str(MODEL_PATH),
        "model_exists": MODEL_PATH.exists(),
        "vehicle_model_path": str(VEHICLE_MODEL_PATH),
        "vehicle_model_exists": VEHICLE_MODEL_PATH.exists(),
        "confidence": CONFIDENCE,
        "iou": IOU,
        "image_size": IMAGE_SIZE,
    }


@app.post("/analyze-parking")
async def analyze_parking(
    image: UploadFile = File(...),
    lot_id: str = Form(""),
) -> dict[str, Any]:
    suffix = Path(image.filename or "upload.jpg").suffix or ".jpg"
    tmp_path: Optional[Path] = None
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            tmp.write(await image.read())
            tmp_path = Path(tmp.name)
        return _analyze_image(tmp_path, lot_id=lot_id)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    finally:
        try:
            if tmp_path is not None:
                tmp_path.unlink(missing_ok=True)
        except Exception:
            pass


@app.post("/analyze-url")
async def analyze_url(payload: AnalyzeUrlRequest) -> dict[str, Any]:
    if not payload.url.strip():
        raise HTTPException(status_code=400, detail="url is required")
    tmp_path: Optional[Path] = None
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as tmp:
            with urllib.request.urlopen(payload.url, timeout=10) as response:
                tmp.write(response.read())
            tmp_path = Path(tmp.name)
        return _analyze_image(tmp_path, lot_id=payload.lot_id)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    finally:
        try:
            if tmp_path is not None:
                tmp_path.unlink(missing_ok=True)
        except Exception:
            pass


def main() -> None:
    global MODEL_PATH, VEHICLE_MODEL_PATH, CONFIDENCE, IOU, IMAGE_SIZE

    parser = argparse.ArgumentParser(description="Run Shayyek parking AI bridge.")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8000)
    parser.add_argument("--model", default=str(DEFAULT_MODEL))
    parser.add_argument("--vehicle-model", default=str(DEFAULT_VEHICLE_MODEL))
    parser.add_argument("--conf", type=float, default=CONFIDENCE)
    parser.add_argument("--iou", type=float, default=IOU)
    parser.add_argument("--imgsz", type=int, default=IMAGE_SIZE)
    args = parser.parse_args()

    MODEL_PATH = Path(args.model).resolve()
    VEHICLE_MODEL_PATH = Path(args.vehicle_model).resolve()
    CONFIDENCE = args.conf
    IOU = args.iou
    IMAGE_SIZE = args.imgsz

    import uvicorn

    uvicorn.run(app, host=args.host, port=args.port)


if __name__ == "__main__":
    main()
