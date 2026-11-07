import 'dart:async';

import '../game/mission_result.dart';

/// Every sound effect. Gun, explosion, hits, damage, flak and the jam are
/// CC0 recordings prepared by `tool/prepare_sfx.py`; the engine, the bomb
/// whistle and the warning are synthesised by `tool/generate_sfx.py`.
/// `assets/audio/SFX_SOURCE.txt` lists every source.
enum Sfx {
  gun(loop: true, level: 0.5),
  engine(loop: true, level: 0.32),
  explosion(level: 0.65, gap: 0.08),
  hit(level: 0.42, gap: 0.05),
  damage(level: 0.8, gap: 0.08),
  flak(level: 0.45, gap: 0.06),
  bomb(level: 0.55),
  jam(level: 0.45),
  warning(level: 0.6, gap: 0.6);

  const Sfx({this.loop = false, this.level = 1, this.gap = 0});

  final bool loop;

  /// Mix level of this sound before the player's effects volume.
  final double level;

  /// Shortest time between two starts; a burst of hits in one frame
  /// should not stack into one loud bang.
  final double gap;

  String get asset => 'audio/sfx/$name.wav';
}

/// A sound that keeps playing until stopped (guns, engine).
abstract interface class SfxLoop {
  Future<void> setVolume(double volume);
  Future<void> setRate(double rate);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
}

abstract interface class SfxBackend {
  Future<void> preload();
  Future<void> play(Sfx sfx, double volume);
  SfxLoop loop(Sfx sfx, double volume);
}

class SilentSfxBackend implements SfxBackend {
  @override
  Future<void> preload() async {}
  @override
  Future<void> play(Sfx sfx, double volume) async {}
  @override
  SfxLoop loop(Sfx sfx, double volume) => _SilentLoop();
}

class _SilentLoop implements SfxLoop {
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> setRate(double rate) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stop() async {}
}

/// Turns what happens in a mission into sound: one-shots for events,
/// loops for the engine and the guns, all under one effects volume.
class SfxDirector {
  SfxDirector(this._backend, {double volume = 0.8})
    : _volume = volume.clamp(0.0, 1.0);

  final SfxBackend _backend;
  double _volume;
  double _clock = 0;
  final Map<Sfx, double> _lastStart = {};
  SfxLoop? _engine;
  SfxLoop? _gun;
  double _engineRate = 1;
  bool _paused = false;

  double get volume => _volume;
  bool get engineOn => _engine != null;
  bool get gunOn => _gun != null;

  set volume(double v) {
    _volume = v.clamp(0.0, 1.0);
    _call(_engine?.setVolume(_level(Sfx.engine)));
    _call(_gun?.setVolume(_level(Sfx.gun)));
  }

  Future<void> preload() => _backend.preload().catchError((Object _) {});

  double _level(Sfx s) => s.level * _volume;

  /// Advances the clock used to space out repeated sounds.
  void tick(double dt) => _clock += dt;

  void play(Sfx s, {double gain = 1}) {
    if (_paused || _volume <= 0) return;
    final last = _lastStart[s];
    if (last != null && _clock - last < s.gap) return;
    _lastStart[s] = _clock;
    _call(_backend.play(s, (_level(s) * gain).clamp(0.0, 1.0)));
  }

  /// The sound for a mission event.
  void event(SimEvent e) => switch (e) {
    SimEvent.hit => play(Sfx.hit),
    SimEvent.kill => play(Sfx.explosion, gain: 0.8),
    SimEvent.blast => play(Sfx.explosion),
    SimEvent.playerHit => play(Sfx.damage),
    SimEvent.flak => play(Sfx.flak),
    SimEvent.bombDrop => play(Sfx.bomb),
    SimEvent.jam => play(Sfx.jam),
    SimEvent.down => play(Sfx.explosion, gain: 1.1),
    SimEvent.warning => play(Sfx.warning),
  };

  void engine({required bool on, double rate = 1}) {
    if (!on) {
      _call(_engine?.stop());
      _engine = null;
      return;
    }
    if (_engine == null && _volume > 0) {
      _engine = _backend.loop(Sfx.engine, _level(Sfx.engine));
      _engineRate = 1;
      if (_paused) _call(_engine!.pause());
    }
    // Only tell the platform when the pitch has really moved.
    if (_engine != null && (rate - _engineRate).abs() > 0.03) {
      _engineRate = rate;
      _call(_engine!.setRate(rate));
    }
  }

  void guns({required bool on}) {
    if (on == (_gun != null)) return;
    if (on) {
      if (_volume <= 0) return;
      _gun = _backend.loop(Sfx.gun, _level(Sfx.gun));
      if (_paused) _call(_gun!.pause());
    } else {
      _call(_gun?.stop());
      _gun = null;
    }
  }

  void pause() {
    if (_paused) return;
    _paused = true;
    _call(_engine?.pause());
    _call(_gun?.pause());
  }

  void resume() {
    if (!_paused) return;
    _paused = false;
    _call(_engine?.resume());
    _call(_gun?.resume());
  }

  /// End of a mission: silence every loop.
  void stopLoops() {
    engine(on: false);
    guns(on: false);
  }

  void _call(Future<void>? f) {
    // Sound is a nicety: a failure must never reach the game.
    f?.catchError((Object _) {});
  }
}
