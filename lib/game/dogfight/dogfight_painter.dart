import 'dart:math' as math;
import 'dart:ui';

import '../../core/effects.dart';
import '../../core/v3.dart';
import '../paint_kit.dart';
import 'camera3.dart';
import 'cockpit_painter.dart';
import 'dogfight_sim.dart';

class _Face {
  const _Face(this.points, this.color);

  final List<V3> points;
  final Color color;
}

/// Model units to world units for the pirate fighter.
const double pirateModelScale = 2.8;

/// Paint schemes: scouts in sun-bleached canvas, raiders in soot grey,
/// the aces in black and gold.
({Color hull, Color wing, Color band, Color sail}) _scheme(PirateClass cls) =>
    switch (cls) {
      PirateClass.scout => (
        hull: Palette.pirateHull,
        wing: Palette.pirateWing,
        band: Palette.pirateSail,
        sail: Palette.pirateSail,
      ),
      PirateClass.raider => (
        hull: const Color(0xFF3A2C26),
        wing: const Color(0xFF7C7A72),
        band: const Color(0xFFC9452F),
        sail: const Color(0xFF8E2420),
      ),
      PirateClass.ace => (
        hull: const Color(0xFF1C1A1E),
        wing: const Color(0xFF2B2A30),
        band: Palette.aceTrim,
        sail: Palette.aceSail,
      ),
    };

/// An original sky-pirate biplane: stubby wooden hull, two canvas wings
/// joined by struts, painted wing-tip bands, wheels, and a tall patched
/// sail as its tail fin.
List<_Face> _pirateModel(PirateClass cls) {
  const s = pirateModelScale;
  V3 p(double x, double y, double z) => V3(x * s, y * s, z * s);
  final c = _scheme(cls);
  final nose = p(0, 0, 9);
  final tl = p(-1.3, 1.1, 2);
  final tr = p(1.3, 1.1, 2);
  final br = p(1.3, -1.0, 2);
  final bl = p(-1.3, -1.0, 2);
  final tail = p(0, 0.4, -9);
  const strut = Color(0xFF3A2414);

  // A wing panel between x0 and x1 (x0 < x1) at height y.
  _Face panel(double x0, double x1, double y, Color color) => _Face([
    p(x0, y, 1.5),
    p(x1, y, 1.5),
    p(x1, y, -1.6),
    p(x0, y, -1.6),
  ], color);
  // A thin vertical strut seen edge-on from any side: two crossed quads.
  List<_Face> post(double x, double y0, double y1, double z) => [
    _Face([
      p(x - 0.15, y0, z),
      p(x + 0.15, y0, z),
      p(x + 0.15, y1, z),
      p(x - 0.15, y1, z),
    ], strut),
    _Face([
      p(x, y0, z - 0.2),
      p(x, y0, z + 0.2),
      p(x, y1, z + 0.2),
      p(x, y1, z - 0.2),
    ], strut),
  ];

  return [
    // Lower wing.
    panel(-8.5, -1.3, 0.1, c.wing),
    panel(1.3, 8.5, 0.1, c.wing),
    // Upper wing, with painted tips.
    panel(-10, -7.8, 3.4, c.band),
    panel(-7.8, 7.8, 3.4, c.wing),
    panel(7.8, 10, 3.4, c.band),
    ...post(-6.6, 0.1, 3.4, 0),
    ...post(6.6, 0.1, 3.4, 0),
    ...post(-1.1, 1.1, 3.4, 0.6),
    ...post(1.1, 1.1, 3.4, 0.6),
    // Hull.
    _Face([nose, tr, tl], c.hull),
    _Face([nose, br, tr], c.hull),
    _Face([nose, bl, br], c.hull),
    _Face([nose, tl, bl], c.hull),
    _Face([tail, tl, tr], c.hull),
    _Face([tail, tr, br], c.hull),
    _Face([tail, br, bl], c.hull),
    _Face([tail, bl, tl], c.hull),
    // Engine cowl ring.
    _Face([
      p(-1, 0.9, 8),
      p(1, 0.9, 8),
      p(1, -0.8, 8),
      p(-1, -0.8, 8),
    ], const Color(0xFF26231F)),
    // Wheels and their legs.
    ...post(-1.4, -2.4, -1.0, 4),
    ...post(1.4, -2.4, -1.0, 4),
    _Face([
      p(-1.4, -2.0, 4.6),
      p(-1.4, -2.9, 4),
      p(-1.4, -2.0, 3.4),
    ], const Color(0xFF151515)),
    _Face([
      p(1.4, -2.0, 4.6),
      p(1.4, -2.9, 4),
      p(1.4, -2.0, 3.4),
    ], const Color(0xFF151515)),
    // Tailplane and the sail fin.
    _Face([
      p(-3.6, 0.4, -7.2),
      p(3.6, 0.4, -7.2),
      p(3.1, 0.4, -9),
      p(-3.1, 0.4, -9),
    ], c.wing),
    _Face([
      p(0, 0.9, -4.5),
      p(0, 5.6, -8.2),
      p(0, 4.4, -9.6),
      p(0, 0.6, -9),
    ], c.sail),
  ];
}

class DogfightPainter {
  DogfightPainter(this.sim, this.tr) : cockpit = CockpitPainter(sim, tr) {
    final rng = math.Random(sim.config.seed * 31 + 7);
    for (var i = 0; i < 30; i++) {
      _clouds.add(
        _CloudSlot(
          V3(
            (rng.nextDouble() - 0.5) * _cloudBox * 2,
            DogfightSim.floorY + 250 + rng.nextDouble() * 2200,
            (rng.nextDouble() - 0.5) * _cloudBox * 2,
          ),
          CloudShape(rng, puffs: 4 + rng.nextInt(3)),
          70 + rng.nextDouble() * 120,
        ),
      );
    }
    // The tops of the cloud sea: a dense field of cumulus below the plane.
    for (var i = 0; i < 70; i++) {
      _floor.add(
        _CloudSlot(
          V3(
            (rng.nextDouble() - 0.5) * _floorBox * 2,
            DogfightSim.floorY - 40 + rng.nextDouble() * 70,
            (rng.nextDouble() - 0.5) * _floorBox * 2,
          ),
          CloudShape(rng, puffs: 6),
          150 + rng.nextDouble() * 170,
        ),
      );
    }
    for (var i = 0; i < 11; i++) {
      final a = i / 11 * math.pi * 2 + rng.nextDouble() * 0.4;
      final r = 3800 + rng.nextDouble() * 6000;
      _islands.add(
        _IslandSlot(
          V3(math.sin(a) * r, 250 + rng.nextDouble() * 1500, math.cos(a) * r),
          320 + rng.nextDouble() * 560,
          rng.nextInt(1 << 20),
        ),
      );
    }
    for (final cls in PirateClass.values) {
      _models[cls] = _pirateModel(cls);
    }
  }

  static const double _cloudBox = 2600;
  static const double _floorBox = 3200;
  static const double _islandBox = 12000;
  static final V3 _sunDir = V3.fromAngles(0.7, 0.32);

  final DogfightSim sim;
  final Tr tr;
  final CockpitPainter cockpit;
  final List<_CloudSlot> _clouds = [];
  final List<_CloudSlot> _floor = [];
  final List<_IslandSlot> _islands = [];
  final Map<PirateClass, List<_Face>> _models = {};

  void paint(Canvas canvas, Size size, EdgeInsetsLike safe) {
    final cam = Camera3.follow(
      sim.player,
      width: size.width,
      height: size.height,
      rollFactor: 1,
      centerY: CockpitPainter.viewCenter,
    );
    canvas.save();
    // A hit shakes the whole cockpit.
    final shake = sim.playerHitFlash;
    if (shake > 0) {
      canvas.translate(
        math.sin(sim.time * 97) * 5 * shake,
        math.cos(sim.time * 83) * 4 * shake,
      );
    }
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
      final fade = 1 - smoothstep(7000, 11000, pr.depth);
      items.add(
        _Drawable(pr.depth, () {
          _billboard(canvas, cam, pr, () {
            paintFloatingIsland(
              canvas,
              Offset.zero,
              isl.radius * pr.scale,
              isl.seed,
              opacity: fade * 0.97,
            );
          });
        }),
      );
    }

    void addClouds(
      List<_CloudSlot> slots,
      double box,
      double far,
      double opacity,
    ) {
      for (final c in slots) {
        final pos = V3(
          pp.x + wrapCentered(c.pos.x - pp.x, box),
          c.pos.y,
          pp.z + wrapCentered(c.pos.z - pp.z, box),
        );
        final pr = cam.project(pos);
        if (pr == null) continue;
        final fade =
            (1 - smoothstep(far * 0.7, far, pr.depth)) *
            smoothstep(60, 260, pr.depth);
        items.add(
          _Drawable(pr.depth, () {
            _billboard(canvas, cam, pr, () {
              c.shape.paint(
                canvas,
                Offset.zero,
                c.size * pr.scale,
                fade * opacity,
              );
            });
          }),
        );
      }
    }

    addClouds(_floor, _floorBox, 3200, 0.95);
    addClouds(_clouds, _cloudBox, 2500, 0.85);

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
          final color = b.fromPlayer
              ? const Color(0xFFFFF0A0)
              : const Color(0xFFFF8A65);
          final width = (2.4 * head.scale).clamp(1.2, 3.5);
          canvas.drawLine(
            Offset(tail.x, tail.y),
            Offset(head.x, head.y),
            Paint()
              ..color = color.withValues(alpha: 0.35)
              ..strokeWidth = width * 3
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawLine(
            Offset(tail.x, tail.y),
            Offset(head.x, head.y),
            Paint()
              ..color = color
              ..strokeWidth = width
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

    _paintIndicators(canvas, size, cam, safe);
    cockpit.paint(canvas, size, safe, cam);
    canvas.restore();

    if (sim.playerHitFlash > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = Palette.danger.withValues(alpha: 0.18 * sim.playerHitFlash),
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
    canvas.drawRect(
      Rect.fromLTRB(-diag * 2, h - diag * 3, diag * 2, h),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, h - diag * 0.9),
          Offset(0, h),
          const [Palette.skyTop, Palette.skyMid, Palette.skyHorizon],
          const [0, 0.65, 1],
        ),
    );
    // High, thin streaks of cirrus.
    final cirrus = Paint()
      ..color = const Color(0x22FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 9; k++) {
      final y = h - diag * (0.25 + (k * 37 % 50) / 100);
      final span = diag * (0.3 + (k % 3) * 0.15);
      final x =
          ((k * 911 - sim.player.yaw * diag * 0.6) % (diag * 3)) - diag * 1.5;
      cirrus.strokeWidth = 3.0 + (k % 3) * 2;
      canvas.drawLine(Offset(x, y), Offset(x + span, y - span * 0.05), cirrus);
    }
    canvas.drawRect(
      Rect.fromLTRB(-diag * 2, h, diag * 2, h + diag * 3),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, h),
          Offset(0, h + diag * 0.7),
          const [Palette.cloudSeaNear, Palette.cloudSeaFar],
        ),
    );
    // Haze along the horizon.
    canvas.drawRect(
      Rect.fromLTRB(-diag * 2, h - 26, diag * 2, h + 18),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, h - 26),
          Offset(0, h + 18),
          const [Color(0x00FFFFFF), Color(0x99FFF3E2), Color(0x00FFFFFF)],
          const [0, 0.55, 1],
        ),
    );
    canvas.restore();

    final sun = cam.projectDir(_sunDir);
    if (sun != null) {
      final s = Offset(sun.x, sun.y);
      paintGlow(canvas, s, 160, const Color(0x55FFE8B0));
      // Soft rays.
      final ray = Paint()..color = const Color(0x10FFF4D6);
      for (var k = 0; k < 8; k++) {
        final a = k * math.pi / 4 + sim.time * 0.02;
        final path = Path()
          ..moveTo(s.dx, s.dy)
          ..lineTo(
            s.dx + math.cos(a - 0.06) * 260,
            s.dy + math.sin(a - 0.06) * 260,
          )
          ..lineTo(
            s.dx + math.cos(a + 0.06) * 260,
            s.dy + math.sin(a + 0.06) * 260,
          )
          ..close();
        canvas.drawPath(path, ray);
      }
      canvas.drawCircle(s, 22, Paint()..color = const Color(0xFFFFF4D6));
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
      final light = 0.6 + 0.48 * n.dot(_sunDir).abs();
      var color = _shade(face.color, light);
      if (e.hitFlash > 0) {
        color = Color.lerp(color, const Color(0xFFFFFFFF), e.hitFlash * 0.6)!;
      }
      if (!e.alive) color = Color.lerp(color, const Color(0xFF202020), 0.45)!;
      projected.add((depth / face.points.length, path, color));
    }
    projected.sort((a, b) => b.$1.compareTo(a.$1));
    final center = cam.project(e.pos);
    final outline = center != null && center.scale > 0.6;
    for (final (_, path, color) in projected) {
      canvas.drawPath(path, Paint()..color = color);
      if (outline) {
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0x55000000)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );
      }
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
        paintGlow(
          canvas,
          o,
          r * 2.5,
          Color.fromRGBO(255, 230, 150, 0.6 * fade),
        );
        canvas.drawCircle(
          o,
          r,
          Paint()..color = Color.fromRGBO(255, 245, 200, fade),
        );
      case EffectKind.fire:
        paintGlow(
          canvas,
          o,
          r * 2.2,
          Color.fromRGBO(255, 150, 50, 0.75 * fade),
        );
        canvas.drawCircle(
          o,
          r,
          Paint()..color = Color.fromRGBO(255, 190, 80, 0.9 * fade),
        );
        canvas.drawCircle(
          o - Offset(r * 0.2, r * 0.2),
          r * 0.55,
          Paint()..color = Color.fromRGBO(255, 245, 190, fade),
        );
      case EffectKind.smoke:
        canvas.drawCircle(
          o + Offset(r * 0.15, r * 0.15),
          r,
          Paint()..color = Color.fromRGBO(30, 30, 34, 0.35 * fade),
        );
        canvas.drawCircle(
          o,
          r * 0.85,
          Paint()..color = Color.fromRGBO(85, 85, 92, 0.45 * fade),
        );
      case EffectKind.debris:
        canvas.save();
        canvas.translate(o.dx, o.dy);
        canvas.rotate(fx.age * 9 + fx.size0);
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 0.9),
          Paint()..color = Color.fromRGBO(70, 45, 30, fade),
        );
        canvas.restore();
      case EffectKind.flak:
      case EffectKind.splash:
        canvas.drawCircle(
          o,
          r,
          Paint()..color = Color.fromRGBO(80, 80, 80, 0.5 * fade),
        );
    }
  }

  void _paintIndicators(
    Canvas canvas,
    Size size,
    Camera3 cam,
    EdgeInsetsLike safe,
  ) {
    const margin = 30.0;
    // Only the part of the screen the cockpit leaves open.
    final viewTop = cockpit.wingBottom(size) + margin;
    final viewBottom = size.height * CockpitPainter.dashMid - 4;
    for (final e in sim.pirates) {
      if (!e.alive) continue;
      final color = e.cls == PirateClass.ace ? Palette.aceTrim : Palette.danger;
      final pr = cam.project(e.pos);
      final onScreen =
          pr != null &&
          pr.x > margin &&
          pr.x < size.width - margin &&
          pr.y > viewTop &&
          pr.y < viewBottom;
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
        paintLabel(
          canvas,
          '${pr.depth.round()}m',
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
      final cx = size.width / 2;
      final cy = (viewTop + viewBottom) / 2;
      final rx = size.width / 2 - margin - math.max(safe.left, safe.right);
      final ry = (viewBottom - viewTop) / 2;
      final pos = Offset(cx + math.cos(ang) * rx, cy + math.sin(ang) * ry);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(ang);
      final tri = Path()
        ..moveTo(14, 0)
        ..lineTo(-6, -9)
        ..lineTo(-6, 9)
        ..close();
      canvas.drawPath(tri, Paint()..color = color.withValues(alpha: 0.9));
      canvas.drawPath(
        tri,
        Paint()
          ..color = const Color(0xAA000000)
          ..style = PaintingStyle.stroke,
      );
      canvas.restore();
    }
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
