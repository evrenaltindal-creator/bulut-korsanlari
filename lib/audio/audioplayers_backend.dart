import 'package:audioplayers/audioplayers.dart';

import 'music.dart';

/// Real playback through the audioplayers plugin.
///
/// Only `main.dart` imports this, so tests never touch the plugin.
class AudioplayersBackend implements MusicBackend {
  AudioplayersBackend() {
    // Game music follows the phone's silent switch and mixes politely
    // with whatever else is playing.
    AudioPlayer.global
        .setAudioContext(AudioContextConfig(respectSilence: true).build())
        .catchError((Object _) {});
  }

  @override
  MusicVoice createVoice() => _Voice();
}

class _Voice implements MusicVoice {
  final AudioPlayer _p = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  @override
  Future<void> start(String asset, double volume) async {
    await _p.stop();
    await _p.play(AssetSource(asset), volume: volume);
  }

  @override
  Future<void> setVolume(double volume) => _p.setVolume(volume);

  @override
  Future<void> stop() => _p.stop();

  @override
  Future<void> pause() => _p.pause();

  @override
  Future<void> resume() => _p.resume();
}
