import 'package:bulut_korsanlari/campaign/missions.dart';
import 'package:bulut_korsanlari/game/bombing/bombing_sim.dart';
import 'package:bulut_korsanlari/game/dogfight/dogfight_sim.dart';
import 'package:bulut_korsanlari/game/mission_result.dart';
import 'package:bulut_korsanlari/game/raid/raid_sim.dart';
import 'package:flutter_test/flutter_test.dart';

import 'autopilot.dart';

MissionResult fly(MissionDef m, PilotSkills skills) => switch (m.kind) {
  MissionKind.dogfight => flyDogfight(
    DogfightSim(config: m.dogfight!, skills: skills),
  ),
  MissionKind.raid => flyRaid(RaidSim(config: m.raid!, skills: skills)),
  MissionKind.bombing => flyBombing(
    BombingSim(config: m.bombing!, skills: skills),
  ),
};

void main() {
  // A plain autopilot with no evasive flying stands in for a player of
  // middling skill. If it cannot win a mission, a person will struggle.
  const seasoned = PilotSkills(gunnery: 0.6, handling: 0.6);

  for (final m in campaignMissions) {
    test('${m.id} (${m.kind.name}) can be won', () {
      final r = fly(m, seasoned);
      expect(r.outcome, MissionOutcome.success);
    });
  }

  test('the first mission is gentle even for a rookie', () {
    final r = fly(campaignMissions.first, const PilotSkills());
    expect(r.outcome, MissionOutcome.success);
    expect(r.healthLeft, greaterThan(0.6));
  });

  test('aces are a real threat to a rookie', () {
    final aceMissions = campaignMissions.where(
      (m) => m.dogfight?.enemies.contains(PirateClass.ace) ?? false,
    );
    expect(aceMissions, isNotEmpty);
    final hp = [
      for (final m in aceMissions) fly(m, const PilotSkills()).healthLeft,
    ];
    expect(hp.reduce((a, b) => a < b ? a : b), lessThan(0.5));
  });
}
