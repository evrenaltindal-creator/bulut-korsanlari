import 'dart:math' as math;

import 'package:bulut_korsanlari/core/controls.dart';
import 'package:bulut_korsanlari/game/bombing/bombing_sim.dart';
import 'package:bulut_korsanlari/game/dogfight/camera3.dart';
import 'package:bulut_korsanlari/game/dogfight/dogfight_sim.dart';
import 'package:bulut_korsanlari/game/mission_result.dart';
import 'package:bulut_korsanlari/game/raid/raid_sim.dart';

/// Simple autopilots that fly each mission type the way a modest human
/// would. Used to check that every campaign mission can be won.
const double _dt = 1 / 60;

MissionResult flyDogfight(DogfightSim s, {double limit = 240}) {
  final c = ControlState();
  for (var t = 0.0; t < limit && s.result == null; t += _dt) {
    final alive = s.pirates.where((p) => p.alive).toList();
    if (alive.isEmpty) {
      c
        ..fire = false
        ..stickX = 0
        ..stickY = 0;
    } else {
      alive.sort(
        (a, b) => a.pos
            .distanceTo(s.player.pos)
            .compareTo(b.pos.distanceTo(s.player.pos)),
      );
      final target = alive.first;
      final cam = Camera3.follow(
        s.player,
        width: 800,
        height: 400,
        rollFactor: 0,
      );
      final lead =
          target.pos +
          target.velocity * (target.pos.distanceTo(s.player.pos) / 1300);
      final rel = cam.toCamera(lead);
      final ax = math.atan2(rel.x, rel.z);
      final ay = math.atan2(rel.y, rel.z);
      c.stickX = (ax * 2.5).clamp(-1.0, 1.0);
      c.stickY = (ay * 2.5).clamp(-1.0, 1.0);
      final dist = target.pos.distanceTo(s.player.pos);
      c.fire =
          rel.z > 0 &&
          ax.abs() < 0.06 &&
          ay.abs() < 0.06 &&
          dist < 800 &&
          s.heat < 0.85;
    }
    s.update(_dt, c);
  }
  return s.result ??
      const MissionResult(outcome: MissionOutcome.objectiveFailed);
}

MissionResult flyRaid(RaidSim s, {double limit = 120}) {
  final c = ControlState();
  for (var t = 0.0; t < limit && s.result == null; t += _dt) {
    final aim = s.aimPoint;
    // The next living target the reticle can still reach.
    RaidTarget? next;
    for (final tg in s.targets) {
      if (!tg.alive || tg.u < aim.x - 15) continue;
      if (next == null || tg.u < next.u) next = tg;
    }
    if (next != null) {
      c.stickX = ((next.v - s.plane.y) / 40).clamp(-1.0, 1.0);
      c.fire = (next.u - aim.x).abs() < 60 && (next.v - aim.y).abs() < 25;
    } else {
      c
        ..stickX = 0
        ..fire = false;
    }
    c.stickY = -0.3;
    s.update(_dt, c);
  }
  return s.result ??
      const MissionResult(outcome: MissionOutcome.objectiveFailed);
}

MissionResult flyBombing(BombingSim s, {double limit = 120}) {
  final c = ControlState();
  for (var t = 0.0; t < limit && s.result == null; t += _dt) {
    final impact = s.trueImpactPoint;
    BombTarget? next;
    for (final tg in s.targets) {
      final landsAt = tg.y + tg.vy * BombingSim.fallTime;
      if (!tg.alive || landsAt < impact.y - 20) continue;
      final better =
          next == null ||
          (tg.primary && !next.primary) ||
          (tg.primary == next.primary && tg.y < next.y);
      if (better) next = tg;
    }
    c.drop = false;
    if (next != null) {
      // Lead a moving ship by its own drift during the fall.
      final tx = next.x + next.vx * BombingSim.fallTime;
      final ty = next.y + next.vy * BombingSim.fallTime;
      c.stickX = ((tx - impact.x) / 60).clamp(-1.0, 1.0);
      c.stickY = 0;
      final (ex, ey) = BombTarget.extent(next.kind);
      c.drop = (impact.y - ty).abs() < ey + 25 && (impact.x - tx).abs() < ex;
    }
    s.update(_dt, c);
  }
  return s.result ??
      const MissionResult(outcome: MissionOutcome.objectiveFailed);
}
