import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:record/record.dart';

/// Mic capture + TTS playback for native targets (Android / iOS / desktop).
///
/// Mic uses `package:record` to stream the same raw linear16 PCM the web impl
/// emits (16 kHz, mono). Playback uses `package:flutter_pcm_sound` to play the
/// agent's streamed TTS (24 kHz, mono, linear16) gaplessly, so the backend
/// voice agent (Deepgram) sees and feeds an identical wire format on every
/// platform.
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

  // The agent's TTS output: 24 kHz mono linear16 (see backend config).
  static const int _ttsRate = 24000;

  // ~100 ms of silence (frames == samples for mono). The PCM engine pulls via a
  // feed callback and stops once its buffer drains; feeding a small silence
  // frame when idle keeps it running so queued TTS plays the instant it lands.
  static const int _silenceFrames = 2400;

  // --- mic (record) -------------------------------------------------------
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

  // --- tts playback (flutter_pcm_sound) -----------------------------------
  // Pending int16 sample values awaiting the next feed callback. Single-isolate
  // access (callback + playTtsPcm both run on the main isolate), so no locking.
  final Queue<int> _pending = Queue<int>();
  bool _playerStarting = false;
  bool _playerReady = false;

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
    if (bytes.isEmpty) return;
    unawaited(_ensurePlayer());

    var pcm = bytes;
    // Strip a 44-byte WAV (RIFF) header if this chunk carries one — the agent's
    // first TTS chunk of a turn is WAV-wrapped, the rest is raw PCM.
    if (pcm.length > 44 &&
        pcm[0] == 0x52 && // 'R'
        pcm[1] == 0x49 && // 'I'
        pcm[2] == 0x46 && // 'F'
        pcm[3] == 0x46) {
      pcm = pcm.sublist(44);
    }
    final even = pcm.length & ~1;
    if (even <= 0) return;
    // Copy to a fresh, aligned buffer, then read host-endian int16 samples
    // (Android/iOS are little-endian, matching the wire format).
    final u8 = Uint8List.fromList(pcm.sublist(0, even));
    _pending.addAll(Int16List.view(u8.buffer));
  }

  Future<void> _ensurePlayer() async {
    if (_playerReady || _playerStarting) return;
    _playerStarting = true;
    try {
      await FlutterPcmSound.setup(sampleRate: _ttsRate, channelCount: 1);
      await FlutterPcmSound.setFeedThreshold(_silenceFrames);
      FlutterPcmSound.setFeedCallback(_onFeed);
      _playerReady = true;
      FlutterPcmSound.start();
    } on Object {
      // Playback is best-effort; the on-screen GenUI render still works without
      // spoken audio. Leave _playerReady false so a later turn can retry.
      _playerStarting = false;
    }
  }

  void _onFeed(int remainingFrames) {
    if (_pending.isEmpty) {
      // Keep the engine alive so the next TTS chunk plays immediately.
      unawaited(
        FlutterPcmSound.feed(
          PcmArrayInt16.fromList(List<int>.filled(_silenceFrames, 0)),
        ),
      );
      return;
    }
    final samples = List<int>.of(_pending);
    _pending.clear();
    unawaited(FlutterPcmSound.feed(PcmArrayInt16.fromList(samples)));
  }

  @override
  Future<void> dispose() async {
    await stopMic();
    _pending.clear();
    if (_playerReady) {
      _playerReady = false;
      FlutterPcmSound.setFeedCallback(null);
      await FlutterPcmSound.release();
    }
    await _recorder.dispose();
  }
}

VoiceAudioIo createVoiceAudioIo() => VoiceAudioIoImpl();
