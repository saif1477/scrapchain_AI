import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'screens/home_screen.dart';
import 'services/ai_inference_service.dart';
import 'services/offline_queue_service.dart';
import 'services/voice_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Offline-first storage (receipt queue, cached prices, settings)
  await Hive.initFlutter();
  await OfflineQueueService.instance.init();

  // Load YOLOv8n + EfficientNet-B0 TFLite models (on-device, no network needed)
  await AIInferenceService.instance.loadModels();

  // Voice: STT + TTS in the collector's language
  await VoiceService.instance.init();

  runApp(const ScrapChainApp());
}

class ScrapChainApp extends StatelessWidget {
  const ScrapChainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScrapChain AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF16A34A),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
