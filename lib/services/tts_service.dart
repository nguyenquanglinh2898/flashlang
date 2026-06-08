import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService._();

  static final TtsService instance = TtsService._();

  final FlutterTts _flutterTts = FlutterTts();

  bool _isInitialized = false;
  bool _isSpeaking = false;
  String? _lastSpokenText;

  bool get isSpeaking => _isSpeaking;
  String? get lastSpokenText => _lastSpokenText;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.awaitSpeakCompletion(true);

    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
    });

    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _flutterTts.setCancelHandler(() {
      _isSpeaking = false;
    });

    _flutterTts.setErrorHandler((dynamic _) {
      _isSpeaking = false;
    });

    _isInitialized = true;
  }

  Future<void> speak(String text) async {
    final String normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      return;
    }

    await initialize();

    if (_isSpeaking) {
      await stop();
    }

    _lastSpokenText = normalizedText;
    await _flutterTts.speak(normalizedText);
  }

  Future<void> stop() async {
    await initialize();
    await _flutterTts.stop();
    _isSpeaking = false;
  }
}
