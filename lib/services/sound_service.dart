import 'dart:developer';

import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  /// Created on the first sound, so a device with sounds off, or a screenshot
  /// render with no audio plugin, never initialises the audio engine
  AudioPlayer? _player;

  Future<void> playPling() async {
    try {
      await (_player ??= AudioPlayer()).play(AssetSource('sounds/pling.mp3'));
    } catch (e) {
      log('Sound playback failed: $e');
    }
  }

  void dispose() {
    _player?.dispose();
    _player = null;
  }
}
