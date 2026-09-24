import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Voice-first UI: STT commands + TTS announcements in 4 languages.
/// Offline STT path: whisper.cpp tiny model via FFI (see voice_ar/).
class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  String language = 'hi'; // hi | mr | ta | bn
  bool _sttReady = false;

  static const Map<String, String> locales = {
    'hi': 'hi-IN',
    'mr': 'mr-IN',
    'ta': 'ta-IN',
    'bn': 'bn-IN',
  };

  /// Voice command -> intent. Covers Hindi/Marathi/Tamil/Bengali + English.
  static const Map<String, String> _intents = {
    // scan
    'scan': 'scan', 'स्कैन': 'scan', 'स्कॅन': 'scan', 'ஸ்கேன்': 'scan', 'স্ক্যান': 'scan',
    // price
    'price': 'price', 'कीमत': 'price', 'भाव': 'price', 'दाम': 'price',
    'விலை': 'price', 'দাম': 'price',
    // recycler
    'recycler': 'recycler', 'रीसायकलर': 'recycler', 'கடை': 'recycler', 'রিসাইক্লার': 'recycler',
    // receipt
    'receipt': 'receipt', 'रसीद': 'receipt', 'पावती': 'receipt', 'ரசீது': 'receipt', 'রসিদ': 'receipt',
  };

  Future<void> init() async {
    _sttReady = await _stt.initialize();
    await _tts.setLanguage(locales[language]!);
    await _tts.setSpeechRate(0.5);
  }

  Future<void> setLanguage(String lang) async {
    language = lang;
    await _tts.setLanguage(locales[lang]!);
  }

  /// Listen for a command; resolves to an intent string
  /// ('scan' | 'price' | 'recycler' | 'receipt' | 'unknown').
  Future<String> listen() async {
    if (!_sttReady) return 'unknown';
    String heard = '';
    await _stt.listen(
      localeId: locales[language],
      onResult: (r) => heard = r.recognizedWords.toLowerCase(),
    );
    await Future<void>.delayed(const Duration(seconds: 4));
    await _stt.stop();
    for (final entry in _intents.entries) {
      if (heard.contains(entry.key.toLowerCase())) return entry.value;
    }
    return 'unknown';
  }

  Future<void> speak(String text) => _tts.speak(text);

  Future<void> announcePrice(String itemHi, double price) => speak(switch (language) {
        'hi' => 'यह $itemHi ₹${price.round()} प्रति किलो है।',
        'mr' => 'हे $itemHi ₹${price.round()} प्रति किलो आहे.',
        'ta' => 'இது $itemHi கிலோவுக்கு ₹${price.round()}.',
        'bn' => 'এই $itemHi প্রতি কেজি ₹${price.round()}।',
        _ => 'This $itemHi is ₹${price.round()} per kg.',
      });

  Future<void> hazardAlert() => speak(switch (language) {
        'hi' => 'सावधान! एसिड कंटेनर। दस्ताने पहनें।',
        'mr' => 'सावधान! ॲसिड कंटेनर. हातमोजे घाला.',
        'ta' => 'எச்சரிக்கை! அமில கொள்கலன். கையுறை அணியவும்.',
        'bn' => 'সাবধান! অ্যাসিড কন্টেইনার। গ্লাভস পরুন।',
        _ => 'Warning! Acid container. Wear gloves.',
      });
}
