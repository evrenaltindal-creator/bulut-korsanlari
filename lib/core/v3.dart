import 'dart:math' as math;

/// Small mutable 3D vector used by the simulations.
///
/// The simulations are plain Dart (no Flutter, no Flame) so they can be
/// stepped and checked in unit tests.
class V3 {
  V3(this.x, this.y, this.z);
  V3.zero() : x = 0, y = 0, z = 0;

  /// Unit vector pointing along [yaw] (0 = +z, positive turns towards +x)
  /// and [pitch] (positive is up).
  factory V3.fromAngles(double yaw, double pitch) {
    final cp = math.cos(pitch);
    return V3(math.sin(yaw) * cp, math.sin(pitch), math.cos(yaw) * cp);
  }

  double x;
  double y;
  double z;

  V3 copy() => V3(x, y, z);

  V3 operator +(V3 o) => V3(x + o.x, y + o.y, z + o.z);
  V3 operator -(V3 o) => V3(x - o.x, y - o.y, z - o.z);
  V3 operator *(double s) => V3(x * s, y * s, z * s);
  V3 operator -() => V3(-x, -y, -z);

  double dot(V3 o) => x * o.x + y * o.y + z * o.z;

  V3 cross(V3 o) => V3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);

  double get length => math.sqrt(x * x + y * y + z * z);
  double get length2 => x * x + y * y + z * z;

  V3 normalized() {
    final l = length;
    return l == 0 ? V3.zero() : this * (1 / l);
  }

  void addScaled(V3 o, double s) {
    x += o.x * s;
    y += o.y * s;
    z += o.z * s;
  }

  void setFrom(V3 o) {
    x = o.x;
    y = o.y;
    z = o.z;
  }

  double distanceTo(V3 o) => (this - o).length;

  @override
  String toString() =>
      'V3(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)}, '
      '${z.toStringAsFixed(1)})';
}

/// Shortest distance between point [p] and the segment [a]-[b].
///
/// Bullets move fast; testing only their end position would let them
/// tunnel through a target between two frames.
double segmentPointDistance(V3 a, V3 b, V3 p) {
  final ab = b - a;
  final len2 = ab.length2;
  if (len2 == 0) return p.distanceTo(a);
  final t = ((p - a).dot(ab) / len2).clamp(0.0, 1.0);
  return p.distanceTo(a + ab * t);
}

/// Wraps an angle to (-pi, pi].
double wrapAngle(double a) {
  var r = a % (2 * math.pi);
  if (r > math.pi) r -= 2 * math.pi;
  if (r <= -math.pi) r += 2 * math.pi;
  return r;
}

/// Wraps [value] into [-half, half).
double wrapCentered(double value, double half) {
  final span = half * 2;
  return ((value + half) % span + span) % span - half;
}

double lerpDouble(double a, double b, double t) => a + (b - a) * t;

double smoothstep(double edge0, double edge1, double x) {
  final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// A random unit vector.
V3 randomUnit(math.Random rng) {
  final yaw = rng.nextDouble() * math.pi * 2;
  final pitch = math.asin(rng.nextDouble() * 2 - 1);
  return V3.fromAngles(yaw, pitch);
}
