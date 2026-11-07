import 'dart:math' as math;
import 'dart:ui';

import '../paint_kit.dart';
import 'camera3.dart';
import 'dogfight_sim.dart';

/// The view from the player's own biplane: the upper wing overhead, struts
/// and rigging wires at the sides, a leather coaming and a wooden panel of
/// brass gauges below, the nose with its twin guns and ring sight ahead.
///
/// The cockpit is fixed to the camera; the world turns around it.
class CockpitPainter {
  CockpitPainter(this.sim, this.tr);

  final DogfightSim sim;
  final Tr tr;

  /// Bullet holes the hull has collected, as fractions of the screen.
  final List<Offset> _holes = [];
  final math.Random _rng = math.Random(7);
  double _lastHealth = 1;

  static const _wood = Color(0xFF6E4527);
  static const _woodDark = Color(0xFF452814);
  static const _leather = Color(0xFF2A1A12);
  static const _stitch = Color(0x99E8C48A);
  static const _strut = Color(0xFF8A5A33);
  static const _wire = Color(0xCC1C1410);
  static const _wingUnder = Color(0xFF357F7A);
  static const _wingRib = Color(0xFF28625E);
  static const _gaugeFace = Color(0xFF17191C);

  /// Top of the dashboard at the screen's edges, as a fraction of height.
  static const double dashEdge = 0.76;

  /// Top of the dashboard in the middle (it curves up towards the nose).
  static const double dashMid = 0.66;

  /// Where the camera's centre sits, as a fraction of height.
  static const double viewCenter = 0.40;

  double wingBottom(Size s) => s.height * 0.105;

  void paint(Canvas canvas, Size size, EdgeInsetsLike safe, Camera3 cam) {
    _collectHoles();
    final w = size.width;
    final h = size.height;
    _paintPropeller(canvas, size);
    _paintStrutsAndWires(canvas, size);
    _paintUpperWing(canvas, size);
    _paintCowling(canvas, size);
    _paintRingSight(canvas, cam);
    _paintDashboard(canvas, size);
    _paintGauges(canvas, size);
    _paintHoles(canvas, size);
    _paintEngineSmoke(canvas, size);
    _paintRadar(canvas, size, safe);
    _paintEnemyPlate(canvas, size, safe);
    if (sim.lowWarning && !sim.playerDown && (sim.time * 3).floor().isEven) {
      paintLabel(
        canvas,
        tr('hud.lowAltitude'),
        Offset(w / 2, h * 0.2),
        size: 18,
        color: Palette.danger,
        anchor: const Offset(0.5, 0.5),
      );
    }
  }

  void _collectHoles() {
    // One hole for roughly every hit taken.
    while (_lastHealth - sim.health > 0.04 && _holes.length < 40) {
      _lastHealth -= 0.05;
      final onWing = _rng.nextBool();
      _holes.add(
        onWing
            ? Offset(
                0.08 + _rng.nextDouble() * 0.84,
                0.02 + _rng.nextDouble() * 0.06,
              )
            : Offset(
                _rng.nextBool()
                    ? 0.05 + _rng.nextDouble() * 0.2
                    : 0.75 + _rng.nextDouble() * 0.2,
                0.8 + _rng.nextDouble() * 0.15,
              ),
      );
    }
  }

  Path _dashPath(Size s) => Path()
    ..moveTo(0, s.height)
    ..lineTo(0, s.height * dashEdge)
    ..quadraticBezierTo(
      s.width / 2,
      s.height * (2 * dashMid - dashEdge),
      s.width,
      s.height * dashEdge,
    )
    ..lineTo(s.width, s.height)
    ..close();

  void _paintPropeller(Canvas canvas, Size size) {
    if (sim.playerDown) return;
    final c = Offset(size.width / 2, size.height * 0.62);
    final r = size.height * 0.5;
    // Two faint blades sweeping round: just enough to feel the engine.
    final a = sim.time * 31;
    final blade = Paint()
      ..color = const Color(0x14FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.16;
    for (var k = 0; k < 2; k++) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r * 0.7),
        a + k * math.pi,
        0.5,
        false,
        blade,
      );
    }
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = const Color(0x0DFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _paintUpperWing(Canvas canvas, Size size) {
    final w = size.width;
    final edge = wingBottom(size);
    final mid = size.height * 0.085;
    final band = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, edge)
      ..quadraticBezierTo(w / 2, mid * 2 - edge, 0, edge)
      ..close();
    // The cut-out over the pilot's head.
    final cut = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(w / 2, 0),
          width: w * 0.16,
          height: mid * 1.5,
        ),
      );
    final wing = Path.combine(PathOperation.difference, band, cut);
    canvas.drawPath(
      wing,
      Paint()
        ..shader = Gradient.linear(Offset.zero, Offset(0, edge), const [
          Color(0xFF1F5552),
          _wingUnder,
        ]),
    );
    canvas.save();
    canvas.clipPath(wing);
    final rib = Paint()
      ..color = _wingRib
      ..strokeWidth = 2;
    for (var k = 1; k < 16; k++) {
      final x = w * k / 16;
      // Ribs fan out slightly away from the middle.
      final lean = (x - w / 2) * 0.05;
      canvas.drawLine(Offset(x, edge + 2), Offset(x + lean, -2), rib);
    }
    canvas.restore();
    // Brass-capped leading edge.
    final lead = Path()
      ..moveTo(0, edge)
      ..quadraticBezierTo(w / 2, mid * 2 - edge, w, edge);
    canvas.drawPath(
      lead,
      Paint()
        ..color = Palette.brass
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    // Roundel of the Compass Squadron on each side.
    for (final x in [w * 0.22, w * 0.78]) {
      final c = Offset(x, edge * 0.5);
      final r = edge * 0.34;
      canvas.drawCircle(c, r, Paint()..color = const Color(0xFFEDE3C8));
      canvas.drawCircle(c, r * 0.68, Paint()..color = const Color(0xFF1E4D6B));
      _compassStar(canvas, c, r * 0.6, Palette.brass);
    }
  }

  void _compassStar(Canvas canvas, Offset c, double r, Color color) {
    final p = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 - math.pi / 2;
      final rr = i.isEven ? r : r * 0.35;
      final pt = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    p.close();
    canvas.drawPath(p, Paint()..color = color);
  }

  void _paintStrutsAndWires(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final top = wingBottom(size) - 2;
    final bottom = h * dashEdge + 4;
    final wire = Paint()
      ..color = _wire
      ..strokeWidth = 1.3;
    final strutW = w * 0.022;
    for (final side in [-1.0, 1.0]) {
      final x = w / 2 + side * w * 0.455;
      final cabaneTop = Offset(w / 2 + side * w * 0.075, top - 4);
      final cabaneBottom = Offset(w / 2 + side * w * 0.1, h * 0.69);
      // Rigging wires crossing between the outer strut and the cabane.
      canvas.drawLine(Offset(x, top + 6), cabaneBottom, wire);
      canvas.drawLine(
        Offset(x, bottom - 10),
        cabaneTop + const Offset(0, 6),
        wire,
      );
      canvas.drawLine(
        Offset(x - side * strutW, top + 6),
        Offset(x - side * strutW, bottom),
        wire,
      );
      // Outer interplane strut (streamlined wood).
      final strut = Rect.fromLTRB(x - strutW / 2, top, x + strutW / 2, bottom);
      canvas.drawRRect(
        RRect.fromRectAndRadius(strut, Radius.circular(strutW / 2)),
        Paint()
          ..shader = Gradient.linear(
            strut.centerLeft,
            strut.centerRight,
            const [_woodDark, _strut, _woodDark],
            const [0, 0.5, 1],
          ),
      );
      // Cabane strut down to the fuselage.
      canvas.drawLine(
        cabaneTop,
        cabaneBottom,
        Paint()
          ..color = _woodDark
          ..strokeWidth = w * 0.011
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _paintCowling(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final c = Offset(w / 2, h * 0.715);
    final cowl = Rect.fromCenter(center: c, width: w * 0.28, height: h * 0.14);
    canvas.drawOval(
      cowl,
      Paint()
        ..shader = Gradient.linear(cowl.topCenter, cowl.center, const [
          Color(0xFF4FA7A0),
          Palette.playerBody,
        ]),
    );
    // Louvres.
    final louvre = Paint()
      ..color = const Color(0x661B4B4D)
      ..strokeWidth = 2;
    for (var k = -3; k <= 3; k++) {
      final x = c.dx + k * w * 0.028;
      canvas.drawLine(
        Offset(x, cowl.top + h * 0.02),
        Offset(x * 0.98 + c.dx * 0.02, c.dy),
        louvre,
      );
    }
    // Twin guns along the top, converging towards the sight.
    for (final side in [-1.0, 1.0]) {
      final base = Offset(c.dx + side * w * 0.05, h * 0.705);
      final tip = Offset(c.dx + side * w * 0.017, h * 0.585);
      canvas.drawLine(
        base,
        tip,
        Paint()
          ..color = const Color(0xFF26292E)
          ..strokeWidth = w * 0.016
          ..strokeCap = StrokeCap.round,
      );
      // Cooling jacket holes.
      for (var k = 1; k < 5; k++) {
        final p = Offset.lerp(base, tip, k / 5.5)!;
        canvas.drawCircle(
          p,
          w * 0.0035,
          Paint()..color = const Color(0xFF0E0F11),
        );
      }
      if (sim.muzzleFlash > 0) {
        paintGlow(
          canvas,
          tip,
          w * 0.04,
          Color.fromRGBO(255, 225, 140, sim.muzzleFlash),
        );
      }
    }
  }

  void _paintRingSight(Canvas canvas, Camera3 cam) {
    final c = Offset(cam.cx, cam.cy);
    final r = cam.focal * 0.045;
    final color = sim.jammed ? Palette.danger : const Color(0xFFE2B85C);
    final post = Paint()
      ..color = const Color(0xFF3B2B1C)
      ..strokeWidth = 2.5;
    // Mounting post from the cowling.
    canvas.drawLine(Offset(c.dx, c.dy + r), Offset(c.dx, c.dy + r * 3.4), post);
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(c, r, ring);
    canvas.drawCircle(c, r * 0.45, ring..strokeWidth = 1.4);
    final thin = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 1;
    canvas.drawLine(c - Offset(r, 0), c + Offset(r, 0), thin);
    canvas.drawLine(c - Offset(0, r), c + Offset(0, r), thin);
    canvas.drawCircle(c, 2, Paint()..color = color);
  }

  void _paintDashboard(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final dash = _dashPath(size);
    canvas.drawPath(
      dash,
      Paint()
        ..shader = Gradient.linear(Offset(0, h * dashMid), Offset(0, h), const [
          _wood,
          _woodDark,
        ]),
    );
    // Wood grain.
    canvas.save();
    canvas.clipPath(dash);
    final grain = Paint()
      ..color = const Color(0x22000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var k = 0; k < 9; k++) {
      final y = h * (0.74 + k * 0.03);
      final g = Path()..moveTo(0, y);
      for (var x = 0.0; x <= w; x += w / 12) {
        g.lineTo(x, y + math.sin(x / w * 9 + k * 1.7) * h * 0.008);
      }
      canvas.drawPath(g, grain);
    }
    canvas.restore();
    // Leather coaming with stitching.
    final rim = Path()
      ..moveTo(0, h * dashEdge)
      ..quadraticBezierTo(w / 2, h * (2 * dashMid - dashEdge), w, h * dashEdge);
    canvas.drawPath(
      rim,
      Paint()
        ..color = _leather
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.035,
    );
    final stitchPath = Path()
      ..moveTo(0, h * dashEdge + h * 0.022)
      ..quadraticBezierTo(
        w / 2,
        h * (2 * dashMid - dashEdge) + h * 0.022,
        w,
        h * dashEdge + h * 0.022,
      );
    final stitch = Paint()
      ..color = _stitch
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final metric in stitchPath.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, d + 4.5), stitch);
      }
    }
    // Brass screws in the corners of the panel.
    for (final p in [Offset(w * 0.2, h * 0.79), Offset(w * 0.8, h * 0.79)]) {
      canvas.drawCircle(p, 3, Paint()..color = Palette.brass);
      canvas.drawLine(
        p - const Offset(2, 2),
        p + const Offset(2, 2),
        Paint()..color = _woodDark,
      );
    }
  }

  void _paintGauges(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = h * 0.085;
    final gap = r * 2.75;
    final y = h * 0.875;
    final p = sim.player;
    final alt =
        ((p.pos.y - DogfightSim.floorY) /
                (DogfightSim.ceilY - DogfightSim.floorY))
            .clamp(0.0, 1.0);
    final speed = ((p.speed - 120) / 260).clamp(0.0, 1.0);
    _gauge(
      canvas,
      Offset(w / 2 - gap * 2, y),
      r,
      alt,
      tr('hud.altitude'),
      zones: const [],
    );
    _gauge(
      canvas,
      Offset(w / 2 - gap, y),
      r,
      speed,
      tr('hud.speed'),
      zones: const [],
    );
    _compass(canvas, Offset(w / 2, y), r);
    _gauge(
      canvas,
      Offset(w / 2 + gap, y),
      r,
      sim.health,
      tr('hud.hull'),
      zones: const [
        (0, 0.3, Palette.danger),
        (0.3, 0.6, Color(0xFFE0A030)),
        (0.6, 1, Palette.ok),
      ],
    );
    _gauge(
      canvas,
      Offset(w / 2 + gap * 2, y),
      r,
      sim.heat,
      tr('hud.heat'),
      zones: const [(0, 0.7, Palette.ok), (0.7, 1, Palette.danger)],
    );
    // Warning lamps beside the outer gauges.
    _lamp(
      canvas,
      Offset(w / 2 - gap * 2.75, y - r * 0.5),
      r * 0.22,
      const Color(0xFFFFB020),
      on: sim.lowWarning && !sim.playerDown,
    );
    _lamp(
      canvas,
      Offset(w / 2 + gap * 2.75, y - r * 0.5),
      r * 0.22,
      Palette.danger,
      on: sim.jammed,
    );
  }

  void _bezel(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(
      c + const Offset(1.5, 2.5),
      r * 1.12,
      Paint()..color = const Color(0x66000000),
    );
    canvas.drawCircle(
      c,
      r * 1.12,
      Paint()
        ..shader = Gradient.linear(
          c - Offset(r, r),
          c + Offset(r, r),
          const [Color(0xFFF2D38A), Color(0xFF9C7228), Color(0xFFE2B85C)],
          const [0, 0.55, 1],
        ),
    );
    canvas.drawCircle(c, r, Paint()..color = _gaugeFace);
  }

  void _glass(Canvas canvas, Offset c, double r) {
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.82),
      math.pi * 1.1,
      math.pi * 0.55,
      false,
      Paint()
        ..color = const Color(0x33FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12
        ..strokeCap = StrokeCap.round,
    );
  }

  /// A needle gauge sweeping 270° from bottom-left to bottom-right.
  void _gauge(
    Canvas canvas,
    Offset c,
    double r,
    double value,
    String label, {
    required List<(double, double, Color)> zones,
  }) {
    _bezel(canvas, c, r);
    const start = math.pi * 0.75;
    const sweep = math.pi * 1.5;
    for (final (a, b, color) in zones) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r * 0.8),
        start + sweep * a,
        sweep * (b - a),
        false,
        Paint()
          ..color = color.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.12,
      );
    }
    final tick = Paint()
      ..color = const Color(0xFFE8E2D0)
      ..strokeWidth = 1.2;
    for (var k = 0; k <= 10; k++) {
      final a = start + sweep * k / 10;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        c + d * r * (k.isEven ? 0.6 : 0.68),
        c + d * r * 0.78,
        tick,
      );
    }
    paintLabel(
      canvas,
      label.toUpperCase(),
      c + Offset(0, r * 0.45),
      size: 7.5,
      color: const Color(0xFFE8E2D0),
      anchor: const Offset(0.5, 0.5),
      shadow: false,
    );
    final a = start + sweep * value.clamp(0.0, 1.0);
    final d = Offset(math.cos(a), math.sin(a));
    canvas.drawLine(
      c - d * r * 0.15,
      c + d * r * 0.72,
      Paint()
        ..color = const Color(0xFFF4E9CF)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      c + d * r * 0.5,
      c + d * r * 0.72,
      Paint()
        ..color = Palette.danger
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(c, r * 0.1, Paint()..color = Palette.brass);
    _glass(canvas, c, r);
  }

  /// A compass card that turns with the heading under a fixed lubber line.
  void _compass(Canvas canvas, Offset c, double r) {
    _bezel(canvas, c, r);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-sim.player.yaw);
    final tick = Paint()
      ..color = const Color(0xFFE8E2D0)
      ..strokeWidth = 1;
    for (var k = 0; k < 24; k++) {
      final a = k * math.pi / 12 - math.pi / 2;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(d * r * (k % 6 == 0 ? 0.6 : 0.7), d * r * 0.8, tick);
    }
    const letters = ['N', 'E', 'S', 'W'];
    for (var k = 0; k < 4; k++) {
      final a = k * math.pi / 2 - math.pi / 2;
      final d = Offset(math.cos(a), math.sin(a));
      paintLabel(
        canvas,
        letters[k],
        d * r * 0.42,
        size: 9,
        color: k == 0 ? Palette.danger : const Color(0xFFE8E2D0),
        anchor: const Offset(0.5, 0.5),
        shadow: false,
      );
    }
    canvas.restore();
    // Lubber line.
    canvas.drawLine(
      c - Offset(0, r * 0.95),
      c - Offset(0, r * 0.62),
      Paint()
        ..color = Palette.brass
        ..strokeWidth = 2.5,
    );
    _compassStar(canvas, c, r * 0.18, Palette.brass);
    _glass(canvas, c, r);
  }

  void _lamp(
    Canvas canvas,
    Offset c,
    double r,
    Color color, {
    required bool on,
  }) {
    canvas.drawCircle(c, r * 1.35, Paint()..color = const Color(0xFF8C6A2E));
    final blink = on && (sim.time * 4).floor().isEven;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = blink
            ? color
            : Color.lerp(color, const Color(0xFF000000), 0.7)!,
    );
    if (blink) paintGlow(canvas, c, r * 3.5, color.withValues(alpha: 0.5));
  }

  void _paintHoles(Canvas canvas, Size size) {
    for (final f in _holes) {
      final p = Offset(f.dx * size.width, f.dy * size.height);
      canvas.drawCircle(p, 4.5, Paint()..color = const Color(0x55E8DCC0));
      canvas.drawCircle(p, 3, Paint()..color = const Color(0xFF0B0B0B));
    }
  }

  void _paintEngineSmoke(Canvas canvas, Size size) {
    if (sim.health > 0.35 && !sim.playerDown) return;
    final k = sim.playerDown ? 1.0 : (0.35 - sim.health) / 0.35;
    for (var i = 0; i < 6; i++) {
      final t = (sim.time * 0.8 + i / 6) % 1;
      final x =
          size.width / 2 + math.sin(i * 2.3 + sim.time) * size.width * 0.06;
      final y = size.height * (0.66 - t * 0.55);
      canvas.drawCircle(
        Offset(x, y),
        size.height * (0.05 + t * 0.12),
        Paint()..color = Color.fromRGBO(35, 35, 38, 0.35 * k * (1 - t)),
      );
    }
  }

  void _paintRadar(Canvas canvas, Size size, EdgeInsetsLike safe) {
    final r = size.height * 0.1;
    final c = Offset(safe.left + 16 + r, wingBottom(size) + 12 + r);
    _bezel(canvas, c, r);
    canvas.drawCircle(
      c,
      r * 0.5,
      Paint()
        ..color = const Color(0x5532D27A)
        ..style = PaintingStyle.stroke,
    );
    // Sweep.
    final sweepA = sim.time * 2.5;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.95),
      sweepA - 0.6,
      0.6,
      true,
      Paint()..color = const Color(0x2232D27A),
    );
    final p = sim.player;
    final cy = math.cos(p.yaw);
    final sy = math.sin(p.yaw);
    for (final e in sim.pirates) {
      if (!e.alive) continue;
      final rel = e.pos - p.pos;
      final rx = rel.x * cy - rel.z * sy;
      final rz = rel.x * sy + rel.z * cy;
      var v = Offset(rx, -rz) / 3200 * r;
      if (v.distance > r - 4) v = v / v.distance * (r - 4);
      final color = e.cls == PirateClass.ace ? Palette.aceTrim : Palette.danger;
      canvas.drawCircle(c + v, 3, Paint()..color = color);
      if (rel.y.abs() > 150) {
        canvas.drawLine(
          c + v,
          c + v + Offset(0, rel.y > 0 ? -6 : 6),
          Paint()
            ..color = color
            ..strokeWidth = 1.4,
        );
      }
    }
    final me = Path()
      ..moveTo(c.dx, c.dy - 5)
      ..lineTo(c.dx - 4, c.dy + 4)
      ..lineTo(c.dx + 4, c.dy + 4)
      ..close();
    canvas.drawPath(me, Paint()..color = Palette.ok);
    _glass(canvas, c, r);
  }

  void _paintEnemyPlate(Canvas canvas, Size size, EdgeInsetsLike safe) {
    final text = '${tr('hud.enemies')}: ${sim.remaining}';
    const pw = 118.0;
    const ph = 26.0;
    final rect = Rect.fromLTWH(
      size.width - safe.right - 16 - pw,
      wingBottom(size) + 14,
      pw,
      ph,
    );
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(5));
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = Gradient.linear(rect.topLeft, rect.bottomRight, const [
          Color(0xFFE9C978),
          Color(0xFFA77A2C),
        ]),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..color = const Color(0xFF5A3E14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    for (final x in [rect.left + 6, rect.right - 6]) {
      canvas.drawCircle(
        Offset(x, rect.center.dy),
        2,
        Paint()..color = const Color(0xFF5A3E14),
      );
    }
    paintLabel(
      canvas,
      text,
      rect.center,
      size: 13,
      color: const Color(0xFF2B1A0A),
      anchor: const Offset(0.5, 0.5),
      shadow: false,
    );
  }
}
