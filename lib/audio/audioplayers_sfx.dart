import 'package:audioplayers/audioplayers.dart';

import 'sfx.dart';

/// Sound effects through the audioplayers plugin: a small pool of players
/// per one-shot so quick repeats overlap, and one player per loop.
///
/// Only `main.dart` imports this, so tests never touch the plugin.
class AudioplayersSfxBackend implements SfxBackend {
  final Map<Sfx, AudioPool> _pools = {};

  @override
  Future<void> preload() async {
    for (final s in Sfx.values.where((s) => !s.loop)) {
      _pools[s] = await AudioPool.createFromAsset(
        path: s.asset,
        maxPlayers: s == Sfx.hit || s == Sfx.flak ? 4 : 3,
      );
    }
  }

  @override
  Future<void> play(Sfx sfx, double volume) async {
    final pool = _pools[sfx];
    if (pool == null) return; // still loading
    await pool.start(volume: volume);
  }

  @override
  SfxLoop loop(Sfx sfx, double volume) => _Loop(sfx, volume);
}

class _Loop implements SfxLoop {
  _Loop(Sfx sfx, double volume) {
    _ready = () async {
      await _p.setReleaseMode(ReleaseMode.loop);
      await _p.play(AssetSource(sfx.asset), volume: volume);
    }();
  }

  final AudioPlayer _p = AudioPlayer();
  late final Future<void> _ready;

  Future<void> _after(Future<void> Function() f) => _ready.then((_) => f());

  @override
  Future<void> setVolume(double volume) => _after(() => _p.setVolume(volume));

  @override
  Future<void> setRate(double rate) => _after(() => _p.setPlaybackRate(rate));

  @override
  Future<void> pause() => _after(_p.pause);

  @override
  Future<void> resume() => _after(_p.resume);

  @override
  Future<void> stop() => _after(() async {
    await _p.stop();
    await _p.dispose();
  });
}
