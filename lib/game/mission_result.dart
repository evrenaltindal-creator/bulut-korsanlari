enum MissionOutcome {
  /// Objective met and the pilot came home.
  success,

  /// The pilot came home but the objective was not met.
  objectiveFailed,

  /// The plane went down. Whether the pilot survives is decided by the
  /// campaign, not by the mission.
  shotDown,
}

class MissionResult {
  const MissionResult({
    required this.outcome,
    this.kills = 0,
    this.targetsDestroyed = 0,
    this.targetsTotal = 0,
    this.shotsFired = 0,
    this.shotsHit = 0,
    this.healthLeft = 1,
  });

  final MissionOutcome outcome;
  final int kills;
  final int targetsDestroyed;
  final int targetsTotal;
  final int shotsFired;
  final int shotsHit;

  /// 0..1
  final double healthLeft;

  double get accuracy => shotsFired == 0 ? 0 : shotsHit / shotsFired;
}

/// The pilot's abilities, both 0..1. They grow with experience.
class PilotSkills {
  const PilotSkills({this.gunnery = 0.3, this.handling = 0.3});

  /// Tighter gun spread, steadier bomb sight.
  final double gunnery;

  /// Faster turns and a better chance to survive being shot down.
  final double handling;
}

/// Common shape of the three mission simulations.
abstract class MissionSim {
  /// 0..1
  double get health;

  /// Non-null once the mission is over.
  MissionResult? get result;

  /// Seconds since the mission began.
  double get time;
}
