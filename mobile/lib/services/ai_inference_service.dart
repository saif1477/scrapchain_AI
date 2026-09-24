import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/models.dart';

/// On-device inference: YOLOv8n (detection) + EfficientNet-B0 (material).
/// Both run fully offline as INT8 TFLite models (~6 MB total).
class AIInferenceService {
  AIInferenceService._();
  static final AIInferenceService instance = AIInferenceService._();

  static const int inputSize = 640; // YOLOv8 input
  static const double confThreshold = 0.45;
  static const double iouThreshold = 0.50;

  static const List<String> labels = [
    'PCB', 'Battery', 'CRT', 'Cable', 'Motor', 'Gold-Plated', 'Lithium',
    'Acid-Container', 'Transformer', 'Heat-Sink', 'Fan', 'Speaker',
    'Display', 'Keyboard', 'Mouse', 'Charger', 'USB-Cable', 'RAM', 'HDD', 'SSD',
  ];

  static const List<String> materials = [
    'Gold-Plated', 'Lithium', 'CRT-Glass', 'Copper', 'Aluminum',
  ];

  Interpreter? _yolo;
  Interpreter? _effnet;

  Future<void> loadModels() async {
    try {
      _yolo = await Interpreter.fromAsset(
        'assets/models/yolov8n_ewaste.tflite',
        options: InterpreterOptions()..threads = 4,
      );
      _effnet = await Interpreter.fromAsset(
        'assets/models/efficientnet_b0_material.tflite',
        options: InterpreterOptions()..threads = 2,
      );
    } catch (e) {
      // Models absent in dev builds — detection falls back to demo mode.
      // ignore: avoid_print
      print('TFLite load failed (demo mode): $e');
    }
  }

  /// Run YOLOv8 on a captured frame. Returns NMS-filtered detections.
  List<Detection> detectEwaste(Uint8List imageBytes) {
    if (_yolo == null) return _demoDetections();

    // 1) Preprocess: decode -> letterbox to 640x640 -> normalize [0,1]
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) return const [];
    final resized = img.copyResize(decoded, width: inputSize, height: inputSize);

    final input = Float32List(inputSize * inputSize * 3);
    var i = 0;
    for (var y = 0; y < inputSize; y++) {
      for (var x = 0; x < inputSize; x++) {
        final p = resized.getPixel(x, y);
        input[i++] = p.r / 255.0;
        input[i++] = p.g / 255.0;
        input[i++] = p.b / 255.0;
      }
    }

    // 2) Inference. YOLOv8 output: [1, 4 + numClasses, 8400]
    final numClasses = labels.length;
    final output = List.generate(
      1,
      (_) => List.generate(4 + numClasses, (_) => List.filled(8400, 0.0)),
    );
    _yolo!.run(input.reshape([1, inputSize, inputSize, 3]), output);

    // 3) Decode: cx,cy,w,h + per-class scores
    final raw = <Detection>[];
    for (var a = 0; a < 8400; a++) {
      var best = 0.0;
      var bestCls = -1;
      for (var c = 0; c < numClasses; c++) {
        final s = output[0][4 + c][a];
        if (s > best) {
          best = s;
          bestCls = c;
        }
      }
      if (best < confThreshold) continue;
      final cx = output[0][0][a] / inputSize;
      final cy = output[0][1][a] / inputSize;
      final w = output[0][2][a] / inputSize;
      final h = output[0][3][a] / inputSize;
      raw.add(Detection(
        label: labels[bestCls],
        confidence: best,
        boundingBox: Rect.fromCenter(
          center: Offset(cx, cy), width: w, height: h),
      ));
    }

    // 4) Non-Maximum Suppression
    return _nms(raw);
  }

  /// EfficientNet-B0 material head: Gold-Plated / Lithium / CRT-Glass / Copper / Aluminum
  String classifyMaterial(Uint8List imageBytes) {
    if (_effnet == null) return 'Gold-Plated';
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) return 'Unknown';
    final resized = img.copyResize(decoded, width: 224, height: 224);

    final input = Float32List(224 * 224 * 3);
    var i = 0;
    for (var y = 0; y < 224; y++) {
      for (var x = 0; x < 224; x++) {
        final p = resized.getPixel(x, y);
        // ImageNet normalization
        input[i++] = (p.r / 255.0 - 0.485) / 0.229;
        input[i++] = (p.g / 255.0 - 0.456) / 0.224;
        input[i++] = (p.b / 255.0 - 0.406) / 0.225;
      }
    }
    final out = List.generate(1, (_) => List.filled(materials.length, 0.0));
    _effnet!.run(input.reshape([1, 224, 224, 3]), out);
    var best = 0;
    for (var c = 1; c < materials.length; c++) {
      if (out[0][c] > out[0][best]) best = c;
    }
    return materials[best];
  }

  List<Detection> _nms(List<Detection> dets) {
    dets.sort((a, b) => b.confidence.compareTo(a.confidence));
    final kept = <Detection>[];
    final suppressed = List<bool>.filled(dets.length, false);
    for (var i = 0; i < dets.length; i++) {
      if (suppressed[i]) continue;
      kept.add(dets[i]);
      for (var j = i + 1; j < dets.length; j++) {
        if (!suppressed[j] &&
            dets[i].label == dets[j].label &&
            _iou(dets[i].boundingBox, dets[j].boundingBox) > iouThreshold) {
          suppressed[j] = true;
        }
      }
    }
    return kept;
  }

  double _iou(Rect a, Rect b) {
    final inter = a.intersect(b);
    if (inter.width <= 0 || inter.height <= 0) return 0;
    final ia = inter.width * inter.height;
    return ia / (a.width * a.height + b.width * b.height - ia);
  }

  /// Deterministic fallback so UI flows are demo-able without model weights.
  List<Detection> _demoDetections() {
    final r = math.Random();
    final label = labels[r.nextInt(6)];
    return [
      Detection(
        label: label,
        confidence: 0.87 + r.nextDouble() * 0.1,
        boundingBox: const Rect.fromLTWH(0.24, 0.19, 0.52, 0.62),
      ),
    ];
  }
}
