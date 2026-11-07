import 'dart:math' as math;

import '../../core/controls.dart';
import '../../core/effects.dart';
import '../../core/v3.dart';
import '../mission_result.dart';

enum BombTargetKind { hangar, depot, gun, airship }

class BombTargetSpec {
  const BombTargetSpec(this.kind, {this.primary = false, this.count = 1});

  final BombTargetKind kind;
  final bool primary;
  final int count;
}

class BombingConfig {
  const BombingConfig({
    required this.targets,
    required this.bombs,
    this.length = 2200,
    this.wind = 22,
    this.seed = 1,
    this.airshipHp = 8,
  });

  final List<BombTargetSpec> targets;
  final int bombs;

  /// Length of the pirate base along the flight path.
  final double length;

  /// Cross wind speed (world units per second), sign picks the direction.
  final double wind;
  final int seed;
  final int airshipHp;
}

class BombTarget {
  BombTarget(this.kind, this.x, this.y, {required this.primary, int? hp})
    : hp = hp ?? defaultHp(kind),
      maxHp = hp ?? defaultHp(kind);

  static int defaultHp(BombTargetKind k) => switch (k) {
    BombTargetKind.hangar => 3,
    BombTargetKind.depot => 2,
    BombTargetKind.gun => 1,
    BombTargetKind.airship => 8,
  };

  /// Half extents of the footprint.
  static (double, double) extent(BombTargetKind k) => switch (k) {
    BombTargetKind.hangar => (40, 26),
    BombTargetKind.depot => (20, 20),
    BombTargetKind.gun => (14, 14),
    // Long axis along the flight path: it flies the same way as the plane.
    BombTargetKind.airship => (32, 95),
  };

  final BombTargetKind kind;
  double x;
  double y;
  final bool primary;
  int hp;
  final int maxHp;
  double vx = 0;
  double vy = 0;
  double cooldown = 1;
  double hitFlash = 0;

  bool get alive => hp > 0;
}

class Bomb {
  Bomb(this.from, this.vel, this.fallTime);

  final V3 from;
  final V3 vel;
  final double fallTime;
  double age = 0;

  double get t => (age / fallTime).clamp(0.0, 1.0);
  V3 get ground => from + vel * fallTime;
  V3 get current => from + vel * age;
}

class FlakBurst {
  FlakBurst(this.at, this.delay);

  final V3 at;
  double delay;
}

/// Top-down bombing run over a pirate base on a floating rock.
///
/// Ground coordinates: x across, y along the flight path (the plane flies
/// towards +y).
class BombingSim implements MissionSim {
  BombingSim({required this.config, this.skills = const PilotSkills()})
    : rng = math.Random(config.seed),
      bombsLeft = config.bombs {
    _layout();
  }

  static const double fallTime = 1.7;
  static const double startY = -700;
  static const double maxX = 420;
  static const double blastRadius = 42;

  final BombingConfig config;
  final PilotSkills skills;
  final math.Random rng;

  final V3 plane = V3(0, startY, 0);
  double speed = 150;
  double vx = 0;
  int bombsLeft;
  final List<BombTarget> targets = [];
  final List<Bomb> bombs = [];
  final List<FlakBurst> pendingFlak = [];
  final EffectList effects = EffectList();

  /// Outline of the floating rock as (y, halfWidth) samples.
  final List<(double, double)> outline = [];

  double _health = 1;
  double _time = 0;
  double _dropCooldown = 0;
  double _endTimer = -1;
  double hitFlash = 0;
  int bombsHit = 0;
  MissionResult? _result;

  @override
  double get health => _health;
  @override
  MissionResult? get result => _result;
  @override
  double get time => _time;

  bool get planeDown => _health <= 0;
  double get endY => config.length + 600;
  double get progress => ((plane.y - startY) / (endY - startY)).clamp(0.0, 1.0);
  Iterable<BombTarget> get primaries => targets.where((t) => t.primary);
  int get primariesLeft => primaries.where((t) => t.alive).length;
  int get destroyed => targets.where((t) => !t.alive).length;

  /// Where a bomb dropped now would land if there were no wind. The sight
  /// leaves the wind to the pilot.
  V3 get sightPoint {
    final v = _bombVelocity(withWind: false);
    return plane + v * fallTime;
  }

  /// The real landing point, wind included.
  V3 get trueImpactPoint => plane + _bombVelocity(withWind: true) * fallTime;

  V3 _bombVelocity({required bool withWind}) =>
      V3(vx * 0.7 + (withWind ? config.wind : 0), speed * 0.9, 0);

  double halfWidthAt(double y) {
    if (y < -150 || y > config.length + 150) return 0;
    final ends =
        smoothstep(-150, 150, y) *
        smoothstep(config.length + 150, config.length - 150, y);
    final s = config.seed * 0.71;
    return (300 + 70 * math.sin(y / 330 + s) + 40 * math.sin(y / 120 + s * 2)) *
        ends;
  }

  void _layout() {
    for (var y = -150.0; y <= config.length + 150; y += 30) {
      outline.add((y, halfWidthAt(y)));
    }
    final kinds = <(BombTargetKind, bool)>[];
    for (final spec in config.targets) {
      for (var i = 0; i < spec.count; i++) {
        kinds.add((spec.kind, spec.primary));
      }
    }
    final placed = <BombTarget>[];
    final ground = kinds.where((k) => k.$1 != BombTargetKind.airship).toList()
      ..shuffle(rng);
    for (var i = 0; i < ground.length; i++) {
      final (kind, primary) = ground[i];
      final (ex, ey) = BombTarget.extent(kind);
      BombTarget? t;
      for (var attempt = 0; attempt < 40; attempt++) {
        final y =
            150 +
            (config.length - 300) * (i + rng.nextDouble()) / ground.length;
        final hw = halfWidthAt(y) - ex - 20;
        if (hw <= 0) continue;
        final x = (rng.nextDouble() * 2 - 1) * hw;
        final clash = placed.any((o) {
          final (ox, oy) = BombTarget.extent(o.kind);
          return (o.x - x).abs() < ox + ex + 14 &&
              (o.y - y).abs() < oy + ey + 14;
        });
        if (!clash) {
          t = BombTarget(kind, x, y, primary: primary);
          break;
        }
      }
      if (t != null) placed.add(t);
    }
    for (final (kind, primary) in kinds.where(
      (k) => k.$1 == BombTargetKind.airship,
    )) {
      // Cruising ahead of the plane, slower than it, drifting sideways:
      // the pilot catches up from behind and bombs along its back.
      final t =
          BombTarget(
              kind,
              (rng.nextDouble() * 2 - 1) * 120,
              config.length * (0.3 + rng.nextDouble() * 0.15),
              primary: primary,
              hp: config.airshipHp,
            )
            ..vx = rng.nextBool() ? 18 : -18
            ..vy = 40;
      placed.add(t);
    }
    targets.addAll(placed);
  }

  void update(double dt, ControlState c) {
    if (_result != null) return;
    _time += dt;
    hitFlash = math.max(0, hitFlash - dt * 3);
    _dropCooldown -= dt;

    if (planeDown) {
      plane.y += speed * dt * 0.7;
      plane.x += vx * dt;
      if (rng.nextDouble() < 0.6) _smoke(plane.copy());
    } else {
      final handling = 0.85 + 0.45 * skills.handling;
      final targetVx = c.stickX.clamp(-1.0, 1.0) * 170 * handling;
      vx += (targetVx - vx) * math.min(1, dt * 3);
      plane.x = (plane.x + vx * dt).clamp(-maxX, maxX);
      final targetSpeed = 150 + c.stickY.clamp(-1.0, 1.0) * 45;
      speed += (targetSpeed - speed) * math.min(1, dt * 1.5);
      plane.y += speed * dt;
      if (c.drop) dropBomb();
    }

    for (final t in targets) {
      t.hitFlash = math.max(0, t.hitFlash - dt * 4);
      if (t.kind == BombTargetKind.airship && t.alive) {
        t.x += t.vx * dt;
        t.y += t.vy * dt;
        if (t.x.abs() > 200) t.vx = -t.x.sign * t.vx.abs();
      }
      if (!t.alive && rng.nextDouble() < dt * 5) {
        _smoke(
          V3(
            t.x + (rng.nextDouble() - 0.5) * 20,
            t.y + (rng.nextDouble() - 0.5) * 20,
            0,
          ),
        );
      }
    }

    _updateBombs(dt);
    _antiAir(dt);
    effects.update(dt, drag: 1.0);

    if (_endTimer < 0) {
      if (planeDown) {
        _endTimer = 2.2;
      } else if (plane.y > endY) {
        _endTimer = 0.01;
      }
    } else {
      _endTimer -= dt;
      if (_endTimer <= 0) _finish();
    }
  }

  void dropBomb() {
    if (planeDown || bombsLeft <= 0 || _dropCooldown > 0) return;
    _dropCooldown = 0.35;
    bombsLeft--;
    final v = _bombVelocity(withWind: true);
    final jitter = lerpDouble(0.08, 0.015, skills.gunnery);
    v.x += (rng.nextDouble() - 0.5) * 2 * speed * jitter;
    v.y += (rng.nextDouble() - 0.5) * 2 * speed * jitter;
    bombs.add(Bomb(plane.copy(), v, fallTime));
  }

  void _updateBombs(double dt) {
    for (final b in bombs) {
      b.age += dt;
      if (b.age >= b.fallTime) _blast(b.ground);
    }
    bombs.removeWhere((b) => b.age >= b.fallTime);
  }

  void _blast(V3 at) {
    final onRock = halfWidthAt(at.y) > at.x.abs();
    var hitAny = false;
    for (final t in targets) {
      if (!t.alive) continue;
      final (ex, ey) = BombTarget.extent(t.kind);
      // Distance from the blast to the footprint rectangle.
      final dx = math.max(0.0, (at.x - t.x).abs() - ex);
      final dy = math.max(0.0, (at.y - t.y).abs() - ey);
      final d = math.sqrt(dx * dx + dy * dy);
      if (d > blastRadius) continue;
      hitAny = true;
      // A bomb on the roof does far more than one that lands alongside.
      _damage(t, d == 0 ? 3 : (d < blastRadius * 0.5 ? 2 : 1));
    }
    if (hitAny) bombsHit++;
    effects.add(
      Effect(
        kind: onRock || hitAny ? EffectKind.fire : EffectKind.splash,
        pos: at.copy(),
        life: 0.9,
        size0: 16,
        size1: 56,
      ),
    );
    for (var i = 0; i < 5; i++) {
      effects.add(
        Effect(
          kind: EffectKind.debris,
          pos: at.copy(),
          vel: V3(
            (rng.nextDouble() - 0.5) * 140,
            (rng.nextDouble() - 0.5) * 140,
            0,
          ),
          life: 0.7,
          size0: 4,
          size1: 2,
        ),
      );
    }
  }

  void _damage(BombTarget t, int amount) {
    t.hp = math.max(0, t.hp - amount);
    t.hitFlash = 1;
    if (t.alive) return;
    effects.add(
      Effect(
        kind: EffectKind.fire,
        pos: V3(t.x, t.y, 0),
        life: 1.3,
        size0: 20,
        size1: 90,
      ),
    );
    if (t.kind == BombTargetKind.depot) {
      for (final o in targets) {
        if (o == t || !o.alive) continue;
        if ((o.x - t.x).abs() < 90 && (o.y - t.y).abs() < 90) _damage(o, 1);
      }
    }
  }

  void _antiAir(double dt) {
    for (final f in pendingFlak) {
      f.delay -= dt;
      if (f.delay <= 0) {
        effects.add(
          Effect(
            kind: EffectKind.flak,
            pos: f.at.copy(),
            life: 1.0,
            size0: 12,
            size1: 36,
          ),
        );
        if (!planeDown && (f.at - plane).length < 34) {
          _health -= 0.09;
          hitFlash = 1;
          if (_health <= 0) _health = 0;
        }
      }
    }
    pendingFlak.removeWhere((f) => f.delay <= 0);
    if (planeDown) return;
    for (final t in targets) {
      final shoots =
          t.kind == BombTargetKind.gun ||
          (t.kind == BombTargetKind.airship &&
              t.alive &&
              rng.nextDouble() < 0.5);
      if (!shoots || !t.alive) continue;
      final dy = t.y - plane.y;
      if (dy < -350 || dy > 800) continue;
      t.cooldown -= dt;
      if (t.cooldown > 0) continue;
      t.cooldown = 2.0 + rng.nextDouble() * 1.4;
      const delay = 0.8;
      final miss = lerpDouble(50, 80, skills.handling);
      final at = V3(
        plane.x + vx * delay + (rng.nextDouble() - 0.5) * miss * 2,
        plane.y + speed * delay + (rng.nextDouble() - 0.5) * miss * 2,
        0,
      );
      pendingFlak.add(FlakBurst(at, delay));
    }
  }

  void _finish() {
    final outcome = planeDown
        ? MissionOutcome.shotDown
        : primariesLeft == 0
        ? MissionOutcome.success
        : MissionOutcome.objectiveFailed;
    _result = MissionResult(
      outcome: outcome,
      targetsDestroyed: destroyed,
      targetsTotal: targets.length,
      shotsFired: config.bombs - bombsLeft,
      shotsHit: bombsHit,
      healthLeft: _health.clamp(0, 1),
    );
  }

  void _smoke(V3 at) {
    effects.add(
      Effect(
        kind: EffectKind.smoke,
        pos: at,
        vel: V3(config.wind * 0.8, 0, 0),
        life: 1.8,
        size0: 10,
        size1: 34,
      ),
    );
  }
}
