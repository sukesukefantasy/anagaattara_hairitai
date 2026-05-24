import 'package:flutter/foundation.dart';
import 'package:rive_native/rive_audio.dart';
import 'package:rive_native/src/ffi/rive_audio_ffi.dart';

/// 再生中の Rive オーディオをすべて停止する（ネイティブ / デスクトップ）。
void stopAllRivePlaybackAudio() {
  final engines = List<AudioEngine>.from(AudioEngineFFI.lookup.values);
  for (final engine in engines) {
    try {
      engine.stop();
    } catch (e) {
      debugPrint('RiveAudioHelper: engine.stop failed: $e');
    }
  }
}
