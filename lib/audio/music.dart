import 'dart:async';
import 'dart:math' as math;

/// Every piece of music in the game. Files are prepared by
/// `tool/prepare_music.py` (constant bitrate, so [seconds] is exact);
/// `assets/audio/MUSIC_SOURCE.txt` says where each one came from.
enum MusicTrack {
  menu(seconds: 176.85),
  logbook(seconds: 176.98),
  dogfight(seconds: 175.39),
  raid(seconds: 180.27),
  bombing(seconds: 178.68),
  finale(seconds: 179.96),
  victory(seconds: 58.70, loop: false),
  defeat(seconds: 177.61, loop: false, level: 0.75),
  ending(seconds: 58.36);

  const MusicTrack({required this.seconds, this.loop = true, this.level = 1});

  final double seconds;

  /// Loops start again with a crossfade; the others play once.
  final bool loop;

  /// Per-track trim on top of the player's music volume.
  final double level;

  /// Path for the audio plugin (relative to `assets/`).
  String get asset => 'audio/music/$name.mp3';
}

/// One playback channel. The director uses two so it can crossfade.
abstract interface class MusicVoice {
  Future<void> start(String asset, double volume);
  Future<void> setVolume(double volume);
  Future<void> stop();
  Future<void> pause();
  Future<void> resume();
}

abstract interface class MusicBackend {
  MusicVoice createVoice();
}

/// Plays nothing. Used in tests and wherever audio is unavailable.
class SilentMusicBackend implements MusicBackend {
  @override
  MusicVoice createVoice() => _SilentVoice();
}

class _SilentVoice implements MusicVoice {
  @override
  Future<void> start(String asset, double volume) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
}

class _Slot {
  _Slot(this.voice);

  final MusicVoice voice;
  MusicTrack? track;
  double gain = 0;
  double target = 0;
  double elapsed = 0;
  bool active = false;
  bool loopQueued = false;
  double sentVolume = -1;

  /// True from asking the voice to start until it reports back. A browser
  /// that blocks autoplay leaves the start waiting for a user gesture.
  bool startPending = false;
  int startToken = 0;
}

/// Chooses what plays: crossfades between screens, loops tracks without a
/// hard cut, ducks under the pause menu and stops with the app.
///
/// [tick] drives fades and timing. In the app a timer calls it; tests
/// call it by hand.
class MusicDirector {
  MusicDirector(
    MusicBackend backend, {
    double volume = 0.7,
    bool autoTick = true,
  }) : _volume = volume.clamp(0.0, 1.0),
       _a = _Slot(backend.createVoice()),
       _b = _Slot(backend.createVoice()) {
    if (autoTick) {
      _timer = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => tick(0.1),
      );
    }
  }

  /// Seconds both voices overlap when changing or looping a track.
  static const double crossfade = 2.5;
  static const double duckLevel = 0.35;

  final _Slot _a;
  final _Slot _b;
  Timer? _timer;
  double _volume;
  bool _ducked = false;
  bool _paused = false;
  bool _blocked = false;
  MusicTrack? _wanted;

  MusicTrack? get wanted => _wanted;
  double get volume => _volume;

  /// The track the listener mostly hears now, if any.
  MusicTrack? get playing {
    final s = [_a, _b]
        .where((s) => s.active)
        .fold<_Slot?>(
          null,
          (best, s) => best == null || s.target > best.target ? s : best,
        );
    return s?.target == 0 ? null : s?.track;
  }

  set volume(double v) {
    _volume = v.clamp(0.0, 1.0);
    _pushVolumes();
  }

  /// Switches to [track]. Asking for the track already playing does
  /// nothing, so screens can call this freely.
  void play(MusicTrack track) {
    if (_wanted == track) return;
    _wanted = track;
    final current = _slotFor(track);
    if (current != null && current.target > 0) return;
    _startFresh(track);
  }

  void stop() {
    _wanted = null;
    for (final s in [_a, _b]) {
      s.target = 0;
    }
  }

  /// Lowers the music, e.g. under the pause menu.
  void duck(bool on) {
    _ducked = on;
    _pushVolumes();
  }

  /// App went to the background.
  void pause() {
    if (_paused) return;
    _paused = true;
    for (final s in [_a, _b]) {
      if (s.active) _call(s.voice.pause());
    }
  }

  void resume() {
    if (!_paused) return;
    _paused = false;
    for (final s in [_a, _b]) {
      if (s.active) _call(s.voice.resume());
    }
  }

  /// A browser refuses to start audio before the first touch: the start
  /// either fails or waits. Call this on a user gesture to start again.
  void unlock() {
    final stuck = [_a, _b].any((s) => s.active && s.startPending);
    if (!_blocked && !stuck) return;
    _blocked = false;
    final w = _wanted;
    if (w == null) return;
    for (final s in [_a, _b]) {
      if (s.active) {
        _call(s.voice.stop());
        s.active = false;
        s.gain = 0;
        s.target = 0;
      }
    }
    _startFresh(w);
  }

  void tick(double dt) {
    if (_paused) return;
    for (final s in [_a, _b]) {
      if (!s.active) continue;
      s.elapsed += dt;
      final step = dt / crossfade;
      if (s.gain < s.target) {
        s.gain = math.min(s.target, s.gain + step);
      } else if (s.gain > s.target) {
        s.gain = math.max(s.target, s.gain - step);
      }
      final track = s.track!;
      if (s.gain <= 0 && s.target <= 0) {
        _silence(s);
        continue;
      }
      if (s.elapsed >= track.seconds) {
        // Finished on its own (a one-shot, or a loop that was not handed
        // over in time).
        _silence(s);
        if (track.loop && _wanted == track && !s.loopQueued) _startFresh(track);
        continue;
      }
      if (track.loop &&
          _wanted == track &&
          !s.loopQueued &&
          s.target > 0 &&
          s.elapsed >= track.seconds - crossfade) {
        s.loopQueued = true;
        s.target = 0;
        _startFresh(track);
      }
    }
    _pushVolumes();
  }

  void dispose() {
    _timer?.cancel();
    for (final s in [_a, _b]) {
      if (s.active) _call(s.voice.stop());
    }
  }

  _Slot? _slotFor(MusicTrack t) {
    for (final s in [_a, _b]) {
      if (s.active && s.track == t && !s.loopQueued) return s;
    }
    return null;
  }

  void _startFresh(MusicTrack track) {
    // Use the quieter voice for the new track; fade the other one out.
    final fresh = _a.gain <= _b.gain ? _a : _b;
    final other = identical(fresh, _a) ? _b : _a;
    other.target = 0;
    if (fresh.active) _call(fresh.voice.stop());
    fresh
      ..track = track
      ..active = true
      ..elapsed = 0
      ..loopQueued = false
      // Nothing to fade from: start at full level straight away.
      ..gain = other.active && other.gain > 0 ? 0 : 1
      ..target = 1
      ..sentVolume = -1;
    final v = _levelOf(fresh);
    fresh.sentVolume = v;
    final token = ++fresh.startToken;
    fresh.startPending = true;
    void done() {
      if (fresh.startToken == token) fresh.startPending = false;
    }

    _call(fresh.voice.start(track.asset, v).then((_) => done()), blocks: true);
  }

  void _silence(_Slot s) {
    if (!s.active) return;
    s.active = false;
    s.gain = 0;
    s.target = 0;
    _call(s.voice.stop());
  }

  double _levelOf(_Slot s) =>
      s.gain * _volume * (s.track?.level ?? 1) * (_ducked ? duckLevel : 1);

  void _pushVolumes() {
    for (final s in [_a, _b]) {
      if (!s.active) continue;
      final v = _levelOf(s);
      if ((v - s.sentVolume).abs() > 0.005) {
        s.sentVolume = v;
        _call(s.voice.setVolume(v));
      }
    }
  }

  void _call(Future<void> f, {bool blocks = false}) {
    f.catchError((Object _) {
      // Audio is a nicety: a failure must never break the game. On the
      // web the first start fails until the player touches the screen.
      if (blocks) _blocked = true;
    });
  }
}
