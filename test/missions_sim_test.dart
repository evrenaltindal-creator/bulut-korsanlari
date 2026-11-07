import 'package:bulut_korsanlari/core/controls.dart';
import 'package:bulut_korsanlari/core/v3.dart';
import 'package:bulut_korsanlari/game/bombing/bombing_sim.dart';
import 'package:bulut_korsanlari/game/dogfight/dogfight_sim.dart';
import 'package:bulut_korsanlari/game/mission_result.dart';
import 'package:bulut_korsanlari/game/raid/raid_sim.dart';
import 'package:flutter_test/flutter_test.dart';

const dt = 1 / 60;

void run(
  void Function(double dt, ControlState c) step,
  double seconds,
  ControlState c,
) {
  for (var t = 0.0; t < seconds; t += dt) {
    step(dt, c);
  }
}

void main() {
  group('Dogfight', () {
    DogfightSim sim({List<PirateClass> enemies = const [PirateClass.scout]}) =>
        DogfightSim(
          config: DogfightConfig(enemies: enemies, seed: 3),
          skills: const PilotSkills(gunnery: 1, handling: 0.5),
        );

    /// Puts the first pirate straight ahead, flying away on a fixed line.
    Pirate placeAhead(DogfightSim s, double dist) {
      final e = s.pirates.first;
      e.pos.setFrom(s.player.pos + s.player.forward * dist);
      e.yaw = s.player.yaw;
      e.pitch = 0;
      e.mode = PirateMode.breakAway;
      e.breakDir = s.player.forward;
      e.modeTimer = 100;
      return e;
    }

    test('holding fire on a pirate dead ahead shoots it down', () {
      final s = sim();
      placeAhead(s, 350);
      run(s.update, 1.5, ControlState()..fire = true);
      expect(s.kills, 1);
      expect(s.shotsHit, greaterThanOrEqualTo(PirateStats.scout.hp));
    });

    test('the mission succeeds once every pirate is down', () {
      final s = sim();
      placeAhead(s, 350);
      final c = ControlState()..fire = true;
      run(s.update, 1.5, c);
      c.fire = false;
      run(s.update, 3, c);
      expect(s.result?.outcome, MissionOutcome.success);
      expect(s.result?.kills, 1);
    });

    test('guns jam when held too long and recover after cooling', () {
      final s = sim();
      final c = ControlState()..fire = true;
      var t = 0.0;
      while (!s.jammed && t < 10) {
        s.update(dt, c);
        t += dt;
      }
      expect(s.jammed, isTrue);
      final fired = s.shotsFired;
      run(s.update, 1, c);
      expect(s.shotsFired, fired, reason: 'jammed guns must not fire');
      run(s.update, 3, ControlState());
      expect(s.jammed, isFalse);
    });

    test('a pirate facing the player hits back', () {
      final s = sim(enemies: const [PirateClass.ace]);
      final e = s.pirates.first;
      e.pos.setFrom(s.player.pos + s.player.forward * 700);
      e.yaw = wrapAngle(s.player.yaw + 3.14159);
      e.fireCooldown = 0;
      run(s.update, 2.5, ControlState());
      expect(s.health, lessThan(1));
    });

    test('losing the hull ends the mission as shot down', () {
      final s = sim();
      s.damagePlayer(1);
      run(s.update, 3, ControlState());
      expect(s.result?.outcome, MissionOutcome.shotDown);
    });

    test(
      'the cloud sea pushes the nose up instead of swallowing the plane',
      () {
        final s = sim();
        s.player.pos.y = DogfightSim.floorY + 100;
        run(s.update, 4, ControlState()..stickY = -1);
        expect(s.player.pos.y, greaterThanOrEqualTo(DogfightSim.floorY));
      },
    );

    test('better handling turns faster', () {
      DogfightSim with_(double h) => DogfightSim(
        config: const DogfightConfig(enemies: [], seed: 1),
        skills: PilotSkills(handling: h),
      );
      final slow = with_(0);
      final fast = with_(1);
      final c = ControlState()..stickX = 1;
      run(slow.update, 1, c);
      run(fast.update, 1, c);
      expect(fast.player.yaw.abs(), greaterThan(slow.player.yaw.abs()));
    });
  });

  group('Raid', () {
    RaidSim sim(Map<RaidTargetKind, int> targets, {double quota = 0.6}) =>
        RaidSim(
          config: RaidConfig(
            length: 2000,
            targets: targets,
            quota: quota,
            seed: 5,
          ),
          skills: const PilotSkills(gunnery: 1),
        );

    test('targets are laid out on the island (skiffs past the edge)', () {
      final s = sim({RaidTargetKind.crate: 5, RaidTargetKind.skiff: 2});
      for (final t in s.targets) {
        final hw = s.halfWidth(t.u);
        if (t.kind == RaidTargetKind.skiff) {
          expect(t.v, greaterThan(hw));
        } else {
          expect(t.v.abs(), lessThan(hw));
        }
      }
    });

    test('strafing a crate under the reticle destroys it', () {
      final s = sim({RaidTargetKind.crate: 1});
      final t = s.targets.first;
      s.speed = 40;
      s.plane.x = t.u - s.aimDistance - 6;
      s.plane.y = t.v;
      run(s.update, 1.2, ControlState()..fire = true);
      expect(t.alive, isFalse);
    });

    test('a burning fuel tank takes its neighbours with it', () {
      final s = sim({RaidTargetKind.fuel: 1, RaidTargetKind.crate: 1});
      final fuel = s.targets.firstWhere((t) => t.kind == RaidTargetKind.fuel);
      final crate = s.targets.firstWhere((t) => t.kind == RaidTargetKind.crate);
      // Move the crate next to the tank.
      s.targets.remove(crate);
      final near = RaidTarget(RaidTargetKind.crate, fuel.u + 30, fuel.v);
      s.targets.add(near);
      s.speed = 40;
      s.plane.x = fuel.u - s.aimDistance - 6;
      s.plane.y = fuel.v;
      run(s.update, 1.2, ControlState()..fire = true);
      expect(fuel.alive, isFalse);
      expect(near.alive, isFalse);
    });

    test('flying past without shooting misses the objective', () {
      final s = sim({RaidTargetKind.crate: 3});
      run(s.update, 30, ControlState());
      expect(s.result?.outcome, MissionOutcome.objectiveFailed);
      expect(s.result?.targetsTotal, 3);
    });
  });

  group('Bombing', () {
    BombingSim sim(List<BombTargetSpec> targets, {double wind = 20}) =>
        BombingSim(
          config: BombingConfig(
            targets: targets,
            bombs: 6,
            wind: wind,
            length: 1600,
            seed: 7,
          ),
          skills: const PilotSkills(gunnery: 1),
        );

    test('the sight ignores the wind; the bomb does not', () {
      final s = sim(const [
        BombTargetSpec(BombTargetKind.hangar, primary: true),
      ], wind: 25);
      final drift = s.trueImpactPoint.x - s.sightPoint.x;
      expect(drift, closeTo(25 * BombingSim.fallTime, 1e-6));
      s.dropBomb();
      final b = s.bombs.single;
      expect(b.ground.x, closeTo(s.trueImpactPoint.x, 6));
      expect(b.ground.y, closeTo(s.trueImpactPoint.y, 6));
    });

    test('bombs on the primary target win the mission', () {
      final s = sim(const [
        BombTargetSpec(BombTargetKind.hangar, primary: true),
      ]);
      final t = s.targets.single;
      // Line up so the real impact point falls on the hangar.
      s.plane.x = t.x - s.config.wind * BombingSim.fallTime;
      s.plane.y = t.y - s.speed * 0.9 * BombingSim.fallTime;
      final c = ControlState();
      for (var i = 0; i < 3; i++) {
        s.dropBomb();
        run(s.update, 0.4, c);
      }
      run(s.update, 2, c);
      expect(t.alive, isFalse);
      run(s.update, 30, c);
      expect(s.result?.outcome, MissionOutcome.success);
    });

    test('missing the primary target fails the objective', () {
      final s = sim(const [
        BombTargetSpec(BombTargetKind.hangar, primary: true),
      ]);
      run(s.update, 30, ControlState());
      expect(s.result?.outcome, MissionOutcome.objectiveFailed);
    });

    test('bombs run out', () {
      final s = sim(const [BombTargetSpec(BombTargetKind.depot)]);
      for (var i = 0; i < 20; i++) {
        s.dropBomb();
        run(s.update, 0.4, ControlState());
      }
      expect(s.bombsLeft, 0);
    });

    test('the airship cruises ahead, slower than the plane', () {
      final s = sim(const [
        BombTargetSpec(BombTargetKind.airship, primary: true),
      ]);
      final ship = s.targets.single;
      final y0 = ship.y;
      final gap0 = ship.y - s.plane.y;
      run(s.update, 10, ControlState());
      expect(ship.y, greaterThan(y0));
      expect(
        ship.y - s.plane.y,
        lessThan(gap0),
        reason: 'the plane catches up',
      );
      expect(ship.x.abs(), lessThanOrEqualTo(201));
    });
  });
}
