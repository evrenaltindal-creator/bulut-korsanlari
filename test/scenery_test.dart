import 'dart:ui' as ui;

import 'package:bulut_korsanlari/campaign/missions.dart';
import 'package:bulut_korsanlari/core/controls.dart';
import 'package:bulut_korsanlari/game/bombing/bombing_painter.dart';
import 'package:bulut_korsanlari/game/bombing/bombing_sim.dart';
import 'package:bulut_korsanlari/game/bombing/bombing_terrain.dart';
import 'package:bulut_korsanlari/game/dogfight/dogfight_painter.dart';
import 'package:bulut_korsanlari/game/dogfight/dogfight_sim.dart';
import 'package:bulut_korsanlari/game/paint_kit.dart';
import 'package:bulut_korsanlari/game/raid/raid_painter.dart';
import 'package:bulut_korsanlari/game/raid/raid_sim.dart';
import 'package:bulut_korsanlari/game/raid/raid_terrain.dart';
import 'package:bulut_korsanlari/l10n/strings.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

final tr = const AppStrings('tr').t;
const size = Size(844, 390);

/// Paints [draw] into a throwaway picture; any painting error throws.
void record(void Function(Canvas canvas) draw) {
  final rec = ui.PictureRecorder();
  draw(Canvas(rec));
  rec.endRecording().dispose();
}

void main() {
  test('every raid island draws end to end, props clear of targets', () {
    for (final m in campaignMissions.where((m) => m.raid != null)) {
      final sim = RaidSim(config: m.raid!);
      final terrain = RaidTerrain(sim);
      record((c) => terrain.paint(c, -500, sim.config.length + 500, 3));
      for (final p in terrain.propPositions) {
        for (final t in sim.targets) {
          expect(
            (p - Offset(t.u, t.v)).distance,
            greaterThan(25),
            reason: '${m.id} prop on a target',
          );
        }
      }
      terrain.dispose();
    }
  });

  test('every bombing base draws end to end, buildings clear of targets', () {
    for (final m in campaignMissions.where((m) => m.bombing != null)) {
      final sim = BombingSim(config: m.bombing!);
      final terrain = BombingTerrain(sim);
      record((c) => terrain.paint(c, -400, sim.config.length + 400));
      for (final r in terrain.footprints) {
        for (final t in sim.targets.where(
          (t) => t.kind != BombTargetKind.airship,
        )) {
          final (ex, ey) = BombTarget.extent(t.kind);
          final target = Rect.fromCenter(
            center: Offset(t.x, t.y),
            width: ex * 2,
            height: ey * 2,
          );
          expect(
            r.overlaps(target),
            isFalse,
            reason: '${m.id} building on a target',
          );
        }
      }
      terrain.dispose();
    }
  });

  test('whole missions paint in every state without errors', () {
    final c = ControlState()..fire = true;
    for (final m in campaignMissions) {
      switch (m.kind) {
        case MissionKind.dogfight:
          final sim = DogfightSim(config: m.dogfight!);
          final painter = DogfightPainter(sim, tr);
          for (var i = 0; i < 240; i++) {
            sim.update(1 / 30, c..stickX = (i % 60 < 30 ? 1 : -1));
            if (i % 40 == 0) {
              record((cv) => painter.paint(cv, size, const EdgeInsetsLike()));
            }
          }
          sim.damagePlayer(0.8); // smoke, holes, warnings
          record((cv) => painter.paint(cv, size, const EdgeInsetsLike()));
          sim.damagePlayer(1); // going down
          sim.update(0.5, c);
          record((cv) => painter.paint(cv, size, const EdgeInsetsLike()));
        case MissionKind.raid:
          final sim = RaidSim(config: m.raid!);
          final painter = RaidPainter(sim, tr);
          for (var i = 0; i < 900 && sim.result == null; i++) {
            sim.update(1 / 30, c);
            if (i % 60 == 0) {
              record((cv) => painter.paint(cv, size, const EdgeInsetsLike()));
            }
          }
        case MissionKind.bombing:
          final sim = BombingSim(config: m.bombing!);
          final painter = BombingPainter(sim, tr);
          for (var i = 0; i < 900 && sim.result == null; i++) {
            sim.update(1 / 30, c..drop = i % 15 == 0);
            if (i % 60 == 0) {
              record((cv) => painter.paint(cv, size, const EdgeInsetsLike()));
            }
          }
      }
    }
  });
}
