import 'v3.dart';

enum EffectKind { spark, fire, smoke, flak, splash, debris }

/// A short-lived visual effect in world coordinates.
///
/// Each mode projects these with its own camera.
class Effect {
  Effect({
    required this.kind,
    required this.pos,
    V3? vel,
    required this.life,
    required this.size0,
    required this.size1,
  }) : vel = vel ?? V3.zero();

  final EffectKind kind;
  final V3 pos;
  final V3 vel;
  final double life;
  final double size0;
  final double size1;
  double age = 0;

  double get t => (age / life).clamp(0.0, 1.0);
  double get size => size0 + (size1 - size0) * t;
  bool get done => age >= life;
}

class EffectList {
  final List<Effect> items = [];

  void add(Effect e) {
    // A hard cap keeps a long burst of fire from growing the list forever.
    if (items.length > 400) items.removeAt(0);
    items.add(e);
  }

  void update(double dt, {double drag = 0.6, double rise = 0}) {
    for (final e in items) {
      e.age += dt;
      e.pos.addScaled(e.vel, dt);
      final k = 1 - drag * dt;
      e.vel.x *= k;
      e.vel.y *= k;
      e.vel.z *= k;
      if (e.kind == EffectKind.smoke) e.pos.y += rise * dt;
    }
    items.removeWhere((e) => e.done);
  }
}
