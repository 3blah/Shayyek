#!/usr/bin/env python3
from pathlib import Path

import torch
from torchvision.models import EfficientNet_V2_S_Weights, efficientnet_v2_s
from ultralytics import YOLO


ROOT = Path(__file__).resolve().parents[2]
MODEL_DIR = ROOT / "assets" / "models"
DETECTOR = MODEL_DIR / "parking_detector_fast.pt"
CLASSIFIER = MODEL_DIR / "parking_slot_classifier_efficientnetv2s.pt"


def verify_detector() -> None:
    model = YOLO(str(DETECTOR))
    print(f"Detector loaded: {DETECTOR.name}")
    print(f"Detector classes: {getattr(model.model, 'names', {})}")


def verify_classifier() -> None:
    checkpoint = torch.load(CLASSIFIER, map_location="cpu", weights_only=True)
    if not isinstance(checkpoint, dict) or "model_state" not in checkpoint:
        raise SystemExit("Classifier checkpoint payload is invalid.")

    class_names = list(checkpoint.get("class_names", []))
    if not class_names:
        raise SystemExit("Classifier checkpoint is missing class_names.")

    weights = EfficientNet_V2_S_Weights.IMAGENET1K_V1
    model = efficientnet_v2_s(weights=weights)
    in_features = model.classifier[1].in_features
    model.classifier[1] = torch.nn.Linear(in_features, len(class_names))
    model.load_state_dict(checkpoint["model_state"])
    model.eval()

    print(f"Classifier loaded: {CLASSIFIER.name}")
    print(f"Classifier classes: {class_names}")


def main() -> None:
    if not DETECTOR.exists():
        raise SystemExit(f"Detector model not found: {DETECTOR}")
    if not CLASSIFIER.exists():
        raise SystemExit(f"Classifier model not found: {CLASSIFIER}")

    verify_detector()
    verify_classifier()
    print("Model verification completed successfully.")


if __name__ == "__main__":
    main()
