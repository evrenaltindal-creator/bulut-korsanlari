import 'dart:math' as math;

import '../game/mission_result.dart';
import 'missions.dart';

enum PilotStatus { active, lost }

class Pilot {
  Pilot({
    required this.id,
    required this.name,
    this.gunnery = 0.3,
    this.handling = 0.3,
    this.missions = 0,
    this.successes = 0,
    this.kills = 0,
    this.status = PilotStatus.active,
    this.lostOn,
  });

  factory Pilot.fromJson(Map<String, Object?> j) => Pilot(
    id: j['id']! as int,
    name: j['name']! as String,
    gunnery: (j['gunnery']! as num).toDouble(),
    handling: (j['handling']! as num).toDouble(),
    missions: j['missions']! as int,
    successes: j['successes']! as int,
    kills: j['kills']! as int,
    status: PilotStatus.values.byName(j['status']! as String),
    lostOn: j['lostOn'] as String?,
  );

  final int id;
  final String name;
  double gunnery;
  double handling;
  int missions;
  int successes;
  int kills;
  PilotStatus status;

  /// Mission id on which the pilot was lost.
  String? lostOn;

  PilotSkills get skills => PilotSkills(gunnery: gunnery, handling: handling);

  /// Rank index 0..4, from kills and successful sorties.
  int get rank {
    final score = kills + successes * 2;
    if (score >= 28) return 4;
    if (score >= 18) return 3;
    if (score >= 10) return 2;
    if (score >= 4) return 1;
    return 0;
  }

  String get rankKey => 'rank.$rank';

  /// Chance to bail out and be picked up after being shot down.
  double get survivalChance => (0.45 + 0.35 * handling).clamp(0.0, 0.85);

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'gunnery': gunnery,
    'handling': handling,
    'missions': missions,
    'successes': successes,
    'kills': kills,
    'status': status.name,
    'lostOn': lostOn,
  };
}

enum LogKind { success, failed, rescued, lost }

/// One line of the squadron's diary.
class LogEntry {
  const LogEntry({
    required this.day,
    required this.missionId,
    required this.pilotName,
    required this.kind,
  });

  factory LogEntry.fromJson(Map<String, Object?> j) => LogEntry(
    day: j['day']! as int,
    missionId: j['missionId']! as String,
    pilotName: j['pilotName']! as String,
    kind: LogKind.values.byName(j['kind']! as String),
  );

  final int day;
  final String missionId;
  final String pilotName;
  final LogKind kind;

  Map<String, Object?> toJson() => {
    'day': day,
    'missionId': missionId,
    'pilotName': pilotName,
    'kind': kind.name,
  };
}

/// What the debriefing screen shows after a mission.
class Debrief {
  const Debrief({
    required this.mission,
    required this.result,
    required this.pilotName,
    this.rescued = false,
    this.pilotLost = false,
    this.newPilotName,
    this.gunneryGain = 0,
    this.handlingGain = 0,
    this.promotedTo,
    this.campaignComplete = false,
  });

  final MissionDef mission;
  final MissionResult result;
  final String pilotName;
  final bool rescued;
  final bool pilotLost;
  final String? newPilotName;
  final double gunneryGain;
  final double handlingGain;

  /// Rank key if the pilot was promoted.
  final String? promotedTo;
  final bool campaignComplete;
}

class Campaign {
  Campaign({required this.pilots, this.missionIndex = 0, List<LogEntry>? log})
    : log = log ?? [];

  factory Campaign.start(String pilotName) =>
      Campaign(pilots: [Pilot(id: 1, name: pilotName)]);

  factory Campaign.fromJson(Map<String, Object?> j) => Campaign(
    pilots: [
      for (final p in j['pilots']! as List<Object?>)
        Pilot.fromJson((p! as Map).cast<String, Object?>()),
    ],
    missionIndex: j['missionIndex']! as int,
    log: [
      for (final e in j['log']! as List<Object?>)
        LogEntry.fromJson((e! as Map).cast<String, Object?>()),
    ],
  );

  final List<Pilot> pilots;
  int missionIndex;
  final List<LogEntry> log;

  bool get finished => missionIndex >= campaignMissions.length;
  MissionDef get currentMission =>
      campaignMissions[math.min(missionIndex, campaignMissions.length - 1)];
  Pilot get activePilot =>
      pilots.lastWhere((p) => p.status == PilotStatus.active);
  int get day => log.length + 1;
  int get totalKills => pilots.fold(0, (a, p) => a + p.kills);

  /// Records the outcome of the current mission and returns the
  /// debriefing. [rng] decides whether a downed pilot survives;
  /// [recruitName] names the replacement if not.
  Debrief apply(
    MissionResult r, {
    required math.Random rng,
    required String Function() recruitName,
  }) {
    final mission = currentMission;
    final pilot = activePilot;
    final rankBefore = pilot.rank;
    pilot.missions++;
    pilot.kills += r.kills;

    var gGain = 0.0;
    var hGain = 0.0;
    var rescued = false;
    var lost = false;
    String? recruit;
    LogKind kind;

    switch (r.outcome) {
      case MissionOutcome.success:
        pilot.successes++;
        (gGain, hGain) = switch (mission.kind) {
          MissionKind.dogfight => (
            0.04 + 0.05 * r.accuracy.clamp(0.0, 1.0),
            0.06,
          ),
          MissionKind.raid => (0.06, 0.03),
          MissionKind.bombing => (0.05, 0.04),
        };
        missionIndex++;
        kind = LogKind.success;
      case MissionOutcome.objectiveFailed:
        gGain = 0.02;
        hGain = 0.02;
        kind = LogKind.failed;
      case MissionOutcome.shotDown:
        if (rng.nextDouble() < pilot.survivalChance) {
          rescued = true;
          hGain = 0.02;
          kind = LogKind.rescued;
        } else {
          lost = true;
          pilot.status = PilotStatus.lost;
          pilot.lostOn = mission.id;
          final nextId = pilots.fold(0, (a, p) => math.max(a, p.id)) + 1;
          recruit = recruitName();
          pilots.add(
            Pilot(id: nextId, name: recruit, gunnery: 0.25, handling: 0.25),
          );
          kind = LogKind.lost;
        }
    }

    if (!lost) {
      gGain = math.min(gGain, 1 - pilot.gunnery);
      hGain = math.min(hGain, 1 - pilot.handling);
      pilot.gunnery += gGain;
      pilot.handling += hGain;
    }
    log.add(
      LogEntry(
        day: day,
        missionId: mission.id,
        pilotName: pilot.name,
        kind: kind,
      ),
    );

    return Debrief(
      mission: mission,
      result: r,
      pilotName: pilot.name,
      rescued: rescued,
      pilotLost: lost,
      newPilotName: recruit,
      gunneryGain: lost ? 0 : gGain,
      handlingGain: lost ? 0 : hGain,
      promotedTo: !lost && pilot.rank > rankBefore ? pilot.rankKey : null,
      campaignComplete: finished,
    );
  }

  Map<String, Object?> toJson() => {
    'pilots': [for (final p in pilots) p.toJson()],
    'missionIndex': missionIndex,
    'log': [for (final e in log) e.toJson()],
  };
}

const List<String> _givenNames = [
  'Deniz',
  'Ece',
  'Bora',
  'Ayaz',
  'Derin',
  'Toprak',
  'Ilgın',
  'Kuzey',
  'Ada',
  'Umut',
  'Nehir',
  'Arda',
  'Defne',
  'Poyraz',
  'Lodos',
  'Yağmur',
  'Ekin',
  'Çağan',
  'Selin',
  'Tuna',
];

const List<String> _familyNames = [
  'Kaya',
  'Yel',
  'Bulut',
  'Ergin',
  'Tanyeri',
  'Özkanat',
  'Akdoğan',
  'Sever',
  'Göktaş',
  'Rüzgârlı',
  'Pusulacı',
  'Demirtaş',
];

String randomPilotName(math.Random rng) =>
    '${_givenNames[rng.nextInt(_givenNames.length)]} ${_familyNames[rng.nextInt(_familyNames.length)]}';
