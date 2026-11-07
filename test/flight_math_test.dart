import 'dart:math' as math;

import 'package:bulut_korsanlari/core/v3.dart';
import 'package:bulut_korsanlari/game/dogfight/camera3.dart';
import 'package:bulut_korsanlari/game/dogfight/dogfight_sim.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('V3', () {
    test('fromAngles points along +z at zero and turns right with yaw', () {
      final f = V3.fromAngles(0, 0);
      expect(f.z, closeTo(1, 1e-9));
      final right = V3.fromAngles(math.pi / 2, 0);
      expect(right.x, closeTo(1, 1e-9));
      final up = V3.fromAngles(0, math.pi / 2);
      expect(up.y, closeTo(1, 1e-9));
    });

    test('segment distance catches a bullet that passes between frames', () {
      final a = V3(-100, 0, 0);
      final b = V3(100, 0, 0);
      expect(segmentPointDistance(a, b, V3(0, 5, 0)), closeTo(5, 1e-9));
      // Both end points are far, the closest approach is not.
      expect(a.distanceTo(V3(0, 5, 0)), greaterThan(50));
      expect(segmentPointDistance(a, b, V3(150, 0, 0)), closeTo(50, 1e-9));
    });

    test('wrap helpers', () {
      expect(wrapAngle(3 * math.pi), closeTo(math.pi, 1e-9));
      expect(wrapAngle(-3 * math.pi / 2), closeTo(math.pi / 2, 1e-9));
      expect(wrapCentered(2600, 2500), closeTo(-2400, 1e-9));
      expect(wrapCentered(-2600, 2500), closeTo(2400, 1e-9));
    });
  });

  group('Flyer basis', () {
    test('is orthonormal with roll applied', () {
      final f = Flyer(pos: V3.zero(), yaw: 0.7, pitch: 0.3)..roll = 0.5;
      final (r, u, fw) = f.basis();
      expect(r.length, closeTo(1, 1e-9));
      expect(u.length, closeTo(1, 1e-9));
      expect(fw.length, closeTo(1, 1e-9));
      expect(r.dot(u), closeTo(0, 1e-9));
      expect(r.dot(fw), closeTo(0, 1e-9));
      expect(u.dot(fw), closeTo(0, 1e-9));
    });

    test('banking right drops the right wing', () {
      final f = Flyer(pos: V3.zero())..roll = 0.6;
      final (r, _, _) = f.basis();
      expect(r.y, lessThan(0));
    });
  });

  group('Camera3', () {
    Camera3 cam({double yaw = 0, double pitch = 0, double roll = 0}) {
      final f = Flyer(pos: V3(0, 1000, 0), yaw: yaw, pitch: pitch)..roll = roll;
      return Camera3.follow(f, width: 800, height: 400, rollFactor: 1);
    }

    test('a point dead ahead lands on the screen centre', () {
      final c = cam(yaw: 0.4);
      final p = c.project(V3(0, 1000, 0) + V3.fromAngles(0.4, 0) * 500)!;
      expect(p.x, closeTo(c.cx, 1e-6));
      expect(p.y, closeTo(c.cy, 1e-6));
      expect(p.depth, closeTo(500, 1e-6));
    });

    test('right is right, up is up, behind is hidden', () {
      final c = cam();
      expect(c.project(V3(100, 1000, 500))!.x, greaterThan(c.cx));
      expect(c.project(V3(0, 1100, 500))!.y, lessThan(c.cy));
      expect(c.project(V3(0, 1000, -500)), isNull);
    });

    test('the horizon moves down the screen as the nose comes up', () {
      expect(cam(pitch: 0.3).horizonOffset, greaterThan(0));
      expect(cam(pitch: -0.3).horizonOffset, lessThan(0));
      expect(cam().horizonOffset, closeTo(0, 1e-9));
    });

    test('closer things are drawn bigger', () {
      final c = cam();
      final near = c.project(V3(0, 1000, 200))!;
      final far = c.project(V3(0, 1000, 800))!;
      expect(near.scale, greaterThan(far.scale));
    });
  });
}
