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

    await _flutterTts.setLanguage('en-GB');
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.42);
    await _flutterTts.awaitSpeakCompletion(true);
    await _selectBritishVoice();

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

  Future<void> _selectBritishVoice() async {
    try {
      final dynamic voices = await _flutterTts.getVoices;
      if (voices is! List) {
        return;
      }

      Map<String, String>? selectedVoice;
      for (final dynamic voice in voices) {
        if (voice is! Map) {
          continue;
        }

        final String locale =
            (voice['locale'] ?? voice['language'] ?? '').toString().toLowerCase();
        final String name = (voice['name'] ?? '').toString().toLowerCase();
        final bool isBritish =
            locale.contains('en-gb') || locale.contains('gb') || name.contains('uk');
        final bool isEnglish = locale.startsWith('en');

        if (isBritish && isEnglish) {
          selectedVoice = <String, String>{
            'name': (voice['name'] ?? '').toString(),
            'locale': (voice['locale'] ?? voice['language'] ?? '').toString(),
          };
          break;
        }
      }

      if (selectedVoice != null) {
        await _flutterTts.setVoice(selectedVoice);
      }
    } catch (_) {
      // Keep default engine voice if the platform does not expose voice metadata.
    }
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
