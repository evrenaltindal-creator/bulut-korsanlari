import 'dart:math' as math;

import '../../core/controls.dart';
import '../../core/effects.dart';
import '../../core/v3.dart';
import '../mission_result.dart';

enum RaidTargetKind { crate, turret, fuel, skiff }

class RaidConfig {
  const RaidConfig({
    required this.length,
    required this.targets,
    this.quota = 0.6,
    this.seed = 1,
    this.turretRate = 1,
  });

  /// Island length in world units along the flight path.
  final double length;
  final Map<RaidTargetKind, int> targets;

  /// Fraction of targets that must be destroyed.
  final double quota;
  final int seed;

  /// Multiplier on how often turrets fire.
  final double turretRate;
}

class RaidTarget {
  RaidTarget(this.kind, this.u, this.v) : hp = maxHp(kind);

  static int maxHp(RaidTargetKind k) => switch (k) {
    RaidTargetKind.crate => 2,
    RaidTargetKind.turret => 3,
    RaidTargetKind.fuel => 2,
    RaidTargetKind.skiff => 5,
  };

  static double radius(RaidTargetKind k) => switch (k) {
    RaidTargetKind.crate => 21,
    RaidTargetKind.turret => 23,
    RaidTargetKind.fuel => 23,
    RaidTargetKind.skiff => 36,
  };

  final RaidTargetKind kind;
  final double u;
  final double v;
  int hp;
  double cooldown = 0;
  double hitFlash = 0;

  bool get alive => hp > 0;
}

class RaidShot {
  RaidShot(this.pos, this.target, this.flightTime) : start = pos.copy();

  final V3 pos;
  final V3 start;

  /// Ground point (u, v, 0) the bullet will strike.
  final V3 target;
  final double flightTime;
  double age = 0;
}

class Flak {
  Flak(this.from, this.at, this.flightTime);

  final V3 from;
  final V3 at;
  final double flightTime;
  double age = 0;
  bool burst = false;
}

/// Low-level strafing run over a pirate harbour on a floating island.
///
/// Coordinates: u along the flight path, v across it (positive to the
/// plane's right), z height above the island surface.
class RaidSim implements MissionSim {
  RaidSim({required this.config, this.skills = const PilotSkills()})
    : rng = math.Random(config.seed) {
    _layout();
  }

  static const double startU = -500;
  static const double maxV = 340;
  static const double minAlt = 32;
  static const double maxAlt = 120;
  static const double shotSpeed = 620;

  final RaidConfig config;
  final PilotSkills skills;
  final math.Random rng;

  final V3 plane = V3(startU, 0, 70);
  double speed = 135;
  final List<RaidTarget> targets = [];
  final List<RaidShot> shots = [];
  final List<Flak> flak = [];
  final EffectList effects = EffectList();

  /// Decorative props (trees, huts) as (u, v, kind).
  final List<(double, double, int)> props = [];

  /// Docks sticking out of the island's right edge as (u, length).
  final List<(double, double)> docks = [];

  double _health = 1;
  double _time = 0;
  double _cooldown = 0;
  double _endTimer = -1;
  double hitFlash = 0;
  double bank = 0;
  int shotsFired = 0;
  int shotsHit = 0;
  MissionResult? _result;

  @override
  double get health => _health;
  @override
  MissionResult? get result => _result;
  @override
  double get time => _time;

  bool get planeDown => _health <= 0;
  int get destroyed => targets.where((t) => !t.alive).length;
  int get required => (targets.length * config.quota).ceil();
  double get progress =>
      ((plane.x - startU) / (config.length + 300 - startU)).clamp(0.0, 1.0);

  /// Where the guns are pointing on the ground right now.
  V3 get aimPoint => V3(plane.x + aimDistance, plane.y, 0);
  double get aimDistance => 60 + plane.z * 2.1;

  /// Half width of the island at [u]; zero beyond its ends.
  double halfWidth(double u) {
    if (u < 0 || u > config.length) return 0;
    final s = config.seed * 0.37;
    final base =
        230 + 60 * math.sin(u / 520 + s) + 35 * math.sin(u / 190 + 2 * s);
    final ends =
        smoothstep(0, 260, u) *
        smoothstep(config.length, config.length - 260, u);
    return base * ends;
  }

  /// Depth of the rocky underside below the island at [u].
  double undersideDepth(double u) =>
      140 + 60 * math.sin(u / 310 + config.seed) + 30 * math.sin(u / 97);

  void _layout() {
    final kinds = <RaidTargetKind>[];
    config.targets.forEach((k, n) {
      for (var i = 0; i < n; i++) {
        kinds.add(k);
      }
    });
    kinds.shuffle(rng);
    final usable = config.length - 500;
    for (var i = 0; i < kinds.length; i++) {
      final k = kinds[i];
      final u =
          250 +
          usable * (i + 0.5) / kinds.length +
          (rng.nextDouble() - 0.5) * 60;
      final hw = halfWidth(u);
      double v;
      if (k == RaidTargetKind.skiff) {
        // Moored at the end of a dock past the right edge.
        final len = 70 + rng.nextDouble() * 40;
        docks.add((u, len));
        v = hw + len + 25;
      } else {
        v = (rng.nextDouble() * 2 - 1) * (hw - 45);
      }
      targets.add(RaidTarget(k, u, v));
    }
    for (
      var u = 60.0;
      u < config.length - 60;
      u += 28 + rng.nextDouble() * 40
    ) {
      final hw = halfWidth(u);
      if (hw < 40) continue;
      final v = (rng.nextDouble() * 2 - 1) * (hw - 20);
      final near = targets.any(
        (t) => (t.u - u).abs() < 40 && (t.v - v).abs() < 40,
      );
      if (!near) props.add((u, v, rng.nextInt(10)));
    }
  }

  void update(double dt, ControlState c) {
    if (_result != null) return;
    _time += dt;
    hitFlash = math.max(0, hitFlash - dt * 3);

    if (planeDown) {
      plane.z = math.max(-200, plane.z - dt * 90);
      plane.x += speed * dt * 0.8;
      bank += dt * 2;
      if (rng.nextDouble() < 0.6) _smoke(plane.copy());
    } else {
      final handling = 0.85 + 0.45 * skills.handling;
      final sx = c.stickX.clamp(-1.0, 1.0);
      plane.y = (plane.y + sx * 230 * handling * dt).clamp(-maxV, maxV);
      plane.z = (plane.z + c.stickY.clamp(-1.0, 1.0) * 70 * dt).clamp(
        minAlt,
        maxAlt,
      );
      bank += (sx * 0.6 - bank) * math.min(1, dt * 5);
      plane.x += speed * dt;
      _guns(dt, c);
    }

    _moveShots(dt);
    _turrets(dt);
    _moveFlak(dt);
    for (final t in targets) {
      t.hitFlash = math.max(0, t.hitFlash - dt * 4);
      if (!t.alive && rng.nextDouble() < dt * 4) {
        _smoke(V3(t.u, t.v, 8));
      }
    }
    effects.update(dt, drag: 1.2);
    for (final e in effects.items) {
      if (e.kind == EffectKind.smoke) e.pos.z += dt * 30;
    }

    if (_endTimer < 0) {
      if (planeDown) {
        _endTimer = 2.2;
      } else if (plane.x > config.length + 300) {
        _endTimer = 0.01;
      }
    } else {
      _endTimer -= dt;
      if (_endTimer <= 0) _finish();
    }
  }

  void _finish() {
    final outcome = planeDown
        ? MissionOutcome.shotDown
        : destroyed >= required
        ? MissionOutcome.success
        : MissionOutcome.objectiveFailed;
    _result = MissionResult(
      outcome: outcome,
      targetsDestroyed: destroyed,
      targetsTotal: targets.length,
      shotsFired: shotsFired,
      shotsHit: shotsHit,
      healthLeft: _health.clamp(0, 1),
    );
  }

  void _guns(double dt, ControlState c) {
    _cooldown -= dt;
    if (!c.fire || _cooldown > 0) return;
    _cooldown = 0.075;
    shotsFired++;
    final spread = lerpDouble(16, 4, skills.gunnery);
    final aim = aimPoint;
    final target = V3(
      aim.x + (rng.nextDouble() - 0.5) * spread * 2,
      aim.y + (rng.nextDouble() - 0.5) * spread * 2,
      0,
    );
    final from = V3(
      plane.x + 10,
      plane.y + (shotsFired.isEven ? -6 : 6),
      plane.z - 2,
    );
    final dist = (target - from).length;
    shots.add(RaidShot(from, target, dist / shotSpeed));
  }

  void _moveShots(double dt) {
    for (final s in shots) {
      s.age += dt;
      final t = (s.age / s.flightTime).clamp(0.0, 1.0);
      s.pos.setFrom(s.start + (s.target - s.start) * t);
      // The bullet keeps the plane's forward motion.
      if (t >= 1) _impact(s.target);
    }
    shots.removeWhere((s) => s.age >= s.flightTime);
  }

  void _impact(V3 at) {
    var hit = false;
    for (final t in targets) {
      if (!t.alive) continue;
      final r = RaidTarget.radius(t.kind);
      final du = t.u - at.x;
      final dv = t.v - at.y;
      if (du * du + dv * dv < r * r) {
        hit = true;
        _damage(t, 1);
        break;
      }
    }
    if (hit) shotsHit++;
    final overGround = halfWidth(at.x) > at.y.abs();
    effects.add(
      Effect(
        kind: hit
            ? EffectKind.spark
            : (overGround ? EffectKind.splash : EffectKind.spark),
        pos: at.copy(),
        vel: V3(
          (rng.nextDouble() - 0.5) * 40,
          (rng.nextDouble() - 0.5) * 40,
          40,
        ),
        life: 0.35,
        size0: hit ? 7 : 4,
        size1: hit ? 3 : 9,
      ),
    );
  }

  void _damage(RaidTarget t, int amount) {
    if (!t.alive) return;
    t.hp -= amount;
    t.hitFlash = 1;
    if (t.hp > 0) return;
    t.hp = 0;
    _explode(V3(t.u, t.v, 6), t.kind == RaidTargetKind.fuel ? 46 : 28);
    if (t.kind == RaidTargetKind.fuel) {
      // Burning fuel catches whatever is close.
      for (final o in targets) {
        if (o == t || !o.alive) continue;
        final du = o.u - t.u;
        final dv = o.v - t.v;
        if (du * du + dv * dv < 75 * 75) _damage(o, 3);
      }
    }
  }

  void _turrets(double dt) {
    if (planeDown) return;
    for (final t in targets) {
      if (t.kind != RaidTargetKind.turret || !t.alive) continue;
      final du = t.u - plane.x;
      if (du < -120 || du > 720) continue;
      t.cooldown -= dt * config.turretRate;
      if (t.cooldown > 0) continue;
      t.cooldown = 1.8 + rng.nextDouble() * 1.2;
      const flight = 0.85;
      final lead = V3(plane.x + speed * flight, plane.y, plane.z);
      final miss = lerpDouble(48, 78, skills.handling);
      lead.x += (rng.nextDouble() - 0.5) * miss * 2;
      lead.y += (rng.nextDouble() - 0.5) * miss * 2;
      lead.z += (rng.nextDouble() - 0.5) * 30;
      flak.add(Flak(V3(t.u, t.v, 14), lead, flight));
    }
  }

  void _moveFlak(double dt) {
    for (final f in flak) {
      f.age += dt;
      if (!f.burst && f.age >= f.flightTime) {
        f.burst = true;
        effects.add(
          Effect(
            kind: EffectKind.flak,
            pos: f.at.copy(),
            life: 0.9,
            size0: 10,
            size1: 30,
          ),
        );
        if (!planeDown && (f.at - plane).length < 40) {
          _health -= 0.1;
          hitFlash = 1;
          if (_health <= 0) {
            _health = 0;
            _explode(plane.copy(), 30);
          }
        }
      }
    }
    flak.removeWhere((f) => f.burst && f.age > f.flightTime + 0.05);
  }

  /// Position of a flak shell still in the air, or null once it burst.
  V3? flakPosition(Flak f) {
    if (f.burst) return null;
    final t = (f.age / f.flightTime).clamp(0.0, 1.0);
    final p = f.from + (f.at - f.from) * t;
    p.z += math.sin(t * math.pi) * 40;
    return p;
  }

  void _explode(V3 at, double size) {
    effects.add(
      Effect(
        kind: EffectKind.fire,
        pos: at,
        life: 0.8,
        size0: size * 0.4,
        size1: size,
      ),
    );
    for (var i = 0; i < 6; i++) {
      effects.add(
        Effect(
          kind: EffectKind.debris,
          pos: at.copy(),
          vel: V3(
            (rng.nextDouble() - 0.5) * 160,
            (rng.nextDouble() - 0.5) * 160,
            60 + rng.nextDouble() * 80,
          ),
          life: 0.9,
          size0: 4,
          size1: 2,
        ),
      );
    }
  }

  void _smoke(V3 at) {
    effects.add(
      Effect(kind: EffectKind.smoke, pos: at, life: 1.6, size0: 8, size1: 26),
    );
  }
}
