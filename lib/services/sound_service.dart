import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _scanPlayer = AudioPlayer();
  final AudioPlayer _receivePlayer = AudioPlayer();

  Future<void> playPling() async {
    try {
      await _receivePlayer.play(AssetSource('sounds/pling.mp3'));
    } catch (e) {
      print('Sound playback failed: $e');
    }
  }

  void dispose() {
    _scanPlayer.dispose();
    _receivePlayer.dispose();
  }
}
