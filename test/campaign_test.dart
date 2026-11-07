import 'dart:convert';
import 'dart:math' as math;

import 'package:bulut_korsanlari/campaign/campaign.dart';
import 'package:bulut_korsanlari/campaign/missions.dart';
import 'package:bulut_korsanlari/campaign/store.dart';
import 'package:bulut_korsanlari/game/mission_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Fixed implements math.Random {
  _Fixed(this.value);

  final double value;

  @override
  double nextDouble() => value;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

const win = MissionResult(
  outcome: MissionOutcome.success,
  kills: 2,
  shotsFired: 10,
  shotsHit: 5,
);
const down = MissionResult(outcome: MissionOutcome.shotDown, kills: 1);

void main() {
  test('every mission has the config its kind needs', () {
    for (final m in campaignMissions) {
      switch (m.kind) {
        case MissionKind.dogfight:
          expect(m.dogfight, isNotNull, reason: m.id);
        case MissionKind.raid:
          expect(m.raid, isNotNull, reason: m.id);
        case MissionKind.bombing:
          expect(m.bombing, isNotNull, reason: m.id);
      }
      expect(m.chapter, inInclusiveRange(1, chapterCount));
    }
    expect(
      campaignMissions.map((m) => m.id).toSet().length,
      campaignMissions.length,
    );
    final kinds = campaignMissions.map((m) => m.kind).toSet();
    expect(
      kinds,
      MissionKind.values.toSet(),
      reason: 'the campaign uses all three mission types',
    );
  });

  test('a success moves the campaign on and trains the pilot', () {
    final c = Campaign.start('Deniz Kaya');
    final before = c.activePilot.gunnery;
    final d = c.apply(win, rng: _Fixed(0.5), recruitName: () => 'X');
    expect(c.missionIndex, 1);
    expect(c.activePilot.kills, 2);
    expect(c.activePilot.successes, 1);
    expect(c.activePilot.gunnery, greaterThan(before));
    expect(d.gunneryGain, greaterThan(0));
    expect(c.log.single.kind, LogKind.success);
  });

  test('a failed objective repeats the mission', () {
    final c = Campaign.start('Ece');
    c.apply(
      const MissionResult(outcome: MissionOutcome.objectiveFailed),
      rng: _Fixed(0.5),
      recruitName: () => 'X',
    );
    expect(c.missionIndex, 0);
    expect(c.activePilot.missions, 1);
  });

  test('a lucky pilot is rescued after being shot down', () {
    final c = Campaign.start('Bora');
    final d = c.apply(down, rng: _Fixed(0), recruitName: () => 'X');
    expect(d.rescued, isTrue);
    expect(d.pilotLost, isFalse);
    expect(c.pilots, hasLength(1));
    expect(c.missionIndex, 0);
  });

  test('an unlucky pilot is lost and a recruit takes over', () {
    final c = Campaign.start('Bora');
    final d = c.apply(down, rng: _Fixed(0.99), recruitName: () => 'Ada Yel');
    expect(d.pilotLost, isTrue);
    expect(d.newPilotName, 'Ada Yel');
    expect(c.pilots.first.status, PilotStatus.lost);
    expect(c.pilots.first.lostOn, 'm1');
    expect(
      c.pilots.first.kills,
      1,
      reason: 'kills before going down still count',
    );
    expect(c.activePilot.name, 'Ada Yel');
    expect(c.missionIndex, 0);
  });

  test('ranks follow kills and successes and are reported', () {
    final c = Campaign.start('Ekin');
    Debrief? promoted;
    for (var i = 0; i < 3 && promoted == null; i++) {
      final d = c.apply(win, rng: _Fixed(0.5), recruitName: () => 'X');
      if (d.promotedTo != null) promoted = d;
    }
    expect(promoted?.promotedTo, 'rank.1');
  });

  test('skills never pass 1', () {
    final c = Campaign.start('Tuna');
    c.activePilot
      ..gunnery = 0.99
      ..handling = 0.99;
    c.apply(win, rng: _Fixed(0.5), recruitName: () => 'X');
    expect(c.activePilot.gunnery, lessThanOrEqualTo(1));
    expect(c.activePilot.handling, lessThanOrEqualTo(1));
  });

  test('winning every mission finishes the campaign', () {
    final c = Campaign.start('Kuzey');
    Debrief? last;
    while (!c.finished) {
      last = c.apply(win, rng: _Fixed(0.5), recruitName: () => 'X');
    }
    expect(last!.campaignComplete, isTrue);
    expect(c.log, hasLength(campaignMissions.length));
  });

  test('JSON round trip keeps everything', () {
    final c = Campaign.start('Selin');
    c.apply(win, rng: _Fixed(0.5), recruitName: () => 'X');
    c.apply(down, rng: _Fixed(0.99), recruitName: () => 'Umut Sever');
    final back = Campaign.fromJson(
      (jsonDecode(jsonEncode(c.toJson())) as Map).cast<String, Object?>(),
    );
    expect(back.missionIndex, c.missionIndex);
    expect(back.pilots.map((p) => p.name), ['Selin', 'Umut Sever']);
    expect(back.pilots.first.status, PilotStatus.lost);
    expect(back.pilots.first.gunnery, c.pilots.first.gunnery);
    expect(back.log.map((e) => e.kind), [LogKind.success, LogKind.lost]);
  });

  group('GameStore', () {
    test('saves and restores the campaign and settings', () async {
      SharedPreferences.setMockInitialValues({});
      final a = await GameStore.load(deviceLang: 'tr');
      expect(a.lang, 'tr');
      expect(a.hasCampaign, isFalse);
      await a.setLang('tr');
      await a.startCampaign('Defne');
      await a.setInvertY(true);
      await a.recordResult(win);

      final b = await GameStore.load(deviceLang: 'en');
      expect(
        b.lang,
        'tr',
        reason: 'a chosen language beats the device language',
      );
      expect(b.invertY, isTrue);
      expect(b.campaign!.activePilot.name, 'Defne');
      expect(b.campaign!.missionIndex, 1);
    });

    test('an unknown device language falls back to English', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await GameStore.load(deviceLang: 'de');
      expect(s.lang, 'en');
    });

    test('a corrupt save does not crash the game', () async {
      SharedPreferences.setMockInitialValues({'campaign_v1': '{not json'});
      final s = await GameStore.load(deviceLang: 'tr');
      expect(s.hasCampaign, isFalse);
    });

    test('an empty name gets a random one', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await GameStore.load(deviceLang: 'tr');
      await s.startCampaign('   ');
      expect(s.campaign!.activePilot.name.trim(), isNotEmpty);
    });
  });
}
