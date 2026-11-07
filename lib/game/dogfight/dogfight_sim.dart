import 'dart:math' as math;

import '../../core/controls.dart';
import '../../core/effects.dart';
import '../../core/v3.dart';
import '../mission_result.dart';

enum PirateClass { scout, raider, ace }

class DogfightConfig {
  const DogfightConfig({required this.enemies, this.seed = 1});

  final List<PirateClass> enemies;
  final int seed;
}

/// Anything that flies: position plus yaw / pitch / roll and speed.
class Flyer {
  Flyer({required this.pos, this.yaw = 0, this.pitch = 0, this.speed = 240});

  final V3 pos;
  double yaw;
  double pitch;
  double roll = 0;
  double speed;

  V3 get forward => V3.fromAngles(yaw, pitch);
  V3 get velocity => forward * speed;

  /// Right vector with no roll applied.
  V3 get flatRight => V3(math.cos(yaw), 0, -math.sin(yaw));

  /// Orthonormal basis (right, up, forward) including roll.
  (V3, V3, V3) basis([double rollFactor = 1]) {
    final f = forward;
    final r0 = flatRight;
    final u0 = f.cross(r0);
    final r = rollFactor * roll;
    final c = math.cos(r);
    final s = math.sin(r);
    return (r0 * c - u0 * s, u0 * c + r0 * s, f);
  }
}

enum PirateMode { engage, breakAway }

class PirateStats {
  const PirateStats({
    required this.hp,
    required this.speed,
    required this.turnRate,
    required this.spread,
    required this.range,
    required this.damage,
  });

  final int hp;
  final double speed;
  final double turnRate;
  final double spread;
  final double range;
  final double damage;

  static const scout = PirateStats(
    hp: 3,
    speed: 228,
    turnRate: 0.75,
    spread: 0.06,
    range: 700,
    damage: 0.04,
  );
  static const raider = PirateStats(
    hp: 5,
    speed: 245,
    turnRate: 0.9,
    spread: 0.045,
    range: 800,
    damage: 0.045,
  );
  static const ace = PirateStats(
    hp: 10,
    speed: 268,
    turnRate: 1.15,
    spread: 0.03,
    range: 920,
    damage: 0.055,
  );

  static PirateStats of(PirateClass c) => switch (c) {
    PirateClass.scout => scout,
    PirateClass.raider => raider,
    PirateClass.ace => ace,
  };
}

class Pirate extends Flyer {
  Pirate({required this.cls, required super.pos, super.yaw})
    : stats = PirateStats.of(cls),
      super(speed: PirateStats.of(cls).speed) {
    hp = stats.hp;
  }

  final PirateClass cls;
  final PirateStats stats;
  late int hp;
  PirateMode mode = PirateMode.engage;
  double modeTimer = 0;
  double fireCooldown = 2;
  int burstLeft = 0;
  V3 breakDir = V3(1, 0, 0);

  /// Seconds since this pirate was shot down; -1 while it still flies.
  double fallTime = -1;
  double hitFlash = 0;

  bool get alive => hp > 0;
  bool get gone => fallTime > 2.6;
}

class Bullet {
  Bullet({
    required this.pos,
    required this.vel,
    required this.life,
    required this.fromPlayer,
  });

  final V3 pos;
  final V3 vel;
  double life;
  final bool fromPlayer;
}

/// Pseudo-3D dogfight among the floating islands.
///
/// World axes: x right, y up, z forward at the start. The "cloud sea" is
/// the floor; the player cannot sink into it.
class DogfightSim implements MissionSim {
  DogfightSim({required this.config, this.skills = const PilotSkills()})
    : rng = math.Random(config.seed) {
    _spawn();
  }

  static const double floorY = 150;
  static const double ceilY = 2600;
  static const double bulletSpeed = 1150;
  static const double playerRadius = 16;
  static const double pirateRadius = 30;

  final DogfightConfig config;
  final PilotSkills skills;
  final math.Random rng;

  final Flyer player = Flyer(pos: V3(0, 1100, 0), speed: 250);
  final List<Pirate> pirates = [];
  final List<Bullet> bullets = [];
  final EffectList effects = EffectList();

  double _health = 1;
  double heat = 0;
  bool jammed = false;
  bool lowWarning = false;
  double _fireCooldown = 0;
  bool _leftGun = true;
  double _time = 0;
  double _endTimer = -1;
  double playerHitFlash = 0;
  double muzzleFlash = 0;
  int shotsFired = 0;
  int shotsHit = 0;
  int kills = 0;
  MissionResult? _result;

  @override
  double get health => _health;
  @override
  MissionResult? get result => _result;
  @override
  double get time => _time;

  bool get playerDown => _health <= 0;
  int get remaining => pirates.where((p) => p.alive).length;

  void _spawn() {
    for (var i = 0; i < config.enemies.length; i++) {
      final cls = config.enemies[i];
      final spreadYaw = (i - (config.enemies.length - 1) / 2) * 0.35;
      final yaw = spreadYaw + (rng.nextDouble() - 0.5) * 0.2;
      final dist =
          1500 + rng.nextDouble() * 700 + (cls == PirateClass.ace ? 400 : 0);
      final dir = V3.fromAngles(yaw, 0);
      final pos = player.pos + dir * dist;
      pos.y += (rng.nextDouble() - 0.5) * 500;
      // Heading roughly back towards the player.
      final p = Pirate(
        cls: cls,
        pos: pos,
        yaw: wrapAngle(yaw + math.pi + (rng.nextDouble() - 0.5) * 0.6),
      );
      p.fireCooldown = 1.5 + rng.nextDouble() * 2;
      pirates.add(p);
    }
  }

  void update(double dt, ControlState c) {
    if (_result != null) return;
    _time += dt;
    playerHitFlash = math.max(0, playerHitFlash - dt * 3);
    muzzleFlash = math.max(0, muzzleFlash - dt * 12);

    _flyPlayer(dt, c);
    _guns(dt, c);
    for (final p in pirates) {
      _updatePirate(p, dt);
    }
    _moveBullets(dt);
    effects.update(dt, drag: 0.8, rise: 18);
    pirates.removeWhere((p) => p.gone);

    if (_endTimer < 0) {
      if (playerDown) {
        _endTimer = 2.4;
      } else if (remaining == 0) {
        _endTimer = 2.0;
      }
    } else {
      _endTimer -= dt;
      if (_endTimer <= 0) _finish();
    }
  }

  void _finish() {
    _result = MissionResult(
      outcome: playerDown ? MissionOutcome.shotDown : MissionOutcome.success,
      kills: kills,
      targetsDestroyed: kills,
      targetsTotal: config.enemies.length,
      shotsFired: shotsFired,
      shotsHit: shotsHit,
      healthLeft: _health.clamp(0, 1),
    );
  }

  void _flyPlayer(double dt, ControlState c) {
    final p = player;
    if (playerDown) {
      // Spiral down trailing smoke.
      p.roll += dt * 3.5;
      p.pitch = math.max(-1.1, p.pitch - dt * 0.8);
      p.yaw += dt * 0.6;
      p.pos.addScaled(p.forward, p.speed * dt);
      if (rng.nextDouble() < 0.6) _smoke(p.pos + p.forward * -20, 1.4);
      return;
    }
    final handling = 0.85 + 0.45 * skills.handling;
    final targetRoll = c.stickX.clamp(-1.0, 1.0) * 0.95;
    p.roll += (targetRoll - p.roll) * math.min(1, dt * 4);
    p.yaw = wrapAngle(p.yaw + math.sin(p.roll) * 1.3 * handling * dt);
    final py = c.stickY.clamp(-1.0, 1.0);
    p.pitch += py * 0.95 * handling * dt;
    if (py.abs() < 0.05) p.pitch -= p.pitch * math.min(1, dt * 0.35);

    lowWarning = false;
    final aboveFloor = p.pos.y - floorY;
    if (aboveFloor < 220) {
      lowWarning = true;
      if (p.pitch < 0.25) {
        p.pitch += dt * 1.4 * (1 - aboveFloor / 220).clamp(0.0, 1.0);
      }
    }
    if (p.pos.y > ceilY - 150 && p.pitch > 0) {
      p.pitch -= dt * 1.2;
    }
    p.pitch = p.pitch.clamp(-1.0, 1.0);

    final targetSpeed = 250 - math.sin(p.pitch) * 90;
    p.speed += (targetSpeed - p.speed) * math.min(1, dt * 0.8);
    p.pos.addScaled(p.forward, p.speed * dt);
    p.pos.y = p.pos.y.clamp(floorY, ceilY);
  }

  void _guns(double dt, ControlState c) {
    _fireCooldown -= dt;
    heat = math.max(0, heat - dt * 0.32);
    if (jammed && heat < 0.35) jammed = false;
    if (playerDown || jammed || !c.fire || _fireCooldown > 0) return;

    _fireCooldown = 0.095;
    heat += 0.06;
    if (heat >= 1) {
      heat = 1;
      jammed = true;
    }
    final (right, up, fwd) = player.basis();
    final spread = lerpDouble(0.03, 0.007, skills.gunnery);
    final dir =
        (fwd +
                right * ((rng.nextDouble() - 0.5) * 2 * spread) +
                up * ((rng.nextDouble() - 0.5) * 2 * spread))
            .normalized();
    final side = _leftGun ? -1.0 : 1.0;
    _leftGun = !_leftGun;
    final start = player.pos + right * (7 * side) + up * -3 + fwd * 8;
    bullets.add(
      Bullet(
        pos: start,
        vel: dir * bulletSpeed + player.velocity,
        life: 1.15,
        fromPlayer: true,
      ),
    );
    shotsFired++;
    muzzleFlash = 1;
  }

  void _updatePirate(Pirate e, double dt) {
    e.hitFlash = math.max(0, e.hitFlash - dt * 4);
    if (!e.alive) {
      e.fallTime += dt;
      e.roll += dt * 4;
      e.pitch = math.max(-1.2, e.pitch - dt * 0.9);
      e.pos.addScaled(e.forward, e.speed * dt);
      if (rng.nextDouble() < 0.7) _smoke(e.pos.copy(), 1.6);
      if (rng.nextDouble() < 0.25) _fire(e.pos.copy(), 0.4, 14);
      return;
    }

    final toPlayer = player.pos - e.pos;
    final dist = toPlayer.length;
    e.modeTimer -= dt;

    V3 desired;
    switch (e.mode) {
      case PirateMode.engage:
        if (dist < 150 && !playerDown) {
          e.mode = PirateMode.breakAway;
          e.modeTimer = 1.6 + rng.nextDouble() * 1.6;
          final side = rng.nextBool() ? 1.0 : -1.0;
          e.breakDir =
              (e.flatRight * side +
                      V3(0, rng.nextDouble() - 0.4, 0) +
                      e.forward * 0.5)
                  .normalized();
        }
        final lead = dist / 900;
        desired = playerDown
            ? e.forward + V3(0, 0.2, 0)
            : (player.pos + player.velocity * lead) - e.pos;
        // An ace with the player on its tail jinks.
        if (e.cls == PirateClass.ace && dist < 500) {
          final behind = e.forward.dot(toPlayer * (1 / dist)) < -0.5;
          if (behind) {
            desired = desired + e.flatRight * (math.sin(_time * 2.3) * dist);
          }
        }
      case PirateMode.breakAway:
        desired = e.breakDir;
        if (e.modeTimer <= 0) e.mode = PirateMode.engage;
    }
    if (dist > 3600) desired = toPlayer;
    if (e.pos.y < floorY + 200) {
      desired = desired + V3(0, desired.length * 0.8, 0);
    }
    if (e.pos.y > ceilY - 200) {
      desired = desired + V3(0, -desired.length * 0.8, 0);
    }

    steer(e, desired, e.stats.turnRate, dt);
    e.pos.addScaled(e.forward, e.speed * dt);

    // Guns.
    e.fireCooldown -= dt;
    if (playerDown || e.mode != PirateMode.engage) return;
    final aim = e.forward.dot(toPlayer * (1 / dist));
    if (e.fireCooldown <= 0 && dist < e.stats.range && aim > math.cos(0.16)) {
      if (e.burstLeft == 0) e.burstLeft = 4;
      e.burstLeft--;
      e.fireCooldown = e.burstLeft == 0 ? 0.9 + rng.nextDouble() * 1.1 : 0.12;
      final toP = toPlayer * (1 / dist);
      final s = e.stats.spread;
      final dir = (e.forward * 0.45 + toP * 0.55 + randomUnit(rng) * s)
          .normalized();
      bullets.add(
        Bullet(
          pos: e.pos + e.forward * 20,
          vel: dir * 950 + e.velocity,
          life: 1.3,
          fromPlayer: false,
        ),
      );
    }
  }

  /// Turns [f] towards [desired] at most [rate] rad/s.
  static void steer(Flyer f, V3 desired, double rate, double dt) {
    final d = desired.normalized();
    if (d.length2 == 0) return;
    final targetYaw = math.atan2(d.x, d.z);
    final targetPitch = math.asin(d.y.clamp(-1.0, 1.0)).clamp(-0.9, 0.9);
    final diff = wrapAngle(targetYaw - f.yaw);
    final step = rate * dt;
    f.yaw = wrapAngle(f.yaw + diff.clamp(-step, step));
    f.pitch += (targetPitch - f.pitch).clamp(-step * 0.7, step * 0.7);
    final targetRoll = (diff * 1.6).clamp(-1.1, 1.1);
    f.roll += (targetRoll - f.roll) * math.min(1, dt * 3);
  }

  void _moveBullets(double dt) {
    for (final b in bullets) {
      final prev = b.pos.copy();
      b.pos.addScaled(b.vel, dt);
      b.life -= dt;
      if (b.life <= 0) continue;
      if (b.fromPlayer) {
        for (final e in pirates) {
          if (!e.alive) continue;
          if (segmentPointDistance(prev, b.pos, e.pos) < pirateRadius) {
            b.life = 0;
            shotsHit++;
            _hitPirate(e);
            break;
          }
        }
      } else if (!playerDown &&
          segmentPointDistance(prev, b.pos, player.pos) < playerRadius) {
        b.life = 0;
        damagePlayer(_damageFrom(b));
      }
    }
    bullets.removeWhere((b) => b.life <= 0);
  }

  /// Takes [amount] (0..1) off the player's hull.
  void damagePlayer(double amount) {
    if (playerDown) return;
    _health -= amount;
    playerHitFlash = 1;
    if (_health <= 0) {
      _health = 0;
      _fire(player.pos + player.forward * 30, 1.0, 40);
    }
  }

  double _damageFrom(Bullet b) {
    // The bullet does not remember its shooter; use the strongest nearby
    // pirate's damage, which is close enough and keeps Bullet small.
    var dmg = PirateStats.scout.damage;
    for (final e in pirates) {
      if (e.alive && e.pos.distanceTo(b.pos) < 1400) {
        dmg = math.max(dmg, e.stats.damage);
      }
    }
    return dmg;
  }

  void _hitPirate(Pirate e) {
    e.hp--;
    e.hitFlash = 1;
    effects.add(
      Effect(
        kind: EffectKind.spark,
        pos: e.pos.copy(),
        vel: randomUnit(rng) * 60,
        life: 0.25,
        size0: 6,
        size1: 2,
      ),
    );
    if (e.hp <= 0) {
      kills++;
      e.fallTime = 0;
      _fire(e.pos.copy(), 0.9, 34);
      for (var i = 0; i < 8; i++) {
        effects.add(
          Effect(
            kind: EffectKind.debris,
            pos: e.pos.copy(),
            vel: randomUnit(rng) * (80 + rng.nextDouble() * 120),
            life: 1.2,
            size0: 3,
            size1: 2,
          ),
        );
      }
    } else if (e.hp <= e.stats.hp ~/ 2) {
      _smoke(e.pos.copy(), 1.0);
    }
  }

  void _smoke(V3 at, double life) {
    effects.add(
      Effect(
        kind: EffectKind.smoke,
        pos: at,
        vel: randomUnit(rng) * 8,
        life: life,
        size0: 6,
        size1: 22,
      ),
    );
  }

  void _fire(V3 at, double life, double size) {
    effects.add(
      Effect(
        kind: EffectKind.fire,
        pos: at,
        vel: randomUnit(rng) * 20,
        life: life,
        size0: size * 0.4,
        size1: size,
      ),
    );
  }
}
