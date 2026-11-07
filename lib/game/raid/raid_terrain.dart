import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../core/v3.dart';
import '../paint_kit.dart';
import 'raid_sim.dart';

/// Isometric projection at scale 1 with the world origin at (0, 0):
/// u goes up-right, v down-right, z straight up.
Offset iso0(double u, double v, double z) =>
    Offset(0.894 * (u + v), 0.447 * (v - u) - z);

enum _Crop { wheat, ploughed, rows, meadow, lavender }

class _Parcel {
  _Parcel(this.u0, this.v0, this.u1, this.v1, this.crop);

  final double u0, v0, u1, v1;
  final _Crop crop;
}

enum _PropKind {
  tree,
  pine,
  blossom,
  house,
  haystack,
  well,
  boulder,
  crates,
  mill,
}

class _Prop {
  _Prop(this.kind, this.u, this.v, this.size, this.tint);

  final _PropKind kind;
  final double u, v, size;
  final int tint;
}

/// Everything on and under the floating island that never moves.
///
/// The island is cut into chunks along the flight path; each chunk is
/// recorded once into a [ui.Picture] in [iso0] space and replayed every
/// frame with a translate and a scale. That keeps thousands of details
/// cheap to draw.
class RaidTerrain {
  RaidTerrain(this.sim) : _rng = math.Random(sim.config.seed * 977 + 11) {
    _build();
  }

  static const double chunk = 300;

  final RaidSim sim;
  final math.Random _rng;
  final List<_Parcel> _parcels = [];
  final List<(Offset, Offset, bool)> _borders =
      []; // (from, to, isHedge) in (u, v)
  final List<List<Offset>> _creeks = []; // polylines in (u, v)
  final List<_Prop> _props = [];
  final Map<int, ui.Picture> _tops = {};
  final Map<int, ui.Picture> _unders = {};
  final Map<int, ui.Picture> _standing = {};

  double get length => sim.config.length;

  /// Where trees, houses and the rest stand, as (u, v); for checks.
  List<Offset> get propPositions => [for (final p in _props) Offset(p.u, p.v)];

  bool _free(double u, double v, double clearance) {
    for (final t in sim.targets) {
      final du = t.u - u;
      final dv = t.v - v;
      if (du * du + dv * dv < clearance * clearance) return false;
    }
    return true;
  }

  double _road(double u) => 40 * math.sin(u / 300);

  bool _onRoad(double u, double v, double pad) =>
      (v - _road(u)).abs() < 12 + pad;

  void _build() {
    // Fields.
    const du = 92.0;
    const dv = 74.0;
    for (var u = 30.0; u < length - 30; u += du) {
      for (var v = -320.0; v < 320; v += dv) {
        final cu = u + du / 2;
        final cv = v + dv / 2;
        if (cv.abs() > sim.halfWidth(cu) - 16) continue;
        final r = _rng.nextDouble();
        if (r < 0.22) continue; // plain grass
        final crop = _Crop.values[_rng.nextInt(_Crop.values.length)];
        _parcels.add(_Parcel(u + 3, v + 3, u + du - 3, v + dv - 3, crop));
        if (_rng.nextDouble() < 0.45) {
          _borders.add((
            Offset(u, v),
            Offset(u + du, v),
            _rng.nextDouble() < 0.7,
          ));
        }
        if (_rng.nextDouble() < 0.35) {
          _borders.add((
            Offset(u, v),
            Offset(u, v + dv),
            _rng.nextDouble() < 0.7,
          ));
        }
      }
    }
    // A creek or two running off the front edge.
    final creekCount = 1 + (length > 3000 ? 1 : 0);
    for (var i = 0; i < creekCount; i++) {
      final uc = length * (0.3 + 0.4 * i) + (_rng.nextDouble() - 0.5) * 200;
      final pts = <Offset>[];
      for (var t = 0.0; t <= 1.0001; t += 0.05) {
        final u = uc + 45 * math.sin(t * 5 + i * 2);
        final hw = sim.halfWidth(u);
        pts.add(Offset(u, -hw * 0.9 + t * hw * 1.9));
      }
      _creeks.add(pts);
    }
    // Sim props: trees, huts and boulders already kept clear of targets.
    for (final (u, v, kind) in sim.props) {
      if (_onRoad(u, v, 6)) continue;
      final k = kind < 6
          ? _PropKind.tree
          : kind < 8
          ? _PropKind.house
          : _PropKind.boulder;
      _props.add(
        _Prop(k, u, v, 0.8 + _rng.nextDouble() * 0.5, _rng.nextInt(4)),
      );
    }
    // Villages.
    for (var u = 250.0; u < length - 250; u += 420 + _rng.nextDouble() * 260) {
      final hw = sim.halfWidth(u);
      final cv = (_rng.nextDouble() * 2 - 1) * (hw - 90);
      for (var k = 0; k < 7; k++) {
        final pu = u + (_rng.nextDouble() - 0.5) * 120;
        final pv = cv + (_rng.nextDouble() - 0.5) * 100;
        if (pv.abs() > sim.halfWidth(pu) - 30 ||
            !_free(pu, pv, 55) ||
            _onRoad(pu, pv, 14)) {
          continue;
        }
        final r = _rng.nextDouble();
        final kind = r < 0.6
            ? _PropKind.house
            : r < 0.8
            ? _PropKind.haystack
            : r < 0.9
            ? _PropKind.well
            : _PropKind.crates;
        _props.add(
          _Prop(kind, pu, pv, 0.9 + _rng.nextDouble() * 0.4, _rng.nextInt(4)),
        );
      }
    }
    // Windmills.
    for (var u = 500.0; u < length - 300; u += 1300 + _rng.nextDouble() * 400) {
      for (var attempt = 0; attempt < 10; attempt++) {
        final v = (_rng.nextDouble() * 2 - 1) * (sim.halfWidth(u) - 60);
        if (_free(u, v, 70) && !_onRoad(u, v, 20)) {
          _props.add(_Prop(_PropKind.mill, u, v, 1, 0));
          break;
        }
      }
    }
    // Woods along the edges.
    for (var u = 80.0; u < length - 80; u += 140 + _rng.nextDouble() * 160) {
      final side = _rng.nextBool() ? 1.0 : -1.0;
      final hw = sim.halfWidth(u);
      if (hw < 80) continue;
      final pine = _rng.nextDouble() < 0.4;
      for (var k = 0; k < 9; k++) {
        final pu = u + (_rng.nextDouble() - 0.5) * 110;
        final pv = side * (sim.halfWidth(pu) - 18 - _rng.nextDouble() * 55);
        if (pv.abs() > sim.halfWidth(pu) - 12 ||
            !_free(pu, pv, 40) ||
            _onRoad(pu, pv, 8)) {
          continue;
        }
        final kind = pine
            ? _PropKind.pine
            : _rng.nextDouble() < 0.12
            ? _PropKind.blossom
            : _PropKind.tree;
        _props.add(
          _Prop(kind, pu, pv, 0.7 + _rng.nextDouble() * 0.6, _rng.nextInt(4)),
        );
      }
    }
    _props.sort((a, b) => (a.v - a.u).compareTo(b.v - b.u));
  }

  int _chunkOf(double u) => (u / chunk).floor();

  /// Draws the rock under the island, then its surface, for the chunks
  /// between [uMin] and [uMax]. The canvas must already be in [iso0]
  /// space.
  void paint(Canvas canvas, double uMin, double uMax, double time) {
    final first = math.max(0, _chunkOf(uMin));
    final last = math.min(_chunkOf(length), _chunkOf(uMax));
    // Far (large u) first.
    for (var c = last; c >= first; c--) {
      canvas.drawPicture(_unders.putIfAbsent(c, () => _recordUnder(c)));
    }
    for (var c = last; c >= first; c--) {
      canvas.drawPicture(_tops.putIfAbsent(c, () => _recordTop(c)));
    }
    // Trees and houses after all the ground, so a nearer chunk's grass
    // never cuts the foot off one standing on a border.
    for (var c = last; c >= first; c--) {
      canvas.drawPicture(_standing.putIfAbsent(c, () => _recordStanding(c)));
    }
    _paintSails(canvas, uMin, uMax, time);
  }

  void dispose() {
    for (final p in [..._tops.values, ..._unders.values, ..._standing.values]) {
      p.dispose();
    }
    _tops.clear();
    _unders.clear();
    _standing.clear();
  }

  List<double> _us(int c) {
    final u0 = math.max(0.0, c * chunk - 2);
    final u1 = math.min(length, (c + 1) * chunk + 2);
    final out = <double>[];
    for (var u = u0; u < u1; u += 15) {
      out.add(u);
    }
    out.add(u1);
    return out;
  }

  double _ends(double u) =>
      smoothstep(0, 260, u) * smoothstep(length, length - 260, u);

  ui.Picture _recordUnder(int c) {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final us = _us(c);
    final rng = math.Random(c * 31 + sim.config.seed);
    // Earth lip just under the grass.
    final lip = Path();
    for (var i = 0; i < us.length; i++) {
      final p = iso0(us[i], sim.halfWidth(us[i]), 0);
      i == 0 ? lip.moveTo(p.dx, p.dy) : lip.lineTo(p.dx, p.dy);
    }
    for (var i = us.length - 1; i >= 0; i--) {
      final p = iso0(us[i], sim.halfWidth(us[i]), -10 * _ends(us[i]));
      lip.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(lip..close(), Paint()..color = const Color(0xFF7A5A3A));
    // Rock hanging below.
    final rock = Path();
    for (var i = 0; i < us.length; i++) {
      final p = iso0(us[i], sim.halfWidth(us[i]), -8 * _ends(us[i]));
      i == 0 ? rock.moveTo(p.dx, p.dy) : rock.lineTo(p.dx, p.dy);
    }
    final bottom = <Offset>[];
    for (var i = us.length - 1; i >= 0; i--) {
      final u = us[i];
      final jag = (math.sin(u * 0.11) + math.sin(u * 0.037)) * 12;
      bottom.add(
        iso0(
          u,
          sim.halfWidth(u) * 0.15,
          -(sim.undersideDepth(u) + jag) * _ends(u),
        ),
      );
    }
    for (final p in bottom) {
      rock.lineTo(p.dx, p.dy);
    }
    rock.close();
    final mid = iso0(c * chunk + chunk / 2, 0, 0);
    canvas.drawPath(
      rock,
      Paint()
        ..shader = ui.Gradient.linear(
          mid,
          mid + const Offset(0, 220),
          const [Palette.rockLight, Palette.rock, Palette.rockDark],
          const [0, 0.35, 1],
        ),
    );
    canvas.save();
    canvas.clipPath(rock);
    final strata = Paint()
      ..color = const Color(0x553A2A24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final f in [0.18, 0.36, 0.55, 0.74]) {
      final path = Path();
      for (var i = 0; i < us.length; i++) {
        final u = us[i];
        final hw = sim.halfWidth(u);
        final p = iso0(
          u,
          lerpDouble(hw, hw * 0.15, f),
          -sim.undersideDepth(u) * _ends(u) * f + math.sin(u * 0.05) * 3,
        );
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, strata);
    }
    // Pale rocks embedded in the face.
    for (var k = 0; k < 18; k++) {
      final u = us.first + rng.nextDouble() * (us.last - us.first);
      final f = rng.nextDouble() * 0.7;
      final hw = sim.halfWidth(u);
      final p = iso0(
        u,
        lerpDouble(hw, hw * 0.15, f),
        -sim.undersideDepth(u) * _ends(u) * f,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: p,
          width: 8 + rng.nextDouble() * 10,
          height: 4 + rng.nextDouble() * 5,
        ),
        Paint()..color = const Color(0x33F0E0D0),
      );
    }
    canvas.restore();
    // Hanging roots under the lip.
    final root = Paint()
      ..color = const Color(0xAA4A3624)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    for (var k = 0; k < 10; k++) {
      final u = us.first + rng.nextDouble() * (us.last - us.first);
      final top = iso0(u, sim.halfWidth(u), -8);
      final len = 8 + rng.nextDouble() * 22;
      canvas.drawPath(
        Path()
          ..moveTo(top.dx, top.dy)
          ..quadraticBezierTo(
            top.dx + 3,
            top.dy + len * 0.6,
            top.dx - 2,
            top.dy + len,
          ),
        root,
      );
    }
    // Waterfalls where a creek leaves the island.
    for (final creek in _creeks) {
      final end = creek.last;
      if (_chunkOf(end.dx) != c) continue;
      final u = end.dx;
      final top = iso0(u, sim.halfWidth(u), 0);
      final fall = sim.undersideDepth(u) * 1.6;
      canvas.drawRect(
        Rect.fromLTWH(top.dx - 6, top.dy, 12, fall),
        Paint()
          ..shader = ui.Gradient.linear(top, top + Offset(0, fall), const [
            Color(0xEEE6F3FF),
            Color(0x00E6F3FF),
          ]),
      );
      for (var k = 0; k < 6; k++) {
        canvas.drawCircle(
          top +
              Offset(
                (rng.nextDouble() - 0.5) * 30,
                fall * (0.5 + rng.nextDouble() * 0.5),
              ),
          10 + rng.nextDouble() * 14,
          Paint()..color = const Color(0x22FFFFFF),
        );
      }
    }
    return rec.endRecording();
  }

  Path _outline(List<double> us) {
    final top = Path();
    for (var i = 0; i < us.length; i++) {
      final p = iso0(us[i], -sim.halfWidth(us[i]), 0);
      i == 0 ? top.moveTo(p.dx, p.dy) : top.lineTo(p.dx, p.dy);
    }
    for (var i = us.length - 1; i >= 0; i--) {
      final p = iso0(us[i], sim.halfWidth(us[i]), 0);
      top.lineTo(p.dx, p.dy);
    }
    return top..close();
  }

  Path _quad(double u0, double v0, double u1, double v1) => Path()
    ..addPolygon([
      iso0(u0, v0, 0),
      iso0(u1, v0, 0),
      iso0(u1, v1, 0),
      iso0(u0, v1, 0),
    ], true);

  ui.Picture _recordTop(int c) {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final us = _us(c);
    final uLo = us.first - 120;
    final uHi = us.last + 120;
    final rng = math.Random(c * 7919 + sim.config.seed);
    final outline = _outline(us);
    canvas.drawPath(outline, Paint()..color = Palette.grass);
    canvas.save();
    canvas.clipPath(outline);

    // Grass texture.
    final light = Paint()..color = const Color(0x3389C066);
    final dark = Paint()..color = const Color(0x22355A28);
    for (var k = 0; k < 260; k++) {
      final u = us.first + rng.nextDouble() * (us.last - us.first);
      final v = (rng.nextDouble() * 2 - 1) * sim.halfWidth(u);
      canvas.drawOval(
        Rect.fromCenter(
          center: iso0(u, v, 0),
          width: 6 + rng.nextDouble() * 10,
          height: 3 + rng.nextDouble() * 4,
        ),
        k.isEven ? light : dark,
      );
    }

    for (final p in _parcels) {
      if (p.u1 < uLo || p.u0 > uHi) continue;
      _paintParcel(canvas, p, rng);
    }

    for (final creek in _creeks) {
      final path = Path();
      for (var i = 0; i < creek.length; i++) {
        final p = iso0(creek[i].dx, creek[i].dy, 0);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF5C7A3E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 17
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF5FA3CF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 11
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0x88CFEAFA)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    // The road with wheel ruts and a bridge over each creek.
    final road = Path();
    var started = false;
    for (final u in us) {
      if (sim.halfWidth(u) < 50) continue;
      final p = iso0(u, _road(u), 0);
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
        ..color = const Color(0xFFB8956A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18,
    );
    canvas.drawPath(
      road,
      Paint()
        ..color = const Color(0xFFD0B184)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13,
    );
    for (final off in [-3.5, 3.5]) {
      final rut = Path();
      var s2 = false;
      for (final u in us) {
        if (sim.halfWidth(u) < 50) continue;
        final p = iso0(u, _road(u) + off, 0);
        if (!s2) {
          rut.moveTo(p.dx, p.dy);
          s2 = true;
        } else {
          rut.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        rut,
        Paint()
          ..color = const Color(0x55755A3A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    for (final creek in _creeks) {
      for (var i = 1; i < creek.length; i++) {
        final a = creek[i - 1];
        final b = creek[i];
        final ra = _road(a.dx);
        if ((a.dy - ra) * (b.dy - _road(b.dx)) <= 0 &&
            a.dx >= us.first &&
            a.dx <= us.last) {
          final u = a.dx;
          canvas.drawPath(
            _quad(u - 10, ra - 13, u + 10, ra + 13),
            Paint()..color = Palette.wood,
          );
          for (var k = -9.0; k <= 9; k += 4.5) {
            canvas.drawLine(
              iso0(u + k, ra - 13, 0),
              iso0(u + k, ra + 13, 0),
              Paint()
                ..color = Palette.woodDark
                ..strokeWidth = 1,
            );
          }
        }
      }
    }

    // Hedges and stone walls.
    for (final (a, b, hedge) in _borders) {
      if (math.max(a.dx, b.dx) < uLo || math.min(a.dx, b.dx) > uHi) continue;
      final pa = iso0(a.dx, a.dy, 0);
      final pb = iso0(b.dx, b.dy, 0);
      if (hedge) {
        canvas.drawLine(
          pa,
          pb,
          Paint()
            ..color = Palette.grassDark
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round,
        );
        final n = ((pb - pa).distance / 9).floor();
        for (var k = 0; k <= n; k++) {
          final p =
              Offset.lerp(pa, pb, n == 0 ? 0 : k / n)! - const Offset(0, 2);
          canvas.drawCircle(p, 3.6, Paint()..color = const Color(0xFF4A7A38));
          canvas.drawCircle(
            p - const Offset(1, 1.2),
            1.8,
            Paint()..color = const Color(0xFF6E9F55),
          );
        }
      } else {
        canvas.drawLine(
          pa,
          pb,
          Paint()
            ..color = const Color(0xFF8E8A80)
            ..strokeWidth = 3.5,
        );
        final n = ((pb - pa).distance / 6).floor();
        for (var k = 0; k <= n; k++) {
          canvas.drawCircle(
            Offset.lerp(pa, pb, n == 0 ? 0 : k / n)! - const Offset(0, 1),
            1.6,
            Paint()..color = const Color(0xFFBDB7A8),
          );
        }
      }
    }
    canvas.restore();

    // Front edge highlight.
    final edge = Path();
    for (var i = 0; i < us.length; i++) {
      final p = iso0(us[i], sim.halfWidth(us[i]), 0);
      i == 0 ? edge.moveTo(p.dx, p.dy) : edge.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      edge,
      Paint()
        ..color = Palette.grassDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Docks for the moored skiffs.
    for (final (u, len) in sim.docks) {
      if (u < us.first || u > us.last) continue;
      _paintDock(canvas, u, sim.halfWidth(u), len);
    }

    return rec.endRecording();
  }

  ui.Picture _recordStanding(int c) {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final u0 = c * chunk;
    // Far to near.
    for (final p in _props) {
      if (p.u < u0 || p.u >= u0 + chunk) continue;
      _paintProp(canvas, p);
    }
    return rec.endRecording();
  }

  void _paintParcel(Canvas canvas, _Parcel p, math.Random rng) {
    final (fill, line, along) = switch (p.crop) {
      _Crop.wheat => (const Color(0xFFD9C26B), const Color(0x44A07A30), true),
      _Crop.ploughed => (
        const Color(0xFF9A7046),
        const Color(0x66603E22),
        false,
      ),
      _Crop.rows => (const Color(0xFF5E9A48), const Color(0x449CD07A), true),
      _Crop.meadow => (const Color(0xFF8DBE62), const Color(0x00000000), true),
      _Crop.lavender => (
        const Color(0xFF8E7FBF),
        const Color(0x55C9B8F0),
        false,
      ),
    };
    canvas.drawPath(_quad(p.u0, p.v0, p.u1, p.v1), Paint()..color = fill);
    final paint = Paint()
      ..color = line
      ..strokeWidth = 1.3;
    if (along) {
      for (var v = p.v0 + 5; v < p.v1; v += 7) {
        canvas.drawLine(iso0(p.u0, v, 0), iso0(p.u1, v, 0), paint);
      }
    } else {
      for (var u = p.u0 + 5; u < p.u1; u += 7) {
        canvas.drawLine(iso0(u, p.v0, 0), iso0(u, p.v1, 0), paint);
      }
    }
    if (p.crop == _Crop.meadow) {
      for (var k = 0; k < 14; k++) {
        final u = p.u0 + rng.nextDouble() * (p.u1 - p.u0);
        final v = p.v0 + rng.nextDouble() * (p.v1 - p.v0);
        canvas.drawCircle(
          iso0(u, v, 0),
          1.3,
          Paint()
            ..color = k.isEven
                ? const Color(0xFFFFF4C2)
                : const Color(0xFFE88AA0),
        );
      }
    }
  }

  void _shadow(Canvas canvas, double u, double v, double r) {
    canvas.drawOval(
      Rect.fromCenter(
        center: iso0(u + 2, v + r * 0.6, 0),
        width: r * 2.6,
        height: r * 1.2,
      ),
      Paint()..color = const Color(0x33000000),
    );
  }

  void _box(
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
    Offset p(double du, double dv, double z) => iso0(u + du, v + dv, z);
    canvas.drawPath(
      Path()
        ..addPolygon([p(-a, b, 0), p(a, b, 0), p(a, b, h), p(-a, b, h)], true),
      Paint()..color = front,
    );
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

  static const _roofs = [
    Color(0xFFB2583C),
    Color(0xFF8C5A3C),
    Color(0xFF5E6E86),
    Color(0xFFA4473A),
  ];
  static const _greens = [
    Color(0xFF4F7A3E),
    Color(0xFF5C8A44),
    Color(0xFF466F3A),
    Color(0xFF6A9448),
  ];

  void _paintProp(Canvas canvas, _Prop p) {
    final s = p.size;
    switch (p.kind) {
      case _PropKind.tree:
        _shadow(canvas, p.u, p.v, 9 * s);
        canvas.drawLine(
          iso0(p.u, p.v, 0),
          iso0(p.u, p.v, 12 * s),
          Paint()
            ..color = Palette.woodDark
            ..strokeWidth = 2.6 * s,
        );
        final g = _greens[p.tint];
        canvas.drawCircle(iso0(p.u, p.v, 17 * s), 9 * s, Paint()..color = g);
        canvas.drawCircle(
          iso0(p.u - 3, p.v + 2, 14 * s),
          6.5 * s,
          Paint()..color = Color.lerp(g, const Color(0xFF000000), 0.15)!,
        );
        canvas.drawCircle(
          iso0(p.u + 1, p.v - 2, 21 * s),
          5 * s,
          Paint()..color = Color.lerp(g, const Color(0xFFFFFFFF), 0.18)!,
        );
      case _PropKind.blossom:
        _shadow(canvas, p.u, p.v, 8 * s);
        canvas.drawLine(
          iso0(p.u, p.v, 0),
          iso0(p.u, p.v, 11 * s),
          Paint()
            ..color = Palette.woodDark
            ..strokeWidth = 2.4 * s,
        );
        canvas.drawCircle(
          iso0(p.u, p.v, 16 * s),
          8.5 * s,
          Paint()..color = const Color(0xFFE7A6B8),
        );
        canvas.drawCircle(
          iso0(p.u + 1, p.v - 2, 19 * s),
          4.5 * s,
          Paint()..color = const Color(0xFFF6D3DC),
        );
      case _PropKind.pine:
        _shadow(canvas, p.u, p.v, 7 * s);
        for (var k = 0; k < 3; k++) {
          final base = iso0(p.u, p.v, (4 + k * 7) * s);
          final w = (9 - k * 2.2) * s;
          canvas.drawPath(
            Path()
              ..moveTo(base.dx - w, base.dy)
              ..lineTo(base.dx, base.dy - 12 * s)
              ..lineTo(base.dx + w, base.dy)
              ..close(),
            Paint()
              ..color = k.isEven
                  ? const Color(0xFF2F5A34)
                  : const Color(0xFF3A6A3E),
          );
        }
      case _PropKind.house:
        _shadow(canvas, p.u + 4, p.v + 4, 12 * s);
        _house(canvas, p.u, p.v, 13 * s, 9 * s, 10 * s, _roofs[p.tint]);
      case _PropKind.haystack:
        _shadow(canvas, p.u, p.v, 7 * s);
        final c = iso0(p.u, p.v, 5 * s);
        canvas.drawOval(
          Rect.fromCenter(center: c, width: 16 * s, height: 13 * s),
          Paint()..color = const Color(0xFFD8B65A),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: c - Offset(2 * s, 3 * s),
            width: 8 * s,
            height: 5 * s,
          ),
          Paint()..color = const Color(0xFFEDD58A),
        );
      case _PropKind.well:
        _box(
          canvas,
          p.u,
          p.v,
          5,
          5,
          6,
          const Color(0xFF3F5E78),
          const Color(0xFF9A958A),
          const Color(0xFF7D786E),
        );
        canvas.drawLine(
          iso0(p.u - 4, p.v, 6),
          iso0(p.u - 4, p.v, 16),
          Paint()
            ..color = Palette.woodDark
            ..strokeWidth = 1.5,
        );
        canvas.drawLine(
          iso0(p.u + 4, p.v, 6),
          iso0(p.u + 4, p.v, 16),
          Paint()
            ..color = Palette.woodDark
            ..strokeWidth = 1.5,
        );
        canvas.drawLine(
          iso0(p.u - 6, p.v, 17),
          iso0(p.u + 6, p.v, 17),
          Paint()
            ..color = const Color(0xFF8C5A3C)
            ..strokeWidth = 4,
        );
      case _PropKind.boulder:
        final c = iso0(p.u, p.v, 3);
        canvas.drawOval(
          Rect.fromCenter(
            center: c + const Offset(2, 3),
            width: 18 * s,
            height: 9 * s,
          ),
          Paint()..color = const Color(0x33000000),
        );
        canvas.drawOval(
          Rect.fromCenter(center: c, width: 16 * s, height: 10 * s),
          Paint()..color = Palette.rockLight,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: c - Offset(2 * s, 2 * s),
            width: 7 * s,
            height: 4 * s,
          ),
          Paint()..color = const Color(0x44FFFFFF),
        );
      case _PropKind.crates:
        _box(
          canvas,
          p.u,
          p.v,
          6,
          6,
          8,
          const Color(0xFFC08A52),
          const Color(0xFF9A6A3A),
          const Color(0xFF7C5430),
        );
        _box(
          canvas,
          p.u + 9,
          p.v + 3,
          5,
          5,
          6,
          const Color(0xFFB27E4A),
          const Color(0xFF8E6034),
          const Color(0xFF70502C),
        );
      case _PropKind.mill:
        _shadow(canvas, p.u + 6, p.v + 6, 14);
        final base = iso0(p.u, p.v, 0);
        final top = iso0(p.u, p.v, 40);
        canvas.drawPath(
          Path()
            ..moveTo(base.dx - 10, base.dy)
            ..lineTo(top.dx - 6, top.dy)
            ..lineTo(top.dx + 6, top.dy)
            ..lineTo(base.dx + 10, base.dy)
            ..close(),
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(base.dx - 10, 0),
              Offset(base.dx + 10, 0),
              const [Color(0xFFD8CDB4), Color(0xFFF0E8D6), Color(0xFFB9AE96)],
              const [0, 0.4, 1],
            ),
        );
        canvas.drawRect(
          Rect.fromCenter(
            center: base - const Offset(0, 6),
            width: 5,
            height: 9,
          ),
          Paint()..color = Palette.woodDark,
        );
        canvas.drawPath(
          Path()
            ..moveTo(top.dx - 8, top.dy + 1)
            ..lineTo(top.dx, top.dy - 9)
            ..lineTo(top.dx + 8, top.dy + 1)
            ..close(),
          Paint()..color = const Color(0xFF8C5A3C),
        );
    }
  }

  void _house(
    Canvas canvas,
    double u,
    double v,
    double a,
    double b,
    double h,
    Color roof,
  ) {
    Offset p(double du, double dv, double z) => iso0(u + du, v + dv, z);
    const wall = Color(0xFFE9DEC4);
    const wallShade = Color(0xFFC9BC9E);
    final rh = b * 0.9;
    // Back roof slope first (mostly hidden).
    canvas.drawPath(
      Path()..addPolygon([
        p(-a, -b, h),
        p(a, -b, h),
        p(a, 0, h + rh),
        p(-a, 0, h + rh),
      ], true),
      Paint()..color = Color.lerp(roof, const Color(0xFF000000), 0.35)!,
    );
    canvas.drawPath(
      Path()
        ..addPolygon([p(-a, b, 0), p(a, b, 0), p(a, b, h), p(-a, b, h)], true),
      Paint()..color = wall,
    );
    canvas.drawPath(
      Path()..addPolygon([
        p(-a, -b, 0),
        p(-a, b, 0),
        p(-a, b, h),
        p(-a, -b, h),
      ], true),
      Paint()..color = wallShade,
    );
    canvas.drawPath(
      Path()..addPolygon([p(-a, -b, h), p(-a, b, h), p(-a, 0, h + rh)], true),
      Paint()..color = wallShade,
    );
    canvas.drawPath(
      Path()..addPolygon([
        p(-a, b, h),
        p(a, b, h),
        p(a, 0, h + rh),
        p(-a, 0, h + rh),
      ], true),
      Paint()..color = roof,
    );
    // Door and windows on the front.
    canvas.drawPath(
      Path()
        ..addPolygon([p(-2, b, 0), p(2, b, 0), p(2, b, 6), p(-2, b, 6)], true),
      Paint()..color = Palette.woodDark,
    );
    for (final du in [-a * 0.6, a * 0.6]) {
      canvas.drawPath(
        Path()..addPolygon([
          p(du - 1.6, b, 4),
          p(du + 1.6, b, 4),
          p(du + 1.6, b, 7.5),
          p(du - 1.6, b, 7.5),
        ], true),
        Paint()..color = const Color(0xFF4A6A88),
      );
    }
    // Chimney.
    final ch = p(a * 0.5, -b * 0.2, h + rh * 0.8);
    canvas.drawRect(
      Rect.fromLTWH(ch.dx - 2, ch.dy - 7, 4, 7),
      Paint()..color = const Color(0xFF8A6E5A),
    );
  }

  void _paintDock(Canvas canvas, double u, double hw, double len) {
    canvas.drawPath(
      Path()..addPolygon([
        iso0(u - 8, hw - 10, 0),
        iso0(u + 8, hw - 10, 0),
        iso0(u + 8, hw + len, 0),
        iso0(u - 8, hw + len, 0),
      ], true),
      Paint()..color = Palette.wood,
    );
    final edge = Paint()
      ..color = Palette.woodDark
      ..strokeWidth = 1.2;
    for (var k = 0.0; k < len; k += 9) {
      canvas.drawLine(iso0(u - 8, hw + k, 0), iso0(u + 8, hw + k, 0), edge);
    }
    for (final k in [len * 0.5, len]) {
      canvas.drawLine(
        iso0(u + 8, hw + k, 0),
        iso0(u + 8, hw + k, -26),
        Paint()
          ..color = Palette.woodDark
          ..strokeWidth = 2.5,
      );
    }
    // Rope coil and a lantern post.
    canvas.drawCircle(
      iso0(u - 4, hw + len - 4, 1),
      2.5,
      Paint()..color = const Color(0xFFCDB487),
    );
    canvas.drawLine(
      iso0(u - 7, hw + 4, 0),
      iso0(u - 7, hw + 4, 14),
      Paint()
        ..color = Palette.woodDark
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(
      iso0(u - 7, hw + 4, 15),
      2,
      Paint()..color = const Color(0xFFFFD27A),
    );
  }

  void _paintSails(Canvas canvas, double uMin, double uMax, double time) {
    for (final p in _props) {
      if (p.kind != _PropKind.mill || p.u < uMin || p.u > uMax) continue;
      final hub = iso0(p.u + 4, p.v + 4, 36);
      final sail = Paint()..color = const Color(0xFFEDE3CC);
      final spar = Paint()
        ..color = Palette.woodDark
        ..strokeWidth = 1.4;
      for (var k = 0; k < 4; k++) {
        final a = time * 1.6 + k * math.pi / 2;
        final d = Offset(math.cos(a), math.sin(a) * 0.8);
        final n = Offset(-d.dy, d.dx);
        final tip = hub + d * 26;
        canvas.drawLine(hub, tip, spar);
        canvas.drawPath(
          Path()..addPolygon([
            hub + d * 6,
            tip,
            tip + n * 6,
            hub + d * 6 + n * 5,
          ], true),
          sail,
        );
      }
      canvas.drawCircle(hub, 2.2, Paint()..color = Palette.woodDark);
    }
  }
}
