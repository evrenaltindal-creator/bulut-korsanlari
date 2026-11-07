import '../audio/music.dart';
import '../game/bombing/bombing_sim.dart';
import '../game/dogfight/dogfight_sim.dart';
import '../game/raid/raid_sim.dart';

enum MissionKind { dogfight, raid, bombing }

/// One page of the campaign. Its texts live under `<id>.title`,
/// `<id>.brief`, `<id>.win` and `<id>.lose` in the strings table.
class MissionDef {
  const MissionDef({
    required this.id,
    required this.chapter,
    required this.kind,
    this.dogfight,
    this.raid,
    this.bombing,
    this.music,
  });

  final String id;
  final int chapter;
  final MissionKind kind;
  final DogfightConfig? dogfight;
  final RaidConfig? raid;
  final BombingConfig? bombing;

  /// Overrides the mission type's usual music (the final battles).
  final MusicTrack? music;

  MusicTrack get musicTrack =>
      music ??
      switch (kind) {
        MissionKind.dogfight => MusicTrack.dogfight,
        MissionKind.raid => MusicTrack.raid,
        MissionKind.bombing => MusicTrack.bombing,
      };

  String get titleKey => '$id.title';
  String get briefKey => '$id.brief';
  String get winKey => '$id.win';
  String get loseKey => '$id.lose';
}

const int chapterCount = 3;

const List<MissionDef> campaignMissions = [
  MissionDef(
    id: 'm1',
    chapter: 1,
    kind: MissionKind.dogfight,
    dogfight: DogfightConfig(
      enemies: [PirateClass.scout, PirateClass.scout],
      seed: 11,
    ),
  ),
  MissionDef(
    id: 'm2',
    chapter: 1,
    kind: MissionKind.raid,
    raid: RaidConfig(
      length: 2600,
      seed: 21,
      quota: 0.55,
      turretRate: 0.7,
      targets: {
        RaidTargetKind.crate: 7,
        RaidTargetKind.fuel: 3,
        RaidTargetKind.turret: 2,
      },
    ),
  ),
  MissionDef(
    id: 'm3',
    chapter: 1,
    kind: MissionKind.dogfight,
    dogfight: DogfightConfig(
      enemies: [PirateClass.scout, PirateClass.raider, PirateClass.raider],
      seed: 31,
    ),
  ),
  MissionDef(
    id: 'm4',
    chapter: 2,
    kind: MissionKind.bombing,
    bombing: BombingConfig(
      seed: 41,
      bombs: 12,
      wind: 18,
      targets: [
        BombTargetSpec(BombTargetKind.hangar, primary: true, count: 3),
        BombTargetSpec(BombTargetKind.depot, count: 3),
        BombTargetSpec(BombTargetKind.gun, count: 3),
      ],
    ),
  ),
  MissionDef(
    id: 'm5',
    chapter: 2,
    kind: MissionKind.dogfight,
    dogfight: DogfightConfig(
      enemies: [
        PirateClass.raider,
        PirateClass.raider,
        PirateClass.raider,
        PirateClass.ace,
      ],
      seed: 51,
    ),
  ),
  MissionDef(
    id: 'm6',
    chapter: 2,
    kind: MissionKind.raid,
    raid: RaidConfig(
      length: 3400,
      seed: 61,
      quota: 0.5,
      targets: {
        RaidTargetKind.skiff: 5,
        RaidTargetKind.crate: 6,
        RaidTargetKind.fuel: 3,
        RaidTargetKind.turret: 4,
      },
    ),
  ),
  MissionDef(
    id: 'm7',
    chapter: 3,
    kind: MissionKind.bombing,
    bombing: BombingConfig(
      seed: 71,
      bombs: 14,
      wind: -26,
      airshipHp: 8,
      targets: [
        BombTargetSpec(BombTargetKind.airship, primary: true),
        BombTargetSpec(BombTargetKind.gun, count: 4),
        BombTargetSpec(BombTargetKind.depot, count: 2),
      ],
    ),
  ),
  MissionDef(
    id: 'm8',
    music: MusicTrack.finale,
    chapter: 3,
    kind: MissionKind.dogfight,
    dogfight: DogfightConfig(
      // The escort first; Captain Raven joins as they fall.
      enemies: [
        PirateClass.raider,
        PirateClass.raider,
        PirateClass.raider,
        PirateClass.raider,
        PirateClass.ace,
      ],
      maxActive: 3,
      seed: 81,
    ),
  ),
  MissionDef(
    id: 'm9',
    music: MusicTrack.finale,
    chapter: 3,
    kind: MissionKind.bombing,
    bombing: BombingConfig(
      seed: 91,
      bombs: 16,
      wind: 30,
      length: 2600,
      airshipHp: 10,
      targets: [
        BombTargetSpec(BombTargetKind.airship, primary: true),
        BombTargetSpec(BombTargetKind.hangar, primary: true, count: 2),
        BombTargetSpec(BombTargetKind.gun, count: 5),
        BombTargetSpec(BombTargetKind.depot, count: 3),
      ],
    ),
  ),
];
