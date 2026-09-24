"""EfficientNet-B0 material classifier (5 classes) -> TFLite.

Distinguishes recovery value tiers on cropped detections:
Gold-Plated / Lithium / CRT-Glass / Copper / Aluminum
"""
import tensorflow as tf

IMG = 224
CLASSES = ["Gold-Plated", "Lithium", "CRT-Glass", "Copper", "Aluminum"]

train_ds = tf.keras.utils.image_dataset_from_directory(
    "../datasets/materials/train", image_size=(IMG, IMG), batch_size=32)
val_ds = tf.keras.utils.image_dataset_from_directory(
    "../datasets/materials/val", image_size=(IMG, IMG), batch_size=32)

base = tf.keras.applications.EfficientNetB0(include_top=False, weights="imagenet", pooling="avg")
base.trainable = False  # phase 1: head only

model = tf.keras.Sequential([
    tf.keras.layers.Rescaling(1.0),  # EfficientNet has built-in preprocessing
    base,
    tf.keras.layers.Dropout(0.25),
    tf.keras.layers.Dense(len(CLASSES), activation="softmax"),
])
model.compile(optimizer=tf.keras.optimizers.Adam(1e-3),
              loss="sparse_categorical_crossentropy", metrics=["accuracy"])
model.fit(train_ds, validation_data=val_ds, epochs=10)

# phase 2: fine-tune top blocks
base.trainable = True
for layer in base.layers[:-30]:
    layer.trainable = False
model.compile(optimizer=tf.keras.optimizers.Adam(1e-5),
              loss="sparse_categorical_crossentropy", metrics=["accuracy"])
model.fit(train_ds, validation_data=val_ds, epochs=10)

# Export TFLite (dynamic-range quantized, ~5 MB)
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
open("efficientnet_b0_material.tflite", "wb").write(converter.convert())
print("Exported efficientnet_b0_material.tflite")
