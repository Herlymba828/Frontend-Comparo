import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Voice through the phone's own engines (PJ-025 reading, PJ-026 dictation):
/// no external provider, French by default.
abstract interface class VoiceService {
  /// Reads [text] aloud; a new text stops the previous one.
  Future<void> speak(String text);

  Future<void> stop();

  /// Listens once and returns what was heard, null when nothing was
  /// understood or the microphone is not allowed.
  Future<String?> listen();
}

const voiceLocale = 'fr-FR';

class DeviceVoiceService implements VoiceService {
  DeviceVoiceService();

  final FlutterTts _tts = FlutterTts();
  final SpeechToText _speech = SpeechToText();
  bool _speechReady = false;

  @override
  Future<void> speak(String text) async {
    await _tts.stop();
    await _tts.setLanguage(voiceLocale);
    await _tts.speak(text);
  }

  @override
  Future<void> stop() => _tts.stop();

  @override
  Future<String?> listen() async {
    _speechReady = _speechReady || await _speech.initialize();
    if (!_speechReady) {
      return null;
    }
    String? heard;
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: voiceLocale,
        listenFor: const Duration(seconds: 8),
        pauseFor: const Duration(seconds: 2),
      ),
      onResult: (result) {
        if (result.finalResult) {
          heard = result.recognizedWords;
        }
      },
    );
    // listen() returns at once: wait for the final result or the timeout.
    for (var waited = 0; waited < 100 && _speech.isListening; waited++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await _speech.stop();
    final words = heard?.trim() ?? '';
    return words.isEmpty ? null : words;
  }
}

final voiceServiceProvider = Provider<VoiceService>(
  (ref) => DeviceVoiceService(),
);

/// The text read for a product: its name and best known price, with the
/// same wording as the screen.
String productSpeech(String name, String? priceLabel) => priceLabel == null
    ? '$name. Aucun prix connu pour le moment.'
    : '$name. Meilleur prix connu : $priceLabel.';
