// Selects the platform mic/TTS implementation: the `package:record`-backed
// native impl by default, the WebAudio impl on web.
export 'package:sos_emergency/data/voice_session/voice_audio_io_io.dart'
    if (dart.library.html) 'package:sos_emergency/data/voice_session/voice_audio_io_web.dart';
