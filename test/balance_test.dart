import 'package:bulut_korsanlari/campaign/missions.dart';
import 'package:bulut_korsanlari/game/bombing/bombing_sim.dart';
import 'package:bulut_korsanlari/game/dogfight/dogfight_sim.dart';
import 'package:bulut_korsanlari/game/mission_result.dart';
import 'package:bulut_korsanlari/game/raid/raid_sim.dart';
import 'package:flutter_test/flutter_test.dart';

import 'autopilot.dart';

/// Flies [m] with a different random seed, so a result does not hang on
/// one lucky (or unlucky) sequence.
MissionResult fly(MissionDef m, PilotSkills skills, int seed) =>
    switch (m.kind) {
      MissionKind.dogfight => flyDogfight(
        DogfightSim(
          config: DogfightConfig(
            enemies: m.dogfight!.enemies,
            maxActive: m.dogfight!.maxActive,
            seed: seed,
          ),
          skills: skills,
        ),
      ),
      MissionKind.raid => flyRaid(
        RaidSim(
          config: RaidConfig(
            length: m.raid!.length,
            targets: m.raid!.targets,
            quota: m.raid!.quota,
            turretRate: m.raid!.turretRate,
            seed: seed,
          ),
          skills: skills,
        ),
      ),
      MissionKind.bombing => flyBombing(
        BombingSim(
          config: BombingConfig(
            targets: m.bombing!.targets,
            bombs: m.bombing!.bombs,
            length: m.bombing!.length,
            wind: m.bombing!.wind,
            airshipHp: m.bombing!.airshipHp,
            seed: seed,
          ),
          skills: skills,
        ),
      ),
    };

int wins(MissionDef m, PilotSkills skills, {int runs = 10}) {
  var n = 0;
  for (var i = 1; i <= runs; i++) {
    if (fly(m, skills, i * 7 + 3).outcome == MissionOutcome.success) n++;
  }
  return n;
}

void main() {
  // A plain autopilot with no evasive flying stands in for a player of
  // middling skill. It must win each mission at least 3 times in 10;
  // a person who dodges will do better.
  const seasoned = PilotSkills(gunnery: 0.6, handling: 0.6);

  for (final m in campaignMissions) {
    test('${m.id} (${m.kind.name}) can be won', () {
      expect(wins(m, seasoned), greaterThanOrEqualTo(3));
    });
  }

  test('a rookie who only taps targets wins the first raid', () {
    // Lining targets up by hand in the isometric view was too hard on a
    // phone (first TestFlight build); tapping them must be enough.
    final m = campaignMissions.firstWhere((m) => m.kind == MissionKind.raid);
    var n = 0;
    for (var i = 1; i <= 10; i++) {
      final r = flyRaidByTapping(
        RaidSim(
          config: RaidConfig(
            length: m.raid!.length,
            targets: m.raid!.targets,
            quota: m.raid!.quota,
            turretRate: m.raid!.turretRate,
            seed: i * 7 + 3,
          ),
        ),
      );
      if (r.outcome == MissionOutcome.success) n++;
    }
    expect(n, greaterThanOrEqualTo(8));
  });

  test('the first mission is gentle even for a rookie', () {
    expect(
      wins(campaignMissions.first, const PilotSkills()),
      greaterThanOrEqualTo(8),
    );
  });

  test('the final dogfight is a real test for a rookie', () {
    final last = campaignMissions.lastWhere(
      (m) => m.kind == MissionKind.dogfight,
    );
    expect(
      last.dogfight!.enemies.last,
      PirateClass.ace,
      reason: 'the captain arrives last',
    );
    expect(wins(last, const PilotSkills()), lessThanOrEqualTo(5));
  });
}
