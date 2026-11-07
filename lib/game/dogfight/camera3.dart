import 'dart:math' as math;

import '../../core/v3.dart';
import 'dogfight_sim.dart';

class Projected {
  const Projected(this.x, this.y, this.scale, this.depth);

  final double x;
  final double y;

  /// Screen pixels per world unit at this depth.
  final double scale;
  final double depth;
}

/// Perspective camera sitting at the player's position.
class Camera3 {
  Camera3({
    required this.pos,
    required this.right,
    required this.up,
    required this.fwd,
    required this.cx,
    required this.cy,
    required this.focal,
    required this.roll,
    required this.pitch,
  });

  /// The camera rolls with the plane only partly ([rollFactor]); the rest
  /// of the bank is shown by tilting the player's own plane.
  factory Camera3.follow(
    Flyer f, {
    required double width,
    required double height,
    double rollFactor = 0.7,
  }) {
    final (r, u, fw) = f.basis(rollFactor);
    return Camera3(
      pos: f.pos,
      right: r,
      up: u,
      fwd: fw,
      cx: width / 2,
      cy: height * 0.46,
      focal: math.max(width, height) * 0.78,
      roll: f.roll * rollFactor,
      pitch: f.pitch,
    );
  }

  static const double near = 4;

  final V3 pos;
  final V3 right;
  final V3 up;
  final V3 fwd;
  final double cx;
  final double cy;
  final double focal;
  final double roll;
  final double pitch;

  /// Camera-space coordinates: x right, y up, z forward (depth).
  V3 toCamera(V3 p) {
    final rel = p - pos;
    return V3(rel.dot(right), rel.dot(up), rel.dot(fwd));
  }

  Projected? project(V3 p) {
    final c = toCamera(p);
    if (c.z < near) return null;
    return Projected(
      cx + c.x / c.z * focal,
      cy - c.y / c.z * focal,
      focal / c.z,
      c.z,
    );
  }

  /// Projects a direction at infinity (the sun).
  Projected? projectDir(V3 d) {
    final z = d.dot(fwd);
    if (z <= 0.01) return null;
    return Projected(
      cx + d.dot(right) / z * focal,
      cy - d.dot(up) / z * focal,
      0,
      double.infinity,
    );
  }

  /// Vertical offset of the horizon from [cy] in the camera's unrolled
  /// frame. Pitching up moves the horizon down the screen.
  double get horizonOffset => focal * math.tan(pitch.clamp(-1.3, 1.3));
}
