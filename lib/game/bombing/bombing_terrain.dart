import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../paint_kit.dart';
import 'bombing_sim.dart';

/// Ground (x, y) in picture space: y grows up the screen in the world, so
/// it is flipped here. The painter maps this to the screen with one
/// translate and one scale.
Offset gp(double x, double y) => Offset(x, -y);

enum _Kind {
  barracks,
  tent,
  crates,
  barrels,
  tree,
  tower,
  campfire,
  mooredShip,
  cart,
}

class _Decor {
  _Decor(this.kind, this.x, this.y, this.w, this.h, this.tint);

  final _Kind kind;
  final double x, y, w, h;
  final int tint;
}

/// The pirate base's plateau seen from above, recorded once per chunk.
class BombingTerrain {
  BombingTerrain(this.sim) : _rng = math.Random(sim.config.seed * 613 + 5) {
    _build();
  }

  static const double chunk = 300;

  final BombingSim sim;
  final math.Random _rng;
  final List<_Decor> _decor = [];
  final List<Rect> _taken = [];
  final List<(Offset, double, int)> _patches = [];
  final Map<int, ui.Picture> _bases = {};
  final Map<int, ui.Picture> _surfaces = {};
  final Map<int, ui.Picture> _decors = {};

  double get top => sim.config.length + 150;

  /// Ground taken by camp buildings (with their margin); for checks.
  List<Rect> get footprints => List.unmodifiable(_taken);

  double _path(double y) => 110 * math.sin(y / 380 + sim.config.seed);

  bool _place(
    _Kind kind,
    double x,
    double y,
    double w,
    double h, {
    int tint = 0,
    double pad = 8,
  }) {
    final hw = sim.halfWidthAt(y);
    if (x.abs() + w / 2 > hw - 26) return false;
    final r = Rect.fromCenter(
      center: Offset(x, y),
      width: w + pad * 2,
      height: h + pad * 2,
    );
    for (final t in sim.targets) {
      if (t.kind == BombTargetKind.airship) continue;
      final (ex, ey) = BombTarget.extent(t.kind);
      if (r.overlaps(
        Rect.fromCenter(
          center: Offset(t.x, t.y),
          width: ex * 2 + 30,
          height: ey * 2 + 30,
        ),
      )) {
        return false;
      }
    }
    if (_taken.any(r.overlaps)) return false;
    if ((x - _path(y)).abs() < w / 2 + 12) return false;
    // Keep the runway clear.
    if (x.abs() < 30 + w / 2 &&
        y > 60 &&
        y < math.min(sim.config.length - 60, 920)) {
      return false;
    }
    _taken.add(r);
    _decor.add(_Decor(kind, x, y, w, h, tint));
    return true;
  }

  void _build() {
    final len = sim.config.length;
    // Clusters of camp buildings.
    for (var y = 60.0; y < len - 60; y += 160 + _rng.nextDouble() * 120) {
      final hw = sim.halfWidthAt(y);
      if (hw < 120) continue;
      final cx = (_rng.nextDouble() * 2 - 1) * (hw - 110);
      for (var k = 0; k < 9; k++) {
        final x = cx + (_rng.nextDouble() - 0.5) * 170;
        final yy = y + (_rng.nextDouble() - 0.5) * 120;
        final r = _rng.nextDouble();
        if (r < 0.3) {
          final vertical = _rng.nextBool();
          _place(
            _Kind.barracks,
            x,
            yy,
            vertical ? 22 : 58,
            vertical ? 58 : 22,
            tint: _rng.nextInt(3),
          );
        } else if (r < 0.55) {
          _place(_Kind.tent, x, yy, 24, 18, tint: _rng.nextInt(3));
        } else if (r < 0.7) {
          _place(_Kind.crates, x, yy, 22, 22, tint: _rng.nextInt(3));
        } else if (r < 0.82) {
          _place(_Kind.barrels, x, yy, 18, 18);
        } else if (r < 0.9) {
          _place(_Kind.campfire, x, yy, 14, 14);
        } else {
          _place(_Kind.cart, x, yy, 14, 22);
        }
      }
    }
    // Watchtowers by the palisade.
    var side = 1.0;
    for (var y = 120.0; y < len - 80; y += 330) {
      final x = side * (sim.halfWidthAt(y) - 40);
      _place(_Kind.tower, x, y, 18, 18, pad: 2);
      side = -side;
    }
    // Small airships moored off the edge (scenery only).
    for (var y = 300.0; y < len - 200; y += 520 + _rng.nextDouble() * 200) {
      final s = _rng.nextBool() ? 1.0 : -1.0;
      _decor.add(
        _Decor(
          _Kind.mooredShip,
          s * (sim.halfWidthAt(y) + 55),
          y,
          70,
          30,
          s > 0 ? 1 : 0,
        ),
      );
    }
    // Trees, mostly near the rim.
    for (var i = 0; i < len / 9; i++) {
      final y = _rng.nextDouble() * len;
      final hw = sim.halfWidthAt(y);
      if (hw < 60) continue;
      final edgeBias = math.pow(_rng.nextDouble(), 0.4).toDouble();
      final x = (_rng.nextBool() ? 1 : -1) * (hw - 34) * edgeBias;
      _place(
        _Kind.tree,
        x,
        y,
        14 + _rng.nextDouble() * 10,
        14,
        tint: _rng.nextInt(3),
        pad: 1,
      );
    }
    // Ground patches.
    for (var i = 0; i < len / 6; i++) {
      final y = -100 + _rng.nextDouble() * (len + 200);
      final hw = sim.halfWidthAt(y);
      if (hw < 30) continue;
      _patches.add((
        Offset((_rng.nextDouble() * 2 - 1) * (hw - 20), y),
        6 + _rng.nextDouble() * 20,
        _rng.nextInt(4),
      ));
    }
  }

  int _chunkOf(double y) => ((y + 150) / chunk).floor();

  void paint(Canvas canvas, double yMin, double yMax) {
    final first = math.max(0, _chunkOf(yMin));
    final last = math.min(_chunkOf(top), _chunkOf(yMax));
    // Shadows and cliffs of every chunk first, so a neighbour's shadow
    // never lands on top of the plateau.
    for (var c = first; c <= last; c++) {
      canvas.drawPicture(_bases.putIfAbsent(c, () => _recordBase(c)));
    }
    for (var c = first; c <= last; c++) {
      canvas.drawPicture(_surfaces.putIfAbsent(c, () => _recordSurface(c)));
    }
    // Buildings last: one standing on a chunk border must not be painted
    // over by the next chunk's ground.
    for (var c = first; c <= last; c++) {
      canvas.drawPicture(_decors.putIfAbsent(c, () => _recordDecor(c)));
    }
  }

  ui.Picture _recordDecor(int c) {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final yLo = c * chunk - 150;
    for (final d in _decor) {
      if (d.y < yLo || d.y >= yLo + chunk) continue;
      _paintDecor(canvas, d);
    }
    return rec.endRecording();
  }

  void dispose() {
    for (final p in [
      ..._bases.values,
      ..._surfaces.values,
      ..._decors.values,
    ]) {
      p.dispose();
    }
    _bases.clear();
    _surfaces.clear();
    _decors.clear();
  }

  ui.Picture _recordBase(int c) {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final pts = _outline(c);
    if (pts.length >= 2) {
      canvas.drawPath(
        _shape(pts, 0, const Offset(34, 30)),
        Paint()..color = const Color(0x2E203048),
      );
      canvas.drawPath(
        _shape(pts, 14, const Offset(5, 10)),
        Paint()..color = Palette.rockDark,
      );
      canvas.drawPath(
        _shape(pts, 8, const Offset(2, 5)),
        Paint()..color = Palette.rock,
      );
    }
    return rec.endRecording();
  }

  /// One edge of the plateau as an open line, [inset] units inside.
  Path _edge(List<(double, double)> pts, double side, double inset) {
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final (y, hw) = pts[i];
      final p = gp(side * math.max(0, hw - inset), y);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  List<(double, double)> _outline(int c) {
    final y0 = c * chunk - 150 - 30;
    final y1 = (c + 1) * chunk - 150 + 30;
    return sim.outline.where((p) => p.$1 >= y0 && p.$1 <= y1).toList();
  }

  Path _shape(List<(double, double)> pts, double grow, Offset shift) {
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final (y, hw) = pts[i];
      final p = gp(-hw - grow, y) + shift;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    for (var i = pts.length - 1; i >= 0; i--) {
      final (y, hw) = pts[i];
      final p = gp(hw + grow, y) + shift;
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  ui.Picture _recordSurface(int c) {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final pts = _outline(c);
    if (pts.length < 2) return rec.endRecording();
    final yLo = c * chunk - 150;
    final yHi = yLo + chunk;
    final rng = math.Random(c * 131 + sim.config.seed);

    // The ground stays inside this chunk's band (picture y is flipped).
    canvas.clipRect(Rect.fromLTRB(-2000, -(yHi + 0.5), 2000, -(yLo - 0.5)));
    final plateau = _shape(pts, 0, Offset.zero);
    canvas.drawPath(plateau, Paint()..color = const Color(0xFFB8996F));
    canvas.save();
    canvas.clipPath(plateau);

    // Texture: grass patches, worn earth, gravel.
    const patchColors = [
      Color(0xFF9E8260),
      Color(0xFF7FA05A),
      Color(0xFFC7AE88),
      Color(0xFF8DAE62),
    ];
    for (final (o, r, k) in _patches) {
      if (o.dy < yLo - 30 || o.dy > yHi + 30) continue;
      canvas.drawOval(
        Rect.fromCenter(
          center: gp(o.dx, o.dy),
          width: r * 2.4,
          height: r * 1.7,
        ),
        Paint()..color = patchColors[k].withValues(alpha: 0.8),
      );
    }
    final gravelA = Paint()..color = const Color(0x33FFF4DC);
    final gravelB = Paint()..color = const Color(0x22000000);
    for (var k = 0; k < 420; k++) {
      final y = yLo + rng.nextDouble() * chunk;
      final hw = sim.halfWidthAt(y);
      final x = (rng.nextDouble() * 2 - 1) * hw;
      canvas.drawCircle(
        gp(x, y),
        0.8 + rng.nextDouble() * 1.6,
        k.isEven ? gravelA : gravelB,
      );
    }

    // The camp road.
    final road = Path();
    for (var y = yLo - 10; y <= yHi + 10; y += 10) {
      final p = gp(_path(y), y);
      y == yLo - 10 ? road.moveTo(p.dx, p.dy) : road.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      road,
      Paint()
        ..color = const Color(0xFFA88A62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20,
    );
    canvas.drawPath(
      road,
      Paint()
        ..color = const Color(0xFFD2B88E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14,
    );

    // Runway for the pirates' own planes.
    final runTop = math.min(sim.config.length - 80, 900.0);
    if (yHi > 80 && yLo < runTop) {
      final a = gp(-18, math.max(80, yLo - 5));
      final b = gp(18, math.min(runTop, yHi + 5));
      canvas.drawRect(
        Rect.fromPoints(a, b),
        Paint()..color = const Color(0xFF8C7A64),
      );
      final dash = Paint()
        ..color = const Color(0xCCEFE6D2)
        ..strokeWidth = 2;
      for (var y = 100.0; y < runTop - 20; y += 40) {
        if (y < yLo - 20 || y > yHi) continue;
        canvas.drawLine(gp(0, y), gp(0, y + 18), dash);
      }
    }

    // Shade just inside the rim.
    for (final side in [-1.0, 1.0]) {
      canvas.drawPath(
        _edge(pts, side, 6),
        Paint()
          ..color = const Color(0x26000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12,
      );
    }
    // Palisade of stakes along the rim.
    final stake = Paint()..color = const Color(0xFF6B4A2C);
    for (var i = 0; i < pts.length - 1; i++) {
      for (final side in [-1.0, 1.0]) {
        final (y0, h0) = pts[i];
        final (y1, h1) = pts[i + 1];
        if (h0 < 40 || h1 < 40) continue;
        for (var t = 0.0; t < 1; t += 0.25) {
          final y = y0 + (y1 - y0) * t;
          final x = side * (h0 + (h1 - h0) * t - 16);
          canvas.drawCircle(gp(x, y), 2.4, stake);
        }
      }
    }
    canvas.restore();

    return rec.endRecording();
  }

  void _shadowRect(Canvas canvas, Rect r, double dx, double dy) {
    canvas.drawRect(
      r.shift(Offset(dx, dy)),
      Paint()..color = const Color(0x40000000),
    );
  }

  static const _roofs = [
    Color(0xFF7B6A58),
    Color(0xFF6C7A6B),
    Color(0xFF8A5A44),
  ];
  static const _canvas = [
    Color(0xFFE6DCC4),
    Color(0xFFCBB892),
    Color(0xFFB8432E),
  ];
  static const _trees = [
    Color(0xFF4F7A3E),
    Color(0xFF5C8A44),
    Color(0xFF3E6A3A),
  ];

  void _paintDecor(Canvas canvas, _Decor d) {
    final c = gp(d.x, d.y);
    final rect = Rect.fromCenter(center: c, width: d.w, height: d.h);
    switch (d.kind) {
      case _Kind.barracks:
        _shadowRect(canvas, rect, 5, 5);
        canvas.drawRect(rect, Paint()..color = _roofs[d.tint]);
        final ridgeAlongX = d.w > d.h;
        final half = ridgeAlongX
            ? Rect.fromLTRB(rect.left, rect.top, rect.right, rect.center.dy)
            : Rect.fromLTRB(rect.left, rect.top, rect.center.dx, rect.bottom);
        canvas.drawRect(half, Paint()..color = const Color(0x22FFFFFF));
        final rib = Paint()
          ..color = const Color(0x33000000)
          ..strokeWidth = 1;
        if (ridgeAlongX) {
          for (var x = rect.left + 5; x < rect.right; x += 5) {
            canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), rib);
          }
        } else {
          for (var y = rect.top + 5; y < rect.bottom; y += 5) {
            canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), rib);
          }
        }
        canvas.drawRect(
          rect,
          Paint()
            ..color = const Color(0x55000000)
            ..style = PaintingStyle.stroke,
        );
      case _Kind.tent:
        final p = Path()
          ..moveTo(rect.left, rect.center.dy)
          ..lineTo(rect.center.dx, rect.top)
          ..lineTo(rect.right, rect.center.dy)
          ..lineTo(rect.center.dx, rect.bottom)
          ..close();
        canvas.drawPath(
          p.shift(const Offset(4, 4)),
          Paint()..color = const Color(0x40000000),
        );
        canvas.drawPath(p, Paint()..color = _canvas[d.tint]);
        canvas.drawPath(
          Path()
            ..moveTo(rect.center.dx, rect.top)
            ..lineTo(rect.right, rect.center.dy)
            ..lineTo(rect.center.dx, rect.bottom)
            ..close(),
          Paint()..color = const Color(0x22000000),
        );
      case _Kind.crates:
        for (var i = 0; i < 4; i++) {
          final r = Rect.fromLTWH(
            rect.left + (i % 2) * 11,
            rect.top + (i ~/ 2) * 11,
            10,
            10,
          );
          _shadowRect(canvas, r, 3, 3);
          canvas.drawRect(r, Paint()..color = const Color(0xFFB98549));
          canvas.drawLine(
            r.topLeft,
            r.bottomRight,
            Paint()
              ..color = const Color(0xFF7C5430)
              ..strokeWidth = 1,
          );
        }
      case _Kind.barrels:
        for (var i = 0; i < 5; i++) {
          final p =
              rect.center +
              Offset(math.cos(i * 1.3) * 6, math.sin(i * 1.3) * 6);
          canvas.drawCircle(
            p + const Offset(2, 2),
            4,
            Paint()..color = const Color(0x40000000),
          );
          canvas.drawCircle(
            p,
            4,
            Paint()
              ..color = i.isEven
                  ? const Color(0xFF8A3A2A)
                  : const Color(0xFF5D5F63),
          );
          canvas.drawCircle(p, 1.6, Paint()..color = const Color(0x55000000));
        }
      case _Kind.campfire:
        for (var i = 0; i < 7; i++) {
          final a = i * math.pi * 2 / 7;
          canvas.drawCircle(
            rect.center + Offset(math.cos(a), math.sin(a)) * 6,
            1.8,
            Paint()..color = const Color(0xFF8E8A80),
          );
        }
        paintGlow(canvas, rect.center, 9, const Color(0xAAFF9A3C));
        canvas.drawCircle(
          rect.center,
          2.5,
          Paint()..color = const Color(0xFFFFD27A),
        );
      case _Kind.cart:
        _shadowRect(canvas, rect, 3, 3);
        canvas.drawRect(rect, Paint()..color = Palette.wood);
        canvas.drawLine(
          rect.topCenter,
          rect.topCenter - const Offset(0, 8),
          Paint()
            ..color = Palette.woodDark
            ..strokeWidth = 1.5,
        );
        for (final p in [
          rect.topLeft,
          rect.topRight,
          rect.bottomLeft,
          rect.bottomRight,
        ]) {
          canvas.drawRect(
            Rect.fromCenter(
              center: p + const Offset(0, 0),
              width: 3,
              height: 6,
            ),
            Paint()..color = const Color(0xFF2A2420),
          );
        }
      case _Kind.tower:
        _shadowRect(canvas, rect, 10, 9);
        canvas.drawRect(rect, Paint()..color = const Color(0xFF7A5A3A));
        canvas.drawLine(
          rect.topLeft,
          rect.bottomRight,
          Paint()
            ..color = const Color(0xFF5A3E26)
            ..strokeWidth = 1.5,
        );
        canvas.drawLine(
          rect.topRight,
          rect.bottomLeft,
          Paint()
            ..color = const Color(0xFF5A3E26)
            ..strokeWidth = 1.5,
        );
        canvas.drawRect(rect.deflate(5), Paint()..color = Palette.pirateSail);
      case _Kind.tree:
        canvas.drawCircle(
          c + Offset(d.w * 0.25, d.w * 0.25),
          d.w / 2,
          Paint()..color = const Color(0x40000000),
        );
        canvas.drawCircle(c, d.w / 2, Paint()..color = _trees[d.tint]);
        canvas.drawCircle(
          c - Offset(d.w * 0.12, d.w * 0.12),
          d.w * 0.28,
          Paint()
            ..color = Color.lerp(_trees[d.tint], const Color(0xFFFFFFFF), 0.2)!,
        );
      case _Kind.mooredShip:
        // Mooring line back to the rim, the gas bag, its shadow below.
        final rim = gp(d.x - (d.tint == 1 ? 55 : -55), d.y);
        canvas.drawLine(
          rim,
          c,
          Paint()
            ..color = const Color(0xAA3A2A1E)
            ..strokeWidth = 1.2,
        );
        canvas.drawOval(
          rect.shift(const Offset(26, 30)),
          Paint()..color = const Color(0x22203048),
        );
        canvas.drawOval(rect, Paint()..color = const Color(0xFFD9C7A1));
        canvas.drawOval(
          rect.deflate(6).shift(const Offset(-4, -3)),
          Paint()..color = const Color(0x22FFFFFF),
        );
        canvas.drawLine(
          rect.centerLeft + const Offset(8, 0),
          rect.centerRight - const Offset(8, 0),
          Paint()
            ..color = Palette.pirateSail
            ..strokeWidth = 3,
        );
    }
  }
}
