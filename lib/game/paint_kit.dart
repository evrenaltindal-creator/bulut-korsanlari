import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Colours shared by the three mission views.
abstract final class Palette {
  static const skyTop = Color(0xFF14304F);
  static const skyMid = Color(0xFF3D6F92);
  static const skyHorizon = Color(0xFFF3C89B);
  static const cloudSeaNear = Color(0xFFEDE6F2);
  static const cloudSeaFar = Color(0xFF8FA6C4);
  static const cloud = Color(0xFFFFFFFF);
  static const cloudShade = Color(0xFFCFD8E8);

  static const grass = Color(0xFF6E9F55);
  static const grassLight = Color(0xFF9CC96D);
  static const grassDark = Color(0xFF4F7A3E);
  static const rock = Color(0xFF80604E);
  static const rockDark = Color(0xFF4D3832);
  static const rockLight = Color(0xFFA9826A);
  static const wood = Color(0xFF8A5A36);
  static const woodDark = Color(0xFF5C3A22);

  static const pirateHull = Color(0xFF4F3326);
  static const pirateWing = Color(0xFFC7B088);
  static const pirateSail = Color(0xFFB3302B);
  static const aceSail = Color(0xFF1E1E24);
  static const aceTrim = Color(0xFFE2B33E);

  static const playerBody = Color(0xFF2A7C7E);
  static const playerWing = Color(0xFF3E9C94);
  static const brass = Color(0xFFD9A441);

  static const hud = Color(0xFFFFD27A);
  static const hudDim = Color(0x99FFD27A);
  static const danger = Color(0xFFE5484D);
  static const ok = Color(0xFF7DD87D);
  static const ink = Color(0xFF10202F);
}

/// Looks up a translated string by key.
typedef Tr = String Function(String key);

final Map<String, TextPainter> _labelCache = {};

/// Paints a short label. [anchor] is (0,0) for top-left, (0.5,0.5) for
/// centred, (1,0) for top-right and so on.
void paintLabel(
  Canvas canvas,
  String text,
  Offset at, {
  double size = 14,
  Color color = Palette.hud,
  FontWeight weight = FontWeight.w700,
  Offset anchor = Offset.zero,
  bool shadow = true,
}) {
  final key = '$text|$size|${color.toARGB32()}|${weight.value}|$shadow';
  final tp = _labelCache.putIfAbsent(key, () {
    if (_labelCache.length > 300) _labelCache.clear();
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: weight,
          letterSpacing: 0.4,
          shadows: shadow
              ? const [Shadow(color: Color(0xCC000000), blurRadius: 3)]
              : null,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  });
  tp.paint(canvas, at - Offset(tp.width * anchor.dx, tp.height * anchor.dy));
}

/// A dark translucent backing so HUD text stays readable over white
/// clouds.
void paintHudPanel(Canvas canvas, Rect rect) {
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, const Radius.circular(10)),
    Paint()..color = const Color(0x6610202F),
  );
}

/// A horizontal meter with a label.
void paintMeter(
  Canvas canvas,
  Rect rect,
  double value, {
  required Color color,
  Color back = const Color(0x66000000),
}) {
  final r = RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2));
  canvas.drawRRect(r, Paint()..color = back);
  final w = rect.width * value.clamp(0.0, 1.0);
  if (w > 0) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left, rect.top, w, rect.height),
        Radius.circular(rect.height / 2),
      ),
      Paint()..color = color,
    );
  }
  canvas.drawRRect(
    r,
    Paint()
      ..color = const Color(0x88FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );
}

/// One fluffy cloud built from overlapping circles.
class CloudShape {
  CloudShape(math.Random rng, {int puffs = 5}) {
    for (var i = 0; i < puffs; i++) {
      final t = puffs == 1 ? 0.5 : i / (puffs - 1);
      offsets.add(
        Offset(
          (t - 0.5) * 2.2 + (rng.nextDouble() - 0.5) * 0.3,
          (rng.nextDouble() - 0.5) * 0.35 - math.sin(t * math.pi) * 0.35,
        ),
      );
      radii.add(0.45 + math.sin(t * math.pi) * 0.45 + rng.nextDouble() * 0.2);
    }
  }

  final List<Offset> offsets = [];
  final List<double> radii = [];

  void paint(Canvas canvas, Offset center, double unit, double opacity) {
    if (opacity <= 0.01 || unit < 0.3) return;
    final shade = Paint()
      ..color = Palette.cloudShade.withValues(alpha: opacity * 0.9);
    final body = Paint()..color = Palette.cloud.withValues(alpha: opacity);
    for (var i = 0; i < offsets.length; i++) {
      canvas.drawCircle(
        center + offsets[i] * unit + Offset(0, unit * 0.12),
        radii[i] * unit,
        shade,
      );
    }
    for (var i = 0; i < offsets.length; i++) {
      canvas.drawCircle(
        center + offsets[i] * unit - Offset(0, unit * 0.05),
        radii[i] * unit * 0.92,
        body,
      );
    }
  }
}

/// A floating island seen from the side: grassy top, rocky underside
/// tapering to a point. [unit] is the island's half width in pixels.
void paintFloatingIsland(
  Canvas canvas,
  Offset center,
  double unit,
  int seed, {
  double opacity = 1,
}) {
  if (unit < 1 || opacity <= 0.01) return;
  final rng = math.Random(seed);
  final a = opacity;
  final detailed = unit > 14;
  Color c(Color col, [double k = 1]) => col.withValues(alpha: a * k);

  // Jagged rocky underside hanging to a point, with a lower ledge.
  final points = <Offset>[Offset(center.dx - unit, center.dy)];
  const steps = 11;
  for (var i = 1; i < steps; i++) {
    final t = i / steps;
    final x = center.dx - unit + t * unit * 2;
    final base = math.pow(math.sin(t * math.pi), 1.4) * unit * 1.25;
    final jag = (rng.nextDouble() - 0.4) * unit * 0.22;
    points.add(Offset(x, center.dy + base + jag));
  }
  points.add(Offset(center.dx + unit, center.dy));
  final under = Path()..addPolygon(points, true);
  canvas.drawPath(
    under,
    Paint()
      ..shader = ui.Gradient.linear(
        center,
        center + Offset(0, unit * 1.3),
        [c(Palette.rockLight), c(Palette.rock), c(Palette.rockDark)],
        const [0, 0.35, 1],
      ),
  );
  if (detailed) {
    // Strata following the underside.
    final strata = Paint()
      ..color = c(Palette.rockDark, 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, unit * 0.025);
    for (final f in [0.3, 0.55, 0.78]) {
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final p = Offset.lerp(Offset(points[i].dx, center.dy), points[i], f)!;
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, strata);
    }
    // Shadowed side.
    final shade = Path()
      ..moveTo(center.dx + unit * 0.1, center.dy + unit * 0.12)
      ..lineTo(points[steps ~/ 2 + 1].dx, points[steps ~/ 2 + 1].dy)
      ..lineTo(center.dx + unit, center.dy)
      ..close();
    canvas.drawPath(shade, Paint()..color = c(Palette.rockDark, 0.35));
    // Hanging roots.
    final root = Paint()
      ..color = c(const Color(0xFF5B4632), 0.8)
      ..strokeWidth = math.max(1, unit * 0.02)
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 5; i++) {
      final x = center.dx + (rng.nextDouble() - 0.5) * unit * 1.5;
      final len = unit * (0.15 + rng.nextDouble() * 0.3);
      final y0 = center.dy + unit * 0.08;
      canvas.drawPath(
        Path()
          ..moveTo(x, y0)
          ..quadraticBezierTo(
            x + len * 0.2,
            y0 + len * 0.5,
            x - len * 0.1,
            y0 + len,
          ),
        root,
      );
    }
  }

  // Grass top with an earthen lip.
  final top = Rect.fromCenter(
    center: center,
    width: unit * 2.1,
    height: unit * 0.42,
  );
  canvas.drawOval(
    top.translate(0, unit * 0.05),
    Paint()..color = c(const Color(0xFF6B5136)),
  );
  canvas.drawOval(top, Paint()..color = c(Palette.grass));
  canvas.drawOval(
    top.deflate(unit * 0.08).translate(0, -unit * 0.04),
    Paint()..color = c(Palette.grassLight),
  );

  // A waterfall spilling off one edge, misting as it falls.
  if (detailed && rng.nextDouble() < 0.7) {
    final side = rng.nextBool() ? 1.0 : -1.0;
    final x = center.dx + side * unit * (0.55 + rng.nextDouble() * 0.3);
    final y0 = center.dy + unit * 0.12;
    final len = unit * (1.3 + rng.nextDouble() * 0.6);
    canvas.drawRect(
      Rect.fromLTWH(x - unit * 0.035, y0, unit * 0.07, len),
      Paint()
        ..shader = ui.Gradient.linear(Offset(x, y0), Offset(x, y0 + len), [
          c(const Color(0xFFE6F3FF), 0.9),
          c(const Color(0xFFE6F3FF), 0),
        ]),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, y0),
        width: unit * 0.16,
        height: unit * 0.05,
      ),
      Paint()..color = c(const Color(0xFF8FC6E8)),
    );
  }

  // Trees and the odd cottage.
  final trees = 3 + rng.nextInt(5);
  for (var i = 0; i < trees; i++) {
    final x = center.dx + (rng.nextDouble() - 0.5) * unit * 1.6;
    final y = center.dy + (rng.nextDouble() - 0.5) * unit * 0.18;
    final h = unit * (0.13 + rng.nextDouble() * 0.12);
    if (detailed) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, y - h * 0.8),
        Paint()
          ..color = c(Palette.woodDark)
          ..strokeWidth = math.max(1, h * 0.15),
      );
    }
    canvas.drawCircle(
      Offset(x, y - h),
      h * 0.62,
      Paint()..color = c(Palette.grassDark),
    );
    if (detailed) {
      canvas.drawCircle(
        Offset(x - h * 0.18, y - h * 1.15),
        h * 0.35,
        Paint()..color = c(Palette.grass),
      );
    }
  }
  if (detailed && rng.nextDouble() < 0.6) {
    final x = center.dx + (rng.nextDouble() - 0.5) * unit;
    final y = center.dy - unit * 0.02;
    final s = unit * 0.11;
    canvas.drawRect(
      Rect.fromLTWH(x - s, y - s, s * 2, s),
      Paint()..color = c(const Color(0xFFE2D2B0)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(x - s * 1.25, y - s)
        ..lineTo(x, y - s * 2)
        ..lineTo(x + s * 1.25, y - s)
        ..close(),
      Paint()..color = c(const Color(0xFFB2583C)),
    );
  }
}

/// Soft radial glow, used for the sun and explosions.
void paintGlow(Canvas canvas, Offset c, double r, Color color) {
  if (r <= 0) return;
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
          .createShader(Rect.fromCircle(center: c, radius: r)),
  );
}

/// Just the four insets; avoids pulling widgets into the painters.
class EdgeInsetsLike {
  const EdgeInsetsLike({
    this.left = 0,
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;
}
