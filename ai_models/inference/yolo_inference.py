"""Server-side / edge YOLOv8 inference (verification + dataset bootstrapping)."""
from ultralytics import YOLO


class EwasteDetector:
    def __init__(self, model_path: str = "weights/yolov8n_ewaste.pt"):
        self.model = YOLO(model_path)

    def detect(self, image_path: str, conf: float = 0.45) -> list[dict]:
        results = self.model(image_path, conf=conf)
        detections = []
        for result in results:
            for box in result.boxes:
                x1, y1, x2, y2 = box.xyxy[0].cpu().numpy().tolist()
                detections.append({
                    "label": self.model.names[int(box.cls)],
                    "confidence": float(box.conf),
                    "bbox": [x1, y1, x2, y2],
                })
        return detections


if __name__ == "__main__":
    import json
    import sys

    detector = EwasteDetector()
    path = sys.argv[1] if len(sys.argv) > 1 else "test_images/pcb_sample.jpg"
    print(json.dumps(detector.detect(path), indent=2))
