import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/ai_inference_service.dart';
import '../services/offline_queue_service.dart';
import '../services/voice_service.dart';
import 'ar_safety_screen.dart';
import 'valuation_screen.dart';

/// Camera-first home: live preview, YOLO overlays, mic button, language picker.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CameraController? _camera;
  List<Detection> _live = const [];
  bool _busy = false;

  static const languages = {'hi': 'हिन्दी', 'mr': 'मराठी', 'ta': 'தமிழ்', 'bn': 'বাংলা'};

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      _camera = CameraController(cams.first, ResolutionPreset.medium,
          enableAudio: false);
      await _camera!.initialize();
      if (mounted) setState(() {});
    } catch (_) {/* emulator without camera — scan button still works */}
  }

  Future<void> _scan() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      List<Detection> dets;
      if (_camera != null && _camera!.value.isInitialized) {
        final shot = await _camera!.takePicture();
        final bytes = await shot.readAsBytes();
        dets = AIInferenceService.instance.detectEwaste(bytes);
      } else {
        dets = AIInferenceService.instance.detectEwaste(Uint8List(0));
      }
      setState(() => _live = dets);
      if (dets.isNotEmpty && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ValuationScreen(detection: dets.first)),
        );
      }
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _voiceCommand() async {
    final intent = await VoiceService.instance.listen();
    if (!mounted) return;
    switch (intent) {
      case 'scan':
      case 'price':
        await _scan();
      case 'recycler':
        await _scan(); // valuation screen shows recyclers
      default:
        await VoiceService.instance.speak('फिर से बोलिए'); // "say again"
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = OfflineQueueService.instance.pendingCount;
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Text('♻️ ScrapChain AI'),
        ]),
        actions: [
          if (pending > 0)
            Chip(
                label: Text('⏳ $pending queued'),
                backgroundColor: Colors.amber.shade900),
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            onSelected: (l) => VoiceService.instance.setLanguage(l),
            itemBuilder: (_) => languages.entries
                .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
          ),
          IconButton(
            icon: const Icon(Icons.warning_amber, color: Colors.orange),
            tooltip: 'AR Safety Mode',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ArSafetyScreen())),
          ),
        ],
      ),
      body: Stack(children: [
        Positioned.fill(
          child: (_camera?.value.isInitialized ?? false)
              ? CameraPreview(_camera!)
              : Container(
                  color: const Color(0xFF0C130C),
                  child: const Center(
                      child: Text('📷 Camera preview',
                          style: TextStyle(color: Colors.white38)))),
        ),
        // Live YOLO bounding boxes
        ..._live.map((d) => LayoutBuilder(builder: (ctx, box) {
              final r = d.boundingBox;
              return Positioned(
                left: r.left * box.maxWidth,
                top: r.top * box.maxHeight,
                width: r.width * box.maxWidth,
                height: r.height * box.maxHeight,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: d.isHazard ? Colors.red : Colors.greenAccent,
                        width: 3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      color: d.isHazard ? Colors.red : Colors.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      child: Text(
                          '${d.label} ${(d.confidence * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ),
                  ),
                ),
              );
            })),
      ]),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton:
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        FloatingActionButton(
          heroTag: 'mic',
          onPressed: _voiceCommand,
          backgroundColor: Colors.amber.shade700,
          child: const Icon(Icons.mic),
        ),
        const SizedBox(width: 24),
        FloatingActionButton.large(
          heroTag: 'scan',
          onPressed: _scan,
          child: _busy
              ? const CircularProgressIndicator(color: Colors.white)
              : const Icon(Icons.center_focus_strong, size: 40),
        ),
      ]),
    );
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }
}
