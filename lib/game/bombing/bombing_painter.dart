import 'dart:math' as math;
import 'dart:ui';

import '../../core/effects.dart';
import '../paint_kit.dart';
import 'bombing_sim.dart';

/// Looking straight down through the clouds at a pirate base.
class BombingPainter {
  BombingPainter(this.sim, this.tr) {
    final rng = math.Random(sim.config.seed * 17 + 3);
    for (var i = 0; i < 18; i++) {
      _lowClouds.add((
        Offset(rng.nextDouble(), rng.nextDouble()),
        CloudShape(rng, puffs: 5),
        50 + rng.nextDouble() * 50,
      ));
    }
    for (var i = 0; i < 10; i++) {
      _highClouds.add((
        Offset(rng.nextDouble(), rng.nextDouble()),
        CloudShape(rng, puffs: 6),
        70 + rng.nextDouble() * 70,
      ));
    }
    for (var i = 0; i < 140; i++) {
      final y = -100 + rng.nextDouble() * (sim.config.length + 200);
      final hw = sim.halfWidthAt(y);
      if (hw < 30) continue;
      _patches.add((
        Offset((rng.nextDouble() * 2 - 1) * (hw - 20), y),
        6 + rng.nextDouble() * 16,
        rng.nextInt(3),
      ));
    }
  }

  final BombingSim sim;
  final Tr tr;
  final List<(Offset, CloudShape, double)> _lowClouds = [];
  final List<(Offset, CloudShape, double)> _highClouds = [];
  final List<(Offset, double, int)> _patches = [];

  late double _s;
  late Offset _anchor;
  late double _camX;
  late Size _size;

  Offset g(double x, double y) => Offset(
    _anchor.dx + (x - _camX) * _s,
    _anchor.dy - (y - sim.plane.y) * _s,
  );

  void paint(Canvas canvas, Size size, EdgeInsetsLike safe) {
    _size = size;
    _s = size.height / 520;
    _anchor = Offset(size.width / 2, size.height * 0.72);
    _camX = sim.plane.x * 0.55;

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = Gradient.linear(Offset.zero, Offset(0, size.height), const [
          Color(0xFF8EA4C8),
          Color(0xFFB9C3DD),
        ]),
    );
    _cloudLayer(canvas, _lowClouds, parallax: 0.55, opacity: 0.6, scale: 0.8);
    _paintRock(canvas);
    _paintTargets(canvas);
    _paintBombs(canvas);
    _paintGroundEffects(canvas);
    _paintSight(canvas);
    _cloudLayer(canvas, _highClouds, parallax: 1.6, opacity: 0.38, scale: 1.4);
    _paintAirEffects(canvas);
    _paintPlane(canvas);
    _paintHud(canvas, size, safe);

    if (sim.hitFlash > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Palette.danger.withValues(alpha: 0.22 * sim.hitFlash),
      );
    }
  }

  void _cloudLayer(
    Canvas canvas,
    List<(Offset, CloudShape, double)> clouds, {
    required double parallax,
    required double opacity,
    required double scale,
  }) {
    final w = _size.width + 400;
    final h = _size.height + 400;
    for (final (o, shape, r) in clouds) {
      final x = ((o.dx * w - sim.plane.x * parallax * _s * 0.4) % w) - 200;
      final y = ((o.dy * h + sim.plane.y * parallax * _s) % h) - 200;
      shape.paint(canvas, Offset(x, y), r * _s * scale, opacity);
    }
  }

  void _paintRock(Canvas canvas) {
    final visibleMin = sim.plane.y - _size.height * 0.4 / _s - 200;
    final visibleMax = sim.plane.y + _size.height / _s + 200;
    final pts = sim.outline
        .where((p) => p.$1 > visibleMin - 60 && p.$1 < visibleMax + 60)
        .toList();
    if (pts.length < 2) return;
    Path outlinePath(double grow, Offset shift) {
      final path = Path();
      for (var i = 0; i < pts.length; i++) {
        final (y, hw) = pts[i];
        final p = g(-hw - grow, y) + shift;
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      for (var i = pts.length - 1; i >= 0; i--) {
        final (y, hw) = pts[i];
        final p = g(hw + grow, y) + shift;
        path.lineTo(p.dx, p.dy);
      }
      return path..close();
    }

    // The rock's shadow on the clouds far below.
    canvas.drawPath(
      outlinePath(0, Offset(30 * _s, 26 * _s)),
      Paint()..color = const Color(0x33203048),
    );
    // Cliff edge, then the plateau.
    canvas.drawPath(
      outlinePath(10, Offset(4 * _s, 8 * _s)),
      Paint()..color = Palette.rockDark,
    );
    canvas.drawPath(
      outlinePath(0, Offset.zero),
      Paint()..color = const Color(0xFFB59772),
    );
    canvas.drawPath(
      outlinePath(-14, Offset.zero),
      Paint()
        ..color = const Color(0x22000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    const colors = [Color(0xFF9E8260), Color(0xFF7FA05A), Color(0xFFC7AE88)];
    for (final (o, r, k) in _patches) {
      if (o.dy < visibleMin || o.dy > visibleMax) continue;
      canvas.drawCircle(g(o.dx, o.dy), r * _s, Paint()..color = colors[k]);
    }
    // A runway stripe for the pirates' own planes.
    final a = g(-18, 80);
    final b = g(18, math.min(sim.config.length - 80, 900));
    canvas.drawRect(
      Rect.fromPoints(a, b),
      Paint()..color = const Color(0xFF8C7A64),
    );
    final dash = Paint()
      ..color = const Color(0xCCEFE6D2)
      ..strokeWidth = 2;
    for (var y = 100.0; y < math.min(sim.config.length - 100, 880); y += 40) {
      canvas.drawLine(g(0, y), g(0, y + 18), dash);
    }
  }

  void _paintTargets(Canvas canvas) {
    final shadow = Paint()..color = const Color(0x44000000);
    for (final t in sim.targets) {
      final c = g(t.x, t.y);
      if (c.dy < -150 || c.dy > _size.height + 150) continue;
      final (ex, ey) = BombTarget.extent(t.kind);
      final flash = t.hitFlash;
      Color f(Color col) => flash > 0
          ? Color.lerp(col, const Color(0xFFFFFFFF), flash * 0.6)!
          : col;
      if (!t.alive) {
        if (t.kind == BombTargetKind.airship) {
          // The wreck sinks into the cloud sea.
          continue;
        }
        canvas.drawOval(
          Rect.fromCenter(
            center: c,
            width: ex * 2.4 * _s,
            height: ey * 2.4 * _s,
          ),
          Paint()..color = const Color(0xCC2A2420),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: c,
            width: ex * 1.2 * _s,
            height: ey * 1.2 * _s,
          ),
          Paint()..color = const Color(0xFF14100D),
        );
        continue;
      }
      switch (t.kind) {
        case BombTargetKind.hangar:
          final r = Rect.fromCenter(
            center: c,
            width: ex * 2 * _s,
            height: ey * 2 * _s,
          );
          canvas.drawRect(r.shift(Offset(6 * _s, 6 * _s)), shadow);
          canvas.drawRRect(
            RRect.fromRectAndRadius(r, Radius.circular(6 * _s)),
            Paint()..color = f(const Color(0xFF6C7A6B)),
          );
          final rib = Paint()
            ..color = const Color(0x55203020)
            ..strokeWidth = 1.4;
          for (var k = 1; k < 8; k++) {
            final x = r.left + r.width * k / 8;
            canvas.drawLine(Offset(x, r.top + 2), Offset(x, r.bottom - 2), rib);
          }
          canvas.drawRect(
            Rect.fromLTWH(
              r.left + r.width * 0.3,
              r.bottom - 5 * _s,
              r.width * 0.4,
              5 * _s,
            ),
            Paint()..color = const Color(0xFF2E2A26),
          );
          canvas.drawCircle(
            r.center,
            5 * _s,
            Paint()..color = f(Palette.pirateSail),
          );
        case BombTargetKind.depot:
          for (final o in [
            const Offset(-9, -7),
            const Offset(9, -7),
            const Offset(0, 9),
          ]) {
            final p = c + o * _s;
            canvas.drawCircle(p + Offset(4 * _s, 4 * _s), 10 * _s, shadow);
            canvas.drawCircle(
              p,
              10 * _s,
              Paint()..color = f(const Color(0xFFB8402E)),
            );
            canvas.drawCircle(
              p,
              5 * _s,
              Paint()..color = f(const Color(0xFFD9604A)),
            );
          }
        case BombTargetKind.gun:
          canvas.drawCircle(c + Offset(4 * _s, 4 * _s), 13 * _s, shadow);
          canvas.drawCircle(
            c,
            13 * _s,
            Paint()..color = f(const Color(0xFFC2B08A)),
          );
          canvas.drawCircle(
            c,
            8 * _s,
            Paint()..color = f(const Color(0xFF4F535A)),
          );
          final ang = math.atan2(-(sim.plane.y - t.y), sim.plane.x - t.x);
          canvas.drawLine(
            c,
            c + Offset(math.cos(ang), math.sin(ang)) * 14 * _s,
            Paint()
              ..color = const Color(0xFF2B2E33)
              ..strokeWidth = 4 * _s
              ..strokeCap = StrokeCap.round,
          );
        case BombTargetKind.airship:
          _paintAirship(canvas, t, c, ex, ey, f);
      }
      if (t.primary && t.alive) {
        final ring = Paint()
          ..color = Palette.hud.withValues(
            alpha: 0.5 + 0.3 * math.sin(sim.time * 4),
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawRect(
          Rect.fromCenter(
            center: c,
            width: (ex * 2 + 18) * _s,
            height: (ey * 2 + 18) * _s,
          ),
          ring,
        );
      }
    }
  }

  /// An original armoured airship seen from above: plated gas bag, red
  /// fins and a long gondola, nose pointing the way it flies (up).
  void _paintAirship(
    Canvas canvas,
    BombTarget t,
    Offset c,
    double ex,
    double ey,
    Color Function(Color) f,
  ) {
    // Shadow on the clouds far below.
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(40 * _s, 60 * _s),
        width: ex * 2 * _s,
        height: ey * 2 * _s,
      ),
      Paint()..color = const Color(0x33203048),
    );
    final len = ey * _s; // half length
    final wid = ex * _s; // half width
    canvas.save();
    canvas.translate(c.dx, c.dy);
    // Tail fins at the back (bottom of the screen).
    final fins = Path()
      ..moveTo(-wid * 0.3, len * 0.75)
      ..lineTo(-wid * 1.4, len * 1.05)
      ..lineTo(-wid * 1.4, len * 1.2)
      ..lineTo(0, len * 1.0)
      ..lineTo(wid * 1.4, len * 1.2)
      ..lineTo(wid * 1.4, len * 1.05)
      ..lineTo(wid * 0.3, len * 0.75)
      ..close();
    canvas.drawPath(fins, Paint()..color = f(Palette.pirateSail));
    final body = Rect.fromCenter(
      center: Offset.zero,
      width: wid * 2,
      height: len * 2,
    );
    canvas.drawOval(body, Paint()..color = f(const Color(0xFF7A7F86)));
    canvas.drawOval(
      body.deflate(wid * 0.35).translate(-wid * 0.2, 0),
      Paint()..color = f(const Color(0xFF8E939A)),
    );
    final plate = Paint()
      ..color = const Color(0x55202428)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (var k = 1; k < 7; k++) {
      final y = -len + 2 * len * k / 7;
      final hw = math.sqrt(1 - math.pow(y / len, 2)) * wid;
      canvas.drawLine(Offset(-hw, y), Offset(hw, y), plate);
    }
    canvas.drawLine(Offset(0, -len + 8 * _s), Offset(0, len - 8 * _s), plate);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, len * 0.1),
          width: 9 * _s,
          height: len * 0.9,
        ),
        Radius.circular(4 * _s),
      ),
      Paint()..color = f(Palette.woodDark),
    );
    // Propeller blurs on the flanks.
    final prop = Paint()..color = const Color(0x55FFFFFF);
    for (final side in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(side * wid * 1.05, len * 0.35),
          width: 6 * _s,
          height: 16 * _s,
        ),
        prop,
      );
    }
    canvas.restore();
    // Damage bar so the player can see the hull giving way.
    paintMeter(
      canvas,
      Rect.fromCenter(center: c + Offset(0, -len - 14), width: 70, height: 5),
      t.hp / t.maxHp,
      color: Palette.danger,
    );
  }

  void _paintBombs(Canvas canvas) {
    for (final b in sim.bombs) {
      final p = b.current;
      final o = g(p.x, p.y);
      // Shrinks as it falls away from the plane.
      final k = 1 - b.t * 0.7;
      canvas.save();
      canvas.translate(o.dx, o.dy);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: 7 * _s * k,
          height: 14 * _s * k,
        ),
        Paint()..color = const Color(0xFF2A2A2E),
      );
      canvas.drawLine(
        Offset(0, 7 * _s * k),
        Offset(0, 11 * _s * k),
        Paint()
          ..color = const Color(0xFF6A6A70)
          ..strokeWidth = 3 * _s * k,
      );
      canvas.restore();
    }
  }

  void _paintGroundEffects(Canvas canvas) {
    for (final fx in sim.effects.items) {
      if (fx.kind == EffectKind.flak) continue;
      final o = g(fx.pos.x, fx.pos.y);
      final r = math.max(1.0, fx.size * _s);
      final fade = 1 - fx.t;
      switch (fx.kind) {
        case EffectKind.fire:
          paintGlow(
            canvas,
            o,
            r * 1.4,
            Color.fromRGBO(255, 150, 50, 0.85 * fade),
          );
          canvas.drawCircle(
            o,
            r * 0.45,
            Paint()..color = Color.fromRGBO(255, 230, 140, fade),
          );
        case EffectKind.splash:
          canvas.drawCircle(
            o,
            r * 0.6,
            Paint()..color = Color.fromRGBO(255, 255, 255, 0.5 * fade),
          );
        case EffectKind.smoke:
          canvas.drawCircle(
            o,
            r * 0.6,
            Paint()..color = Color.fromRGBO(45, 45, 50, 0.38 * fade),
          );
        case EffectKind.debris:
          canvas.drawRect(
            Rect.fromCenter(center: o, width: r * 1.4, height: r),
            Paint()..color = Color.fromRGBO(60, 40, 28, fade),
          );
        case EffectKind.spark:
          canvas.drawCircle(
            o,
            r,
            Paint()..color = Color.fromRGBO(255, 236, 160, fade),
          );
        case EffectKind.flak:
          break;
      }
    }
  }

  void _paintAirEffects(Canvas canvas) {
    for (final fx in sim.effects.items) {
      if (fx.kind != EffectKind.flak) continue;
      final o = g(fx.pos.x, fx.pos.y);
      final r = fx.size * _s;
      final fade = 1 - fx.t;
      canvas.drawCircle(
        o,
        r * 0.6,
        Paint()..color = Color.fromRGBO(35, 35, 40, 0.75 * fade),
      );
      if (fx.t < 0.25) {
        canvas.drawCircle(
          o,
          r * 0.3,
          Paint()..color = Color.fromRGBO(255, 170, 80, 1 - fx.t / 0.25),
        );
      }
    }
  }

  void _paintSight(Canvas canvas) {
    if (sim.planeDown || sim.bombsLeft == 0) return;
    final s = sim.sightPoint;
    final c = g(s.x, s.y);
    final paint = Paint()
      ..color = Palette.hud
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(c, 14 * _s, paint);
    canvas.drawLine(c - Offset(22 * _s, 0), c - Offset(8 * _s, 0), paint);
    canvas.drawLine(c + Offset(22 * _s, 0), c + Offset(8 * _s, 0), paint);
    canvas.drawLine(c - Offset(0, 22 * _s), c - Offset(0, 8 * _s), paint);
    canvas.drawLine(c + Offset(0, 22 * _s), c + Offset(0, 8 * _s), paint);
    // Dotted line back to the plane.
    final from = g(sim.plane.x, sim.plane.y);
    final dot = Paint()..color = Palette.hudDim;
    for (var k = 0.15; k < 0.9; k += 0.08) {
      canvas.drawCircle(Offset.lerp(from, c, k)!, 1.4, dot);
    }
  }

  void _paintPlane(Canvas canvas) {
    final p = g(sim.plane.x, sim.plane.y);
    final span = 70 * _s;
    final roll = (sim.vx / 170).clamp(-1.0, 1.0) * 0.5;
    canvas.save();
    canvas.translate(p.dx, p.dy);
    if (sim.planeDown) canvas.rotate(sim.time * 2);
    // Banking narrows the wings as seen from above.
    final wx = math.cos(roll);
    final wing = Paint()..color = Palette.playerWing;
    final body = Paint()..color = Palette.playerBody;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, -span * 0.04),
          width: span * wx,
          height: span * 0.15,
        ),
        Radius.circular(span * 0.05),
      ),
      wing,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, span * 0.36),
          width: span * 0.36 * wx,
          height: span * 0.08,
        ),
        Radius.circular(span * 0.03),
      ),
      wing,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, span * 0.08),
          width: span * 0.12,
          height: span * 0.62,
        ),
        Radius.circular(span * 0.06),
      ),
      body,
    );
    canvas.drawCircle(
      Offset(0, -span * 0.02),
      span * 0.045,
      Paint()..color = const Color(0xFF1B4B4D),
    );
    canvas.drawCircle(
      Offset(-span * 0.48 * wx, -span * 0.04),
      span * 0.03,
      Paint()..color = Palette.brass,
    );
    canvas.drawCircle(
      Offset(span * 0.48 * wx, -span * 0.04),
      span * 0.03,
      Paint()..color = Palette.brass,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, -span * 0.25),
        width: span * 0.32,
        height: span * 0.05,
      ),
      Paint()..color = const Color(0x55FFFFFF),
    );
    canvas.restore();
  }

  void _paintHud(Canvas canvas, Size size, EdgeInsetsLike safe) {
    final left = safe.left + 16;
    final top = safe.top + 14;
    paintHudPanel(
      canvas,
      Rect.fromLTRB(left - 10, top - 8, left + 170, top + 108),
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
      '${tr('hud.bombs')}: ${sim.bombsLeft}',
      Offset(left, top + 30),
      size: 12,
    );
    final primaries = sim.primaries.length;
    paintLabel(
      canvas,
      '${tr('hud.primary')}: ${primaries - sim.primariesLeft}/$primaries',
      Offset(left, top + 48),
      size: 12,
      color: sim.primariesLeft == 0 ? Palette.ok : Palette.hud,
    );
    // Wind.
    final w = sim.config.wind;
    final wc = Offset(left + 36, top + 92);
    paintLabel(canvas, tr('hud.wind'), Offset(left, top + 68), size: 11);
    final len = 10 + w.abs() * 0.6;
    final dir = w >= 0 ? 1.0 : -1.0;
    final arrow = Paint()
      ..color = Palette.hud
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      wc - Offset(len * dir, 0),
      wc + Offset(len * dir, 0),
      arrow,
    );
    canvas.drawLine(
      wc + Offset(len * dir, 0),
      wc + Offset((len - 7) * dir, -5),
      arrow,
    );
    canvas.drawLine(
      wc + Offset(len * dir, 0),
      wc + Offset((len - 7) * dir, 5),
      arrow,
    );
    paintLabel(
      canvas,
      '${w.abs().round()}',
      Offset(wc.dx + len + 10, wc.dy),
      size: 11,
      anchor: const Offset(0, 0.5),
    );
    // Progress.
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
  }
}
