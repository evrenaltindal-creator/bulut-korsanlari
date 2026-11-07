import 'dart:math' as math;
import 'dart:ui';

import '../../core/effects.dart';
import '../../core/v3.dart';
import '../paint_kit.dart';
import 'raid_sim.dart';

/// Isometric view of the strafing run.
class RaidPainter {
  RaidPainter(this.sim, this.tr) {
    final rng = math.Random(sim.config.seed * 13 + 5);
    for (var u = 20.0; u < sim.config.length; u += 14) {
      final hw = sim.halfWidth(u);
      if (hw < 25) continue;
      for (var k = 0; k < 2; k++) {
        _tufts.add(
          Offset(
            u + rng.nextDouble() * 14,
            (rng.nextDouble() * 2 - 1) * (hw - 12),
          ),
        );
      }
    }
    for (var i = 0; i < 26; i++) {
      _farClouds.add((
        Offset(rng.nextDouble() * 3000, rng.nextDouble()),
        CloudShape(rng, puffs: 5),
        40 + rng.nextDouble() * 60,
      ));
    }
  }

  // 2:1 isometric axes: u goes up-right, v goes down-right, z goes up.
  static const _au = Offset(0.894, -0.447);
  static const _av = Offset(0.894, 0.447);

  final RaidSim sim;
  final Tr tr;
  final List<Offset> _tufts = [];
  final List<(Offset, CloudShape, double)> _farClouds = [];

  late double _s;
  late Offset _anchor;
  late double _camU;
  late double _camV;

  Offset iso(double u, double v, double z) =>
      _anchor +
      (_au * (u - _camU) + _av * (v - _camV)) * _s -
      Offset(0, z * _s);

  void paint(Canvas canvas, Size size, EdgeInsetsLike safe) {
    _s = size.height / 430;
    _anchor = Offset(size.width * 0.3, size.height * 0.6);
    _camU = sim.plane.x;
    _camV = sim.plane.y * 0.55;

    _paintBackground(canvas, size);
    _paintIsland(canvas, size);

    // Everything standing on or above the island, far to near.
    final items = <(double, void Function())>[];
    double key(double u, double v) => v - u;
    final uMin = _camU - 700;
    final uMax = _camU + 1300;
    for (final (u, v, kind) in sim.props) {
      if (u < uMin || u > uMax) continue;
      items.add((key(u, v), () => _paintProp(canvas, u, v, kind)));
    }
    for (final (u, len) in sim.docks) {
      if (u < uMin || u > uMax) continue;
      final hw = sim.halfWidth(u);
      items.add((key(u, hw), () => _paintDock(canvas, u, hw, len)));
    }
    for (final t in sim.targets) {
      if (t.u < uMin || t.u > uMax) continue;
      items.add((key(t.u, t.v), () => _paintTarget(canvas, t)));
    }
    items.sort((a, b) => a.$1.compareTo(b.$1));
    for (final it in items) {
      it.$2();
    }

    _paintReticle(canvas);
    _paintShots(canvas);
    _paintPlane(canvas);
    _paintFlak(canvas);
    _paintEffects(canvas);
    _paintHud(canvas, size, safe);

    if (sim.hitFlash > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Palette.danger.withValues(alpha: 0.22 * sim.hitFlash),
      );
    }
  }

  void _paintBackground(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          const [Palette.skyMid, Color(0xFFB9C9DE), Palette.cloudSeaNear],
          const [0, 0.55, 1],
        ),
    );
    // A layer of cloud far below, sliding slowly for depth.
    for (final (o, shape, r) in _farClouds) {
      final x = (o.dx - _camU * 0.35) % 3000;
      final px = x / 3000 * (size.width + 400) - 200;
      final py = size.height * (0.25 + o.dy * 0.85) + (_camU * 0.1) % 40;
      shape.paint(canvas, Offset(px, py), r * _s, 0.55);
    }
  }

  void _paintIsland(Canvas canvas, Size size) {
    final L = sim.config.length;
    final u0 = math.max(0.0, _camU - 900);
    final u1 = math.min(L, _camU + 1500);
    if (u1 <= u0) return;
    const step = 24.0;
    final us = <double>[];
    for (var u = u0; u < u1; u += step) {
      us.add(u);
    }
    us.add(u1);

    double ends(double u) => smoothstep(0, 260, u) * smoothstep(L, L - 260, u);

    // Rocky underside hanging below the front (right) edge.
    final under = Path();
    for (var i = 0; i < us.length; i++) {
      final u = us[i];
      final p = iso(u, sim.halfWidth(u), 0);
      i == 0 ? under.moveTo(p.dx, p.dy) : under.lineTo(p.dx, p.dy);
    }
    for (var i = us.length - 1; i >= 0; i--) {
      final u = us[i];
      final p = iso(
        u,
        sim.halfWidth(u) * 0.15,
        -sim.undersideDepth(u) * ends(u),
      );
      under.lineTo(p.dx, p.dy);
    }
    under.close();
    canvas.drawPath(
      under,
      Paint()
        ..shader = Gradient.linear(
          iso(_camU, 0, 0),
          iso(_camU, 0, -200),
          const [Palette.rockLight, Palette.rock, Palette.rockDark],
          const [0, 0.4, 1],
        ),
    );
    // Strata lines.
    final strata = Paint()
      ..color = const Color(0x553A2A24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final f in [0.25, 0.5, 0.72]) {
      final path = Path();
      for (var i = 0; i < us.length; i++) {
        final u = us[i];
        final hw = sim.halfWidth(u);
        final p = iso(
          u,
          lerpDouble(hw, hw * 0.15, f),
          -sim.undersideDepth(u) * ends(u) * f,
        );
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, strata);
    }

    // Grass top.
    final top = Path();
    for (var i = 0; i < us.length; i++) {
      final p = iso(us[i], -sim.halfWidth(us[i]), 0);
      i == 0 ? top.moveTo(p.dx, p.dy) : top.lineTo(p.dx, p.dy);
    }
    for (var i = us.length - 1; i >= 0; i--) {
      final p = iso(us[i], sim.halfWidth(us[i]), 0);
      top.lineTo(p.dx, p.dy);
    }
    top.close();
    canvas.drawPath(top, Paint()..color = Palette.grass);
    canvas.drawPath(
      top,
      Paint()
        ..color = Palette.grassDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Dirt road down the middle.
    final road = Path();
    var started = false;
    for (final u in us) {
      if (sim.halfWidth(u) < 50) continue;
      final p = iso(u, 40 * math.sin(u / 300), 0);
      if (!started) {
        road.moveTo(p.dx, p.dy);
        started = true;
      } else {
        road.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      road,
      Paint()
        ..color = const Color(0xFFC9A877)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14 * _s
        ..strokeCap = StrokeCap.round,
    );

    final tuft = Paint()..color = Palette.grassLight;
    for (final t in _tufts) {
      if (t.dx < u0 || t.dx > u1) continue;
      final p = iso(t.dx, t.dy, 0);
      canvas.drawOval(
        Rect.fromCenter(center: p, width: 5 * _s, height: 2.5 * _s),
        tuft,
      );
    }

    // Plane's shadow on the grass.
    final pl = sim.plane;
    if (sim.halfWidth(pl.x) > pl.y.abs() && pl.z > -10) {
      _planeShape(canvas, z: 0, color: const Color(0x44000000), shadow: true);
    }
  }

  void _isoBox(
    Canvas canvas,
    double u,
    double v,
    double a,
    double b,
    double h,
    Color top,
    Color front,
    Color side,
  ) {
    Offset p(double du, double dv, double z) => iso(u + du, v + dv, z);
    // Face at +v (facing the viewer, down-right).
    canvas.drawPath(
      Path()
        ..addPolygon([p(-a, b, 0), p(a, b, 0), p(a, b, h), p(-a, b, h)], true),
      Paint()..color = front,
    );
    // Face at -u (down-left).
    canvas.drawPath(
      Path()..addPolygon([
        p(-a, -b, 0),
        p(-a, b, 0),
        p(-a, b, h),
        p(-a, -b, h),
      ], true),
      Paint()..color = side,
    );
    canvas.drawPath(
      Path()..addPolygon([
        p(-a, -b, h),
        p(a, -b, h),
        p(a, b, h),
        p(-a, b, h),
      ], true),
      Paint()..color = top,
    );
  }

  void _paintProp(Canvas canvas, double u, double v, int kind) {
    if (kind < 6) {
      // Tree: trunk and two blobs.
      final base = iso(u, v, 0);
      canvas.drawOval(
        Rect.fromCenter(center: base, width: 16 * _s, height: 7 * _s),
        Paint()..color = const Color(0x33000000),
      );
      canvas.drawLine(
        base,
        iso(u, v, 14),
        Paint()
          ..color = Palette.woodDark
          ..strokeWidth = 3 * _s,
      );
      canvas.drawCircle(
        iso(u, v, 20),
        10 * _s,
        Paint()..color = Palette.grassDark,
      );
      canvas.drawCircle(
        iso(u, v, 24) + Offset(-2 * _s, -2 * _s),
        6 * _s,
        Paint()..color = Palette.grass,
      );
    } else if (kind < 8) {
      // Hut with a red roof.
      _isoBox(
        canvas,
        u,
        v,
        12,
        10,
        14,
        const Color(0xFFB2583C),
        const Color(0xFFD8C3A0),
        const Color(0xFFB8A27F),
      );
    } else {
      // Boulder.
      final c = iso(u, v, 4);
      canvas.drawOval(
        Rect.fromCenter(center: c, width: 18 * _s, height: 11 * _s),
        Paint()..color = Palette.rockLight,
      );
    }
  }

  void _paintDock(Canvas canvas, double u, double hw, double len) {
    final planks = [
      iso(u - 8, hw - 10, 0),
      iso(u + 8, hw - 10, 0),
      iso(u + 8, hw + len, 0),
      iso(u - 8, hw + len, 0),
    ];
    canvas.drawPath(
      Path()..addPolygon(planks, true),
      Paint()..color = Palette.wood,
    );
    final edge = Paint()
      ..color = Palette.woodDark
      ..strokeWidth = 1.2;
    for (var k = 0.0; k < len; k += 9) {
      canvas.drawLine(iso(u - 8, hw + k, 0), iso(u + 8, hw + k, 0), edge);
    }
    // Support posts hanging into the void.
    for (final k in [len * 0.5, len]) {
      canvas.drawLine(
        iso(u + 8, hw + k, 0),
        iso(u + 8, hw + k, -26),
        Paint()
          ..color = Palette.woodDark
          ..strokeWidth = 2.5 * _s,
      );
    }
  }

  void _paintTarget(Canvas canvas, RaidTarget t) {
    final flash = t.hitFlash;
    Color f(Color c) =>
        flash > 0 ? Color.lerp(c, const Color(0xFFFFFFFF), flash * 0.6)! : c;
    if (!t.alive) {
      if (t.kind == RaidTargetKind.skiff) {
        _paintSkiff(canvas, t, wrecked: true);
        return;
      }
      final c = iso(t.u, t.v, 0);
      canvas.drawOval(
        Rect.fromCenter(center: c, width: 40 * _s, height: 20 * _s),
        Paint()..color = const Color(0xCC2A2522),
      );
      canvas.drawOval(
        Rect.fromCenter(center: c, width: 22 * _s, height: 11 * _s),
        Paint()..color = const Color(0xFF16120F),
      );
      return;
    }
    switch (t.kind) {
      case RaidTargetKind.crate:
        _isoBox(
          canvas,
          t.u,
          t.v,
          9,
          9,
          15,
          f(const Color(0xFFC08A52)),
          f(const Color(0xFF9A6A3A)),
          f(const Color(0xFF7C5430)),
        );
        canvas.drawLine(
          iso(t.u - 9, t.v + 9, 0),
          iso(t.u + 9, t.v + 9, 15),
          Paint()
            ..color = Palette.woodDark
            ..strokeWidth = 1.2,
        );
      case RaidTargetKind.turret:
        _isoBox(
          canvas,
          t.u,
          t.v,
          13,
          13,
          8,
          f(const Color(0xFF6B6F76)),
          f(const Color(0xFF4A4E55)),
          f(const Color(0xFF3A3D43)),
        );
        final dome = iso(t.u, t.v, 12);
        canvas.drawCircle(
          dome,
          8 * _s,
          Paint()..color = f(const Color(0xFF545961)),
        );
        final target = iso(sim.plane.x, sim.plane.y, sim.plane.z);
        final dir = target - dome;
        final d = dir.distance == 0 ? const Offset(1, 0) : dir / dir.distance;
        canvas.drawLine(
          dome,
          dome + d * 16 * _s,
          Paint()
            ..color = const Color(0xFF2B2E33)
            ..strokeWidth = 3.5 * _s
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(
          dome + Offset(0, -2 * _s),
          2.5 * _s,
          Paint()..color = Palette.pirateSail,
        );
      case RaidTargetKind.fuel:
        final bottom = iso(t.u, t.v, 0);
        final topC = iso(t.u, t.v, 22);
        final w = 26 * _s;
        canvas.drawRect(
          Rect.fromLTRB(
            bottom.dx - w / 2,
            topC.dy,
            bottom.dx + w / 2,
            bottom.dy,
          ),
          Paint()..color = f(const Color(0xFFB8402E)),
        );
        canvas.drawOval(
          Rect.fromCenter(center: bottom, width: w, height: w * 0.5),
          Paint()..color = f(const Color(0xFFB8402E)),
        );
        canvas.drawRect(
          Rect.fromLTRB(
            bottom.dx - w / 2,
            (topC.dy + bottom.dy) / 2 - 2 * _s,
            bottom.dx + w / 2,
            (topC.dy + bottom.dy) / 2 + 2 * _s,
          ),
          Paint()..color = const Color(0xFFE9D7A8),
        );
        canvas.drawOval(
          Rect.fromCenter(center: topC, width: w, height: w * 0.5),
          Paint()..color = f(const Color(0xFFD9604A)),
        );
      case RaidTargetKind.skiff:
        _paintSkiff(canvas, t, wrecked: false);
    }
    if (t.kind != RaidTargetKind.skiff) _pennant(canvas, t);
  }

  /// A small red pirate pennant marks everything worth shooting.
  void _pennant(Canvas canvas, RaidTarget t) {
    final h = switch (t.kind) {
      RaidTargetKind.crate => 15.0,
      RaidTargetKind.turret => 16.0,
      RaidTargetKind.fuel => 22.0,
      RaidTargetKind.skiff => 60.0,
    };
    final base = iso(t.u + 6, t.v - 6, h);
    final tip = base - Offset(0, 14 * _s);
    canvas.drawLine(
      base,
      tip,
      Paint()
        ..color = const Color(0xFF2B2118)
        ..strokeWidth = 1.2 * _s,
    );
    final wave = math.sin(sim.time * 6 + t.u) * 1.5 * _s;
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(tip.dx + 10 * _s, tip.dy + 3 * _s + wave)
        ..lineTo(tip.dx, tip.dy + 6 * _s)
        ..close(),
      Paint()..color = Palette.pirateSail,
    );
  }

  /// A small pirate airship moored at a dock: wooden hull under a patched
  /// gas bag.
  void _paintSkiff(Canvas canvas, RaidTarget t, {required bool wrecked}) {
    final bob = wrecked ? -30.0 : math.sin(sim.time * 1.7 + t.u) * 3;
    final hull = iso(t.u, t.v, 18 + bob);
    final bag = iso(t.u, t.v, 52 + bob);
    final flash = t.hitFlash;
    Color f(Color c) =>
        flash > 0 ? Color.lerp(c, const Color(0xFFFFFFFF), flash * 0.6)! : c;
    final rope = Paint()
      ..color = const Color(0xAA3A2A1E)
      ..strokeWidth = 1;
    canvas.drawLine(
      hull + Offset(-10 * _s, 0),
      bag + Offset(-14 * _s, 6 * _s),
      rope,
    );
    canvas.drawLine(
      hull + Offset(10 * _s, 0),
      bag + Offset(14 * _s, 6 * _s),
      rope,
    );
    final hullPath = Path()
      ..moveTo(hull.dx - 22 * _s, hull.dy - 4 * _s)
      ..lineTo(hull.dx + 24 * _s, hull.dy - 8 * _s)
      ..lineTo(hull.dx + 16 * _s, hull.dy + 6 * _s)
      ..lineTo(hull.dx - 16 * _s, hull.dy + 7 * _s)
      ..close();
    canvas.drawPath(
      hullPath,
      Paint()..color = f(wrecked ? const Color(0xFF3A2A20) : Palette.wood),
    );
    if (wrecked) {
      canvas.drawLine(bag, bag + Offset(8 * _s, 18 * _s), rope);
      return;
    }
    final bagRect = Rect.fromCenter(
      center: bag,
      width: 58 * _s,
      height: 26 * _s,
    );
    canvas.drawOval(bagRect, Paint()..color = f(const Color(0xFFD9C7A1)));
    canvas.drawOval(
      Rect.fromCenter(
        center: bag + Offset(8 * _s, -4 * _s),
        width: 14 * _s,
        height: 9 * _s,
      ),
      Paint()..color = f(const Color(0xFFB8A27F)),
    );
    canvas.drawLine(
      Offset(bagRect.left + 6 * _s, bag.dy),
      Offset(bagRect.right - 6 * _s, bag.dy),
      Paint()
        ..color = Palette.pirateSail
        ..strokeWidth = 3 * _s,
    );
  }

  void _paintReticle(Canvas canvas) {
    if (sim.planeDown) return;
    final a = sim.aimPoint;
    final c = iso(a.x, a.y, 0);
    final paint = Paint()
      ..color = Palette.hud
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawOval(
      Rect.fromCenter(center: c, width: 34 * _s, height: 17 * _s),
      paint,
    );
    canvas.drawLine(c - Offset(22 * _s, 0), c + Offset(22 * _s, 0), paint);
    canvas.drawLine(c - Offset(0, 11 * _s), c + Offset(0, 11 * _s), paint);
  }

  void _paintShots(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xFFFFF0A0)
      ..strokeWidth = 2 * _s
      ..strokeCap = StrokeCap.round;
    for (final s in sim.shots) {
      final dir = (s.target - s.start).normalized();
      final tail = s.pos - dir * 16;
      canvas.drawLine(
        iso(tail.x, tail.y, tail.z),
        iso(s.pos.x, s.pos.y, s.pos.z),
        paint,
      );
    }
  }

  /// The player's fighter drawn in the isometric frame, banked by [RaidSim.bank].
  void _planeShape(
    Canvas canvas, {
    required double z,
    required Color color,
    bool shadow = false,
  }) {
    final pl = sim.plane;
    final bank = sim.bank;
    Offset p(double fu, double fv) {
      final dz = shadow ? 0.0 : -fv * math.sin(bank);
      return iso(pl.x + fu, pl.y + fv * math.cos(bank), z + dz);
    }

    final wings = [
      p(6, -30),
      p(10, -28),
      p(10, 28),
      p(6, 30),
      p(-2, 30),
      p(-2, -30),
    ];
    final body = [
      p(22, 0),
      p(14, -5),
      p(-22, -3),
      p(-26, 0),
      p(-22, 3),
      p(14, 5),
    ];
    final tail = [p(-18, -11), p(-14, -11), p(-14, 11), p(-18, 11)];
    if (shadow) {
      final paint = Paint()..color = color;
      for (final poly in [wings, body, tail]) {
        canvas.drawPath(Path()..addPolygon(poly, true), paint);
      }
      return;
    }
    canvas.drawPath(
      Path()..addPolygon(wings, true),
      Paint()..color = Palette.playerWing,
    );
    canvas.drawPath(
      Path()..addPolygon(tail, true),
      Paint()..color = Palette.playerWing,
    );
    canvas.drawPath(
      Path()..addPolygon(body, true),
      Paint()..color = Palette.playerBody,
    );
    canvas.drawCircle(
      p(4, 0),
      3.5 * _s,
      Paint()..color = const Color(0xFF1B4B4D),
    );
    canvas.drawCircle(p(4, -29), 2.5 * _s, Paint()..color = Palette.brass);
    canvas.drawCircle(p(4, 29), 2.5 * _s, Paint()..color = Palette.brass);
    // Propeller blur.
    canvas.drawOval(
      Rect.fromCenter(center: p(23, 0), width: 8 * _s, height: 20 * _s),
      Paint()..color = const Color(0x44FFFFFF),
    );
  }

  void _paintPlane(Canvas canvas) {
    _planeShape(canvas, z: sim.plane.z, color: Palette.playerBody);
  }

  void _paintFlak(Canvas canvas) {
    final paint = Paint()..color = const Color(0xFF2B2B2B);
    for (final f in sim.flak) {
      final p = sim.flakPosition(f);
      if (p == null) continue;
      canvas.drawCircle(iso(p.x, p.y, p.z), 2.6 * _s, paint);
    }
  }

  void _paintEffects(Canvas canvas) {
    for (final fx in sim.effects.items) {
      final o = iso(fx.pos.x, fx.pos.y, fx.pos.z);
      final r = math.max(1.0, fx.size * _s);
      final fade = 1 - fx.t;
      switch (fx.kind) {
        case EffectKind.spark:
          canvas.drawCircle(
            o,
            r * 0.6,
            Paint()..color = Color.fromRGBO(255, 236, 160, fade),
          );
        case EffectKind.splash:
          canvas.drawCircle(
            o,
            r * 0.6,
            Paint()..color = Color.fromRGBO(120, 90, 60, 0.6 * fade),
          );
        case EffectKind.fire:
          paintGlow(
            canvas,
            o,
            r * 1.6,
            Color.fromRGBO(255, 160, 60, 0.85 * fade),
          );
          canvas.drawCircle(
            o,
            r * 0.6,
            Paint()..color = Color.fromRGBO(255, 225, 130, fade),
          );
        case EffectKind.smoke:
          canvas.drawCircle(
            o,
            r * 0.6,
            Paint()..color = Color.fromRGBO(50, 50, 55, 0.4 * fade),
          );
        case EffectKind.flak:
          canvas.drawCircle(
            o,
            r * 0.6,
            Paint()..color = Color.fromRGBO(40, 40, 44, 0.75 * fade),
          );
          if (fx.t < 0.3) {
            canvas.drawCircle(
              o,
              r * 0.3,
              Paint()..color = Color.fromRGBO(255, 170, 80, 1 - fx.t / 0.3),
            );
          }
        case EffectKind.debris:
          canvas.drawRect(
            Rect.fromCenter(center: o, width: r * 1.4, height: r),
            Paint()..color = Color.fromRGBO(60, 40, 28, fade),
          );
      }
    }
  }

  void _paintHud(Canvas canvas, Size size, EdgeInsetsLike safe) {
    final left = safe.left + 16;
    final top = safe.top + 14;
    paintHudPanel(
      canvas,
      Rect.fromLTRB(left - 10, top - 8, left + 230, top + 66),
    );
    paintLabel(canvas, tr('hud.hull'), Offset(left, top), size: 11);
    paintMeter(
      canvas,
      Rect.fromLTWH(left, top + 15, 150, 9),
      sim.health,
      color: sim.health > 0.35 ? Palette.ok : Palette.danger,
    );
    paintLabel(
      canvas,
      '${tr('hud.targets')}: ${sim.destroyed}/${sim.targets.length}  '
      '(${tr('hud.needed')} ${sim.required})',
      Offset(left, top + 30),
      size: 12,
      color: sim.destroyed >= sim.required ? Palette.ok : Palette.hud,
    );
    // Progress along the island.
    final barW = math.min(260.0, size.width * 0.3);
    final r = Rect.fromLTWH(
      size.width / 2 - barW / 2,
      size.height - safe.bottom - 18,
      barW,
      6,
    );
    paintMeter(canvas, r, sim.progress, color: Palette.hudDim);
    paintLabel(
      canvas,
      tr('hud.route'),
      Offset(r.left - 8, r.center.dy),
      size: 10,
      anchor: const Offset(1, 0.5),
    );
    final altFrac =
        (sim.plane.z - RaidSim.minAlt) / (RaidSim.maxAlt - RaidSim.minAlt);
    paintLabel(
      canvas,
      '${tr('hud.altitude')} ${(altFrac * 100).round()}%',
      Offset(left, top + 48),
      size: 11,
    );
  }
}
