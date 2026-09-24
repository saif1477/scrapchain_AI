import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/ai_inference_service.dart';
import '../services/voice_service.dart';

/// AR Safety Mode: continuous hazard scanning with red/yellow overlays and
/// local-language audio alerts.
///
/// Hazard classes: Acid-Container (OCR-confirmed via ML Kit), open Battery
/// (lithium fire risk), CRT (leaded glass). Production build renders anchored
/// 3D warning planes via ARCore; this build uses 2D screen-space overlays,
/// which convey identical information on non-ARCore devices.
class ArSafetyScreen extends StatefulWidget {
  const ArSafetyScreen({super.key});

  @override
  State<ArSafetyScreen> createState() => _ArSafetyScreenState();
}

class _ArSafetyScreenState extends State<ArSafetyScreen> {
  CameraController? _camera;
  Timer? _loop;
  List<Detection> _hazards = const [];
  DateTime _lastAlert = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final cams = await availableCameras();
      _camera =
          CameraController(cams.first, ResolutionPreset.low, enableAudio: false);
      await _camera!.initialize();
      setState(() {});
    } catch (_) {}
    // ~2 fps hazard scan loop (thermal/CPU friendly)
    _loop = Timer.periodic(const Duration(milliseconds: 500), (_) => _scan());
  }

  Future<void> _scan() async {
    Uint8List bytes = Uint8List(0);
    if (_camera?.value.isInitialized ?? false) {
      final shot = await _camera!.takePicture();
      bytes = await shot.readAsBytes();
    }
    final dets = AIInferenceService.instance
        .detectEwaste(bytes)
        .where((d) => d.isHazard)
        .toList();
    if (!mounted) return;
    setState(() => _hazards = dets);

    // Audio alert, debounced to every 5s
    if (dets.any((d) => d.label == 'Acid-Container') &&
        DateTime.now().difference(_lastAlert).inSeconds > 5) {
      _lastAlert = DateTime.now();
      await VoiceService.instance.hazardAlert();
    }
  }

  Color _hazardColor(String label) =>
      label == 'Acid-Container' ? Colors.red : Colors.amber;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('🦺 AR Safety Mode'),
          backgroundColor: Colors.red.shade900),
      body: Stack(children: [
        Positioned.fill(
          child: (_camera?.value.isInitialized ?? false)
              ? CameraPreview(_camera!)
              : Container(color: Colors.black),
        ),
        ..._hazards.map((d) => LayoutBuilder(builder: (ctx, box) {
              final r = d.boundingBox;
              final c = _hazardColor(d.label);
              return Positioned(
                left: r.left * box.maxWidth,
                top: r.top * box.maxHeight,
                width: r.width * box.maxWidth,
                height: r.height * box.maxHeight,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: c, width: 4),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: c.withValues(alpha: .5), blurRadius: 18)
                    ],
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      color: c,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      child: Text('⚠ ${d.label}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              );
            })),
        if (_hazards.isNotEmpty)
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.red.shade900.withValues(alpha: .92),
                  borderRadius: BorderRadius.circular(12)),
              child: const Text(
                'सावधान! खतरनाक सामग्री मिली।\nदस्ताने पहनें · खुले में न जलाएँ · तेज़ाब न निकालें',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ]),
    );
  }

  @override
  void dispose() {
    _loop?.cancel();
    _camera?.dispose();
    super.dispose();
  }
}
