import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

/// Mic capture for native targets (Android / iOS / desktop) backed by
/// `package:record`. Streams the same raw linear16 PCM the web impl emits so
/// the backend voice agent (Deepgram) sees an identical wire format.
///
/// TTS playback is not implemented here yet — speaking still drives the
/// on-screen GenUI render; spoken responses are a separate follow-up.
abstract interface class VoiceAudioIo {
  /// Starts the mic; [onChunk] receives raw linear16 PCM **bytes** (16 kHz,
  /// mono, little-endian, 2 bytes/sample) ready to send over the wire.
  Future<void> startMic(void Function(List<int> pcm16) onChunk);
  Future<void> stopMic();
  void playTtsPcm(List<int> bytes);
  Future<void> dispose();
}

class VoiceAudioIoImpl implements VoiceAudioIo {
  VoiceAudioIoImpl();

  // Match the backend agent's expected input: 16 kHz mono linear16.
  static const _config = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: 16000,
    numChannels: 1,
    // Tuned for a moving vehicle cabin.
    autoGain: true,
    echoCancel: true,
    noiseSuppress: true,
  );

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _micSub;

  @override
  Future<void> startMic(void Function(List<int> pcm16) onChunk) async {
    // `hasPermission` triggers the runtime RECORD_AUDIO prompt on first use.
    if (!await _recorder.hasPermission()) {
      throw StateError('Microphone permission was denied');
    }
    final stream = await _recorder.startStream(_config);
    // record emits raw little-endian PCM16 bytes — forward them verbatim.
    _micSub = stream.listen(onChunk);
  }

  @override
  Future<void> stopMic() async {
    await _micSub?.cancel();
    _micSub = null;
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
  }

  @override
  void playTtsPcm(List<int> bytes) {
    // TODO(voice): native streaming PCM playback (24 kHz) for spoken responses.
  }

  @override
  Future<void> dispose() async {
    await stopMic();
    await _recorder.dispose();
  }
}

VoiceAudioIo createVoiceAudioIo() => VoiceAudioIoImpl();
