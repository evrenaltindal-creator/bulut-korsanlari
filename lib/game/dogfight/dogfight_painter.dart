import 'dart:math' as math;
import 'dart:ui';

import '../../core/effects.dart';
import '../../core/v3.dart';
import '../paint_kit.dart';
import 'camera3.dart';
import 'dogfight_sim.dart';

class _Face {
  const _Face(this.points, this.color);

  final List<V3> points;
  final Color color;
}

/// Model units to world units for the pirate fighter.
const double pirateModelScale = 2.8;

/// An original sky-pirate fighter: stubby wooden hull, canvas wings and a
/// tall patched sail as its tail fin.
List<_Face> _pirateModel(PirateClass cls) {
  const s = pirateModelScale;
  V3 p(double x, double y, double z) => V3(x * s, y * s, z * s);
  final sail = cls == PirateClass.ace ? Palette.aceSail : Palette.pirateSail;
  final trim = cls == PirateClass.ace ? Palette.aceTrim : Palette.pirateWing;
  final nose = p(0, 0, 9);
  final tl = p(-1.3, 1.1, 2);
  final tr = p(1.3, 1.1, 2);
  final br = p(1.3, -1.0, 2);
  final bl = p(-1.3, -1.0, 2);
  final tail = p(0, 0.4, -9);
  const hull = Palette.pirateHull;
  return [
    _Face([
      p(-1.3, 0.2, 3.5),
      p(-9.5, 0.7, 1.2),
      p(-9, 0.7, -1.4),
      p(-1.3, 0.2, -1),
    ], Palette.pirateWing),
    _Face([
      p(1.3, 0.2, 3.5),
      p(9.5, 0.7, 1.2),
      p(9, 0.7, -1.4),
      p(1.3, 0.2, -1),
    ], Palette.pirateWing),
    _Face([p(-9.5, 0.75, 1.2), p(-10.2, 1.4, 0), p(-9, 0.75, -1.4)], trim),
    _Face([p(9.5, 0.75, 1.2), p(10.2, 1.4, 0), p(9, 0.75, -1.4)], trim),
    _Face([nose, tr, tl], hull),
    _Face([nose, br, tr], hull),
    _Face([nose, bl, br], hull),
    _Face([nose, tl, bl], hull),
    _Face([tail, tl, tr], hull),
    _Face([tail, tr, br], hull),
    _Face([tail, br, bl], hull),
    _Face([tail, bl, tl], hull),
    _Face([
      p(-3.6, 0.4, -7.2),
      p(3.6, 0.4, -7.2),
      p(3.1, 0.4, -9),
      p(-3.1, 0.4, -9),
    ], Palette.pirateWing),
    _Face([
      p(0, 0.9, -4.5),
      p(0, 5.6, -8.2),
      p(0, 4.4, -9.6),
      p(0, 0.6, -9),
    ], sail),
  ];
}

class DogfightPainter {
  DogfightPainter(this.sim, this.tr) {
    final rng = math.Random(sim.config.seed * 31 + 7);
    for (var i = 0; i < 34; i++) {
      _clouds.add(
        _CloudSlot(
          V3(
            (rng.nextDouble() - 0.5) * _cloudBox * 2,
            DogfightSim.floorY + 120 + rng.nextDouble() * 2300,
            (rng.nextDouble() - 0.5) * _cloudBox * 2,
          ),
          CloudShape(rng, puffs: 4 + rng.nextInt(3)),
          70 + rng.nextDouble() * 120,
        ),
      );
    }
    for (var i = 0; i < 9; i++) {
      final a = i / 9 * math.pi * 2 + rng.nextDouble() * 0.4;
      final r = 6000 + rng.nextDouble() * 4000;
      _islands.add(
        _IslandSlot(
          V3(math.sin(a) * r, 300 + rng.nextDouble() * 1400, math.cos(a) * r),
          380 + rng.nextDouble() * 520,
          rng.nextInt(1 << 20),
        ),
      );
    }
    for (final cls in PirateClass.values) {
      _models[cls] = _pirateModel(cls);
    }
  }

  static const double _cloudBox = 2600;
  static const double _islandBox = 12000;
  static final V3 _sunDir = V3.fromAngles(0.7, 0.32);

  final DogfightSim sim;
  final Tr tr;
  final List<_CloudSlot> _clouds = [];
  final List<_IslandSlot> _islands = [];
  final Map<PirateClass, List<_Face>> _models = {};

  void paint(Canvas canvas, Size size, EdgeInsetsLike safe) {
    final cam = Camera3.follow(
      sim.player,
      width: size.width,
      height: size.height,
    );
    _paintSky(canvas, size, cam);

    final items = <_Drawable>[];
    final pp = sim.player.pos;

    for (final isl in _islands) {
      final pos = V3(
        pp.x + wrapCentered(isl.pos.x - pp.x, _islandBox),
        isl.pos.y,
        pp.z + wrapCentered(isl.pos.z - pp.z, _islandBox),
      );
      final pr = cam.project(pos);
      if (pr == null) continue;
      final d = pr.depth;
      final fade = 1 - smoothstep(7000, 11000, d);
      items.add(
        _Drawable(d, () {
          _billboard(canvas, cam, pr, () {
            paintFloatingIsland(
              canvas,
              Offset.zero,
              isl.radius * pr.scale,
              isl.seed,
              opacity: fade * 0.95,
            );
          });
        }),
      );
    }

    for (final c in _clouds) {
      final pos = V3(
        pp.x + wrapCentered(c.pos.x - pp.x, _cloudBox),
        c.pos.y,
        pp.z + wrapCentered(c.pos.z - pp.z, _cloudBox),
      );
      final pr = cam.project(pos);
      if (pr == null) continue;
      final d = pr.depth;
      final fade = (1 - smoothstep(1700, 2500, d)) * smoothstep(60, 260, d);
      items.add(
        _Drawable(d, () {
          c.shape.paint(
            canvas,
            Offset(pr.x, pr.y),
            c.size * pr.scale,
            fade * 0.85,
          );
        }),
      );
    }

    for (final e in sim.pirates) {
      final center = cam.project(e.pos);
      if (center == null) continue;
      items.add(_Drawable(center.depth, () => _paintPirate(canvas, cam, e)));
    }

    for (final b in sim.bullets) {
      final head = cam.project(b.pos);
      final tail = cam.project(b.pos - b.vel * 0.028);
      // Too close to the lens: a tracer this near would smear across the
      // whole screen.
      if (head == null || tail == null || tail.depth < 40) continue;
      items.add(
        _Drawable(head.depth, () {
          canvas.drawLine(
            Offset(tail.x, tail.y),
            Offset(head.x, head.y),
            Paint()
              ..color = b.fromPlayer
                  ? const Color(0xFFFFF0A0)
                  : const Color(0xFFFF8A65)
              ..strokeWidth = (2.4 * head.scale).clamp(1.2, 3.5)
              ..strokeCap = StrokeCap.round,
          );
        }),
      );
    }

    for (final fx in sim.effects.items) {
      final pr = cam.project(fx.pos);
      if (pr == null) continue;
      items.add(_Drawable(pr.depth, () => _paintEffect(canvas, fx, pr)));
    }

    items.sort((a, b) => b.depth.compareTo(a.depth));
    for (final it in items) {
      it.draw();
    }

    _paintPlayerPlane(canvas, size);
    _paintCrosshair(canvas, cam);
    _paintIndicators(canvas, size, cam, safe);
    _paintRadar(canvas, safe);
    _paintHud(canvas, size, safe);

    if (sim.playerHitFlash > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = Palette.danger.withValues(alpha: 0.22 * sim.playerHitFlash),
      );
    }
  }

  void _billboard(
    Canvas canvas,
    Camera3 cam,
    Projected pr,
    void Function() draw,
  ) {
    canvas.save();
    canvas.translate(pr.x, pr.y);
    canvas.rotate(-cam.roll);
    draw();
    canvas.restore();
  }

  void _paintSky(Canvas canvas, Size size, Camera3 cam) {
    final diag = math.sqrt(size.width * size.width + size.height * size.height);
    final h = cam.horizonOffset;
    canvas.save();
    canvas.translate(cam.cx, cam.cy);
    canvas.rotate(-cam.roll);
    final skyRect = Rect.fromLTRB(-diag, h - diag * 1.6, diag, h);
    canvas.drawRect(
      skyRect,
      Paint()
        ..shader = Gradient.linear(
          Offset(0, h - diag * 0.9),
          Offset(0, h),
          const [Palette.skyTop, Palette.skyMid, Palette.skyHorizon],
          const [0, 0.65, 1],
        ),
    );
    final seaRect = Rect.fromLTRB(-diag, h, diag, h + diag * 1.6);
    canvas.drawRect(
      seaRect,
      Paint()
        ..shader = Gradient.linear(
          Offset(0, h),
          Offset(0, h + diag * 0.7),
          const [Palette.cloudSeaNear, Palette.cloudSeaFar],
        ),
    );
    // Haze along the horizon.
    canvas.drawRect(
      Rect.fromLTRB(-diag, h - 22, diag, h + 18),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, h - 22),
          Offset(0, h + 18),
          const [Color(0x00FFFFFF), Color(0x88FFF3E2), Color(0x00FFFFFF)],
          const [0, 0.55, 1],
        ),
    );
    // Lumpy cloud-sea ripples that slide as the plane turns.
    final ripplePaint = Paint()..color = const Color(0x33FFFFFF);
    for (var row = 1; row < 6; row++) {
      final y = h + row * row * 9.0;
      final step = 60.0 + row * 30;
      final phase = (sim.player.yaw * 900 * row / 3) % step;
      for (var x = -diag - phase; x < diag; x += step) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x, y),
            width: step * 0.8,
            height: 4.0 + row * 2,
          ),
          ripplePaint,
        );
      }
    }
    canvas.restore();

    final sun = cam.projectDir(_sunDir);
    if (sun != null) {
      paintGlow(canvas, Offset(sun.x, sun.y), 120, const Color(0x66FFE8B0));
      canvas.drawCircle(
        Offset(sun.x, sun.y),
        22,
        Paint()..color = const Color(0xFFFFF4D6),
      );
    }
  }

  void _paintPirate(Canvas canvas, Camera3 cam, Pirate e) {
    final (r, u, f) = e.basis();
    final faces = _models[e.cls]!;
    final projected = <(double, Path, Color)>[];
    for (final face in faces) {
      final path = Path();
      var depth = 0.0;
      var ok = true;
      for (var i = 0; i < face.points.length; i++) {
        final lp = face.points[i];
        final w = e.pos + r * lp.x + u * lp.y + f * lp.z;
        final pr = cam.project(w);
        if (pr == null) {
          ok = false;
          break;
        }
        depth += pr.depth;
        if (i == 0) {
          path.moveTo(pr.x, pr.y);
        } else {
          path.lineTo(pr.x, pr.y);
        }
      }
      if (!ok) continue;
      path.close();
      // Two-sided shading from the face normal.
      final a = face.points[0];
      final b = face.points[1];
      final c = face.points[2];
      final nLocal = (b - a).cross(c - a).normalized();
      final n = (r * nLocal.x + u * nLocal.y + f * nLocal.z).normalized();
      final light = 0.62 + 0.45 * n.dot(_sunDir).abs();
      var color = _shade(face.color, light);
      if (e.hitFlash > 0) {
        color = Color.lerp(color, const Color(0xFFFFFFFF), e.hitFlash * 0.6)!;
      }
      if (!e.alive) color = Color.lerp(color, const Color(0xFF202020), 0.45)!;
      projected.add((depth / face.points.length, path, color));
    }
    projected.sort((a, b) => b.$1.compareTo(a.$1));
    for (final (_, path, color) in projected) {
      canvas.drawPath(path, Paint()..color = color);
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0x55000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }
    // Spinning propeller disc on the nose.
    final nose = cam.project(e.pos + f * (9.6 * pirateModelScale));
    if (nose != null && e.alive) {
      canvas.drawCircle(
        Offset(nose.x, nose.y),
        math.max(1.5, 4.5 * pirateModelScale * nose.scale),
        Paint()..color = const Color(0x33EEEEEE),
      );
    }
  }

  Color _shade(Color c, double k) {
    int ch(double v) => (v * 255 * k).clamp(0, 255).round();
    return Color.fromARGB(255, ch(c.r), ch(c.g), ch(c.b));
  }

  void _paintEffect(Canvas canvas, Effect fx, Projected pr) {
    final r = math.max(1.0, fx.size * pr.scale);
    final o = Offset(pr.x, pr.y);
    final fade = 1 - fx.t;
    switch (fx.kind) {
      case EffectKind.spark:
        canvas.drawCircle(
          o,
          r,
          Paint()..color = Color.fromRGBO(255, 240, 170, fade),
        );
      case EffectKind.fire:
        paintGlow(canvas, o, r * 1.8, Color.fromRGBO(255, 170, 60, 0.8 * fade));
        canvas.drawCircle(
          o,
          r * 0.7,
          Paint()..color = Color.fromRGBO(255, 220, 120, fade),
        );
      case EffectKind.smoke:
        canvas.drawCircle(
          o,
          r,
          Paint()..color = Color.fromRGBO(60, 60, 66, 0.45 * fade),
        );
      case EffectKind.debris:
        canvas.drawRect(
          Rect.fromCenter(center: o, width: r * 1.6, height: r),
          Paint()..color = Color.fromRGBO(70, 45, 30, fade),
        );
      case EffectKind.flak:
      case EffectKind.splash:
        canvas.drawCircle(
          o,
          r,
          Paint()..color = Color.fromRGBO(80, 80, 80, 0.5 * fade),
        );
    }
  }

  /// The player's own fighter, seen from behind, tilted by the part of the
  /// bank the camera does not show.
  void _paintPlayerPlane(Canvas canvas, Size size) {
    final span = math.min(size.width, size.height) * 0.5;
    final center = Offset(size.width / 2, size.height * 0.86);
    final p = sim.player;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(p.roll * 0.3);
    final bob = math.sin(sim.time * 2.1) * span * 0.006;
    canvas.translate(0, bob);
    final wing = Paint()..color = Palette.playerWing;
    final body = Paint()..color = Palette.playerBody;
    final brass = Paint()..color = Palette.brass;
    final dark = Paint()..color = const Color(0xFF1B4B4D);
    // Lower wing.
    final lw = Path()
      ..moveTo(-span * 0.5, span * 0.02)
      ..lineTo(span * 0.5, span * 0.02)
      ..lineTo(span * 0.46, span * 0.075)
      ..lineTo(-span * 0.46, span * 0.075)
      ..close();
    canvas.drawPath(lw, wing);
    canvas.drawPath(
      lw,
      Paint()
        ..color = const Color(0x55000000)
        ..style = PaintingStyle.stroke,
    );
    // Wing-tip brass caps.
    canvas.drawCircle(Offset(-span * 0.49, span * 0.045), span * 0.022, brass);
    canvas.drawCircle(Offset(span * 0.49, span * 0.045), span * 0.022, brass);
    // Fuselage (rounded, seen from behind).
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, span * 0.02),
        width: span * 0.16,
        height: span * 0.2,
      ),
      body,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, -span * 0.01),
        width: span * 0.1,
        height: span * 0.1,
      ),
      dark,
    );
    // Tailplane.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, span * 0.07),
          width: span * 0.34,
          height: span * 0.03,
        ),
        Radius.circular(span * 0.015),
      ),
      body,
    );
    // Fin with a compass-rose emblem.
    final fin = Path()
      ..moveTo(-span * 0.018, span * 0.05)
      ..lineTo(-span * 0.012, -span * 0.12)
      ..lineTo(span * 0.012, -span * 0.12)
      ..lineTo(span * 0.018, span * 0.05)
      ..close();
    canvas.drawPath(fin, body);
    canvas.drawCircle(Offset(0, -span * 0.06), span * 0.012, brass);
    // Muzzle flashes at the wing guns.
    if (sim.muzzleFlash > 0) {
      final a = sim.muzzleFlash;
      paintGlow(
        canvas,
        Offset(-span * 0.16, span * 0.01),
        span * 0.05,
        Color.fromRGBO(255, 230, 140, a),
      );
      paintGlow(
        canvas,
        Offset(span * 0.16, span * 0.01),
        span * 0.05,
        Color.fromRGBO(255, 230, 140, a),
      );
    }
    if (sim.health < 0.4) {
      final k = (0.4 - sim.health) / 0.4;
      paintGlow(
        canvas,
        Offset(span * 0.05, -span * 0.02),
        span * 0.12 * (0.6 + k),
        Color.fromRGBO(40, 40, 40, 0.5 * k),
      );
    }
    canvas.restore();
  }

  void _paintCrosshair(Canvas canvas, Camera3 cam) {
    final c = Offset(cam.cx, cam.cy);
    final color = sim.jammed ? Palette.danger : Palette.hud;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(c, 16, paint);
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * 10, c + d * 22, paint);
    }
    canvas.drawCircle(c, 1.8, Paint()..color = color);
  }

  void _paintIndicators(
    Canvas canvas,
    Size size,
    Camera3 cam,
    EdgeInsetsLike safe,
  ) {
    const margin = 34.0;
    for (final e in sim.pirates) {
      if (!e.alive) continue;
      final color = e.cls == PirateClass.ace ? Palette.aceTrim : Palette.danger;
      final pr = cam.project(e.pos);
      final onScreen =
          pr != null &&
          pr.x > margin &&
          pr.x < size.width - margin &&
          pr.y > margin &&
          pr.y < size.height - margin;
      if (onScreen) {
        final box = math.max(14.0, 12 * pirateModelScale * pr.scale);
        final paint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        final rect = Rect.fromCenter(
          center: Offset(pr.x, pr.y),
          width: box * 2,
          height: box * 2,
        );
        const k = 0.3;
        for (final corner in [
          rect.topLeft,
          rect.topRight,
          rect.bottomLeft,
          rect.bottomRight,
        ]) {
          final dx = corner.dx < pr.x ? 1.0 : -1.0;
          final dy = corner.dy < pr.y ? 1.0 : -1.0;
          canvas.drawLine(corner, corner + Offset(box * 2 * k * dx, 0), paint);
          canvas.drawLine(corner, corner + Offset(0, box * 2 * k * dy), paint);
        }
        final dist = pr.depth.round();
        paintLabel(
          canvas,
          '${dist}m',
          Offset(pr.x, rect.bottom + 3),
          size: 11,
          color: color,
          anchor: const Offset(0.5, 0),
        );
        continue;
      }
      final c = cam.toCamera(e.pos);
      var dx = c.x;
      var dy = -c.y;
      if (dx.abs() < 1e-3 && dy.abs() < 1e-3) dy = 1;
      final ang = math.atan2(dy, dx);
      final rx = size.width / 2 - margin - math.max(safe.left, safe.right);
      final ry = size.height / 2 - margin - math.max(safe.top, safe.bottom);
      final pos = Offset(
        size.width / 2 + math.cos(ang) * rx,
        size.height / 2 + math.sin(ang) * ry,
      );
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(ang);
      final tri = Path()
        ..moveTo(14, 0)
        ..lineTo(-6, -9)
        ..lineTo(-6, 9)
        ..close();
      canvas.drawPath(tri, Paint()..color = color.withValues(alpha: 0.9));
      canvas.restore();
    }
  }

  void _paintRadar(Canvas canvas, EdgeInsetsLike safe) {
    const r = 46.0;
    final c = Offset(safe.left + 16 + r, safe.top + 16 + r);
    canvas.drawCircle(c, r, Paint()..color = const Color(0x5510202F));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = Palette.hudDim
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(
      c,
      r / 2,
      Paint()
        ..color = const Color(0x33FFD27A)
        ..style = PaintingStyle.stroke,
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
      if (v.distance > r - 3) v = v / v.distance * (r - 3);
      final above = rel.y > 150;
      final below = rel.y < -150;
      final color = e.cls == PirateClass.ace ? Palette.aceTrim : Palette.danger;
      canvas.drawCircle(c + v, 3.2, Paint()..color = color);
      if (above || below) {
        canvas.drawLine(
          c + v,
          c + v + Offset(0, above ? -6 : 6),
          Paint()
            ..color = color
            ..strokeWidth = 1.4,
        );
      }
    }
    final me = Path()
      ..moveTo(c.dx, c.dy - 6)
      ..lineTo(c.dx - 4.5, c.dy + 5)
      ..lineTo(c.dx + 4.5, c.dy + 5)
      ..close();
    canvas.drawPath(me, Paint()..color = Palette.ok);
  }

  void _paintHud(Canvas canvas, Size size, EdgeInsetsLike safe) {
    final right = size.width - safe.right - 72;
    final top = safe.top + 16;
    paintHudPanel(
      canvas,
      Rect.fromLTRB(right - 160, top - 8, right + 10, top + 80),
    );
    paintLabel(
      canvas,
      tr('hud.hull'),
      Offset(right - 150, top),
      size: 11,
      anchor: Offset.zero,
    );
    paintMeter(
      canvas,
      Rect.fromLTWH(right - 150, top + 15, 150, 9),
      sim.health,
      color: sim.health > 0.35 ? Palette.ok : Palette.danger,
    );
    paintLabel(
      canvas,
      sim.jammed ? tr('hud.jammed') : tr('hud.heat'),
      Offset(right - 150, top + 30),
      size: 11,
      color: sim.jammed ? Palette.danger : Palette.hud,
    );
    paintMeter(
      canvas,
      Rect.fromLTWH(right - 150, top + 45, 150, 7),
      sim.heat,
      color: sim.jammed ? Palette.danger : const Color(0xFFFFA24D),
    );
    paintLabel(
      canvas,
      '${tr('hud.enemies')}: ${sim.remaining}',
      Offset(right, top + 60),
      size: 13,
      anchor: const Offset(1, 0),
    );
    if (sim.lowWarning && !sim.playerDown) {
      final blink = (sim.time * 3).floor().isEven;
      if (blink) {
        paintLabel(
          canvas,
          tr('hud.lowAltitude'),
          Offset(size.width / 2, size.height * 0.22),
          size: 18,
          color: Palette.danger,
          anchor: const Offset(0.5, 0.5),
        );
      }
    }
    paintLabel(
      canvas,
      '${tr('hud.altitude')} ${sim.player.pos.y.round()}',
      Offset(safe.left + 16, safe.top + 16 + 46 * 2 + 8),
      size: 11,
    );
  }
}

class _CloudSlot {
  _CloudSlot(this.pos, this.shape, this.size);

  final V3 pos;
  final CloudShape shape;
  final double size;
}

class _IslandSlot {
  _IslandSlot(this.pos, this.radius, this.seed);

  final V3 pos;
  final double radius;
  final int seed;
}

class _Drawable {
  _Drawable(this.depth, this.draw);

  final double depth;
  final void Function() draw;
}
