"""Train YOLOv8n on the Indian e-waste dataset and export TFLite for on-device use.

Dataset: 20 classes, ~24k images (scraped + field-collected + Roboflow e-waste sets,
augmented with Indian scrap-yard conditions: low light, cluttered piles, monsoon glare).

Usage:  python train_yolov8.py            (needs GPU; ~3h on a T4)
Output: runs/detect/train/weights/best.pt  +  yolov8n_ewaste_float16.tflite
"""
from ultralytics import YOLO

model = YOLO("yolov8n.pt")  # COCO-pretrained backbone

results = model.train(
    data="../datasets/ewaste_india_2026.yaml",
    epochs=100,
    imgsz=640,
    batch=16,
    device=0,
    workers=8,
    optimizer="SGD",
    lr0=0.01,
    lrf=0.1,
    momentum=0.937,
    weight_decay=0.0005,
    warmup_epochs=3.0,
    box=7.5,
    cls=0.5,
    dfl=1.5,
    patience=50,
    amp=True,
    # Scrap-yard-specific augmentation
    hsv_h=0.015, hsv_s=0.7, hsv_v=0.5,
    degrees=15, translate=0.15, scale=0.6, fliplr=0.5,
    mosaic=1.0, mixup=0.1,
)

# Validate
metrics = model.val()
print(f"mAP50: {metrics.box.map50:.3f}  mAP50-95: {metrics.box.map:.3f}")

# Export for Flutter (tflite_flutter): float16 ≈ 6 MB, INT8 ≈ 3 MB
model.export(format="tflite", imgsz=640, half=True)
model.export(format="tflite", imgsz=640, int8=True, data="../datasets/ewaste_india_2026.yaml")
