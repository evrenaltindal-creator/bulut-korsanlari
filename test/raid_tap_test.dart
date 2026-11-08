import 'package:bulut_korsanlari/campaign/missions.dart';
import 'package:bulut_korsanlari/game/mission_game.dart';
import 'package:bulut_korsanlari/game/raid/raid_sim.dart';
import 'package:bulut_korsanlari/l10n/strings.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late RaidGame game;

  Future<void> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 740);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final m = campaignMissions.firstWhere((m) => m.kind == MissionKind.raid);
    game = RaidGame(
      config: m.raid!,
      tr: const AppStrings('tr').t,
      onFinished: (_) {},
    );
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    // Fly on until the island and its first targets are in view.
    for (var i = 0; i < 6 * 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (_onScreen(game).isNotEmpty) break;
    }
  }

  testWidgets('tapping a target on screen marks it', (tester) async {
    await start(tester);
    final targets = _onScreen(game);
    expect(targets, isNotEmpty);
    final t = targets.first;
    await tester.tapAt(game.painter.screenOf(t));
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.sim.marked, t);
    expect(game.sim.everMarked, isTrue);
    expect(game.controls.fire, isFalse, reason: 'a mark is not a shot');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a tap on the stick half marks too, a slide steers', (
    tester,
  ) async {
    await start(tester);
    // Wait for a target on the left (stick) half of the screen.
    List<RaidTarget> left() =>
        _onScreen(game)
            .where((t) => game.painter.screenOf(t).dx < 360)
            .toList();
    for (var i = 0; i < 10 * 60 && left().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(left(), isNotEmpty);
    final t = left().first;
    await tester.tapAt(game.painter.screenOf(t));
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.sim.marked, t);
    expect(game.controls.stickX, 0);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('holding on empty sky still fires by hand', (tester) async {
    await start(tester);
    // A spot on the right half with no target anywhere near the finger.
    final spots = [
      for (var x = 420.0; x < 790; x += 20)
        for (var y = 20.0; y < 360; y += 20) Offset(x, y),
    ];
    final empty = spots.firstWhere(
      (p) => game.sim.targets.every(
        (t) => (game.painter.screenOf(t) - p).distance > 120,
      ),
    );
    final finger = await tester.startGesture(empty);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.controls.fire, isTrue);
    expect(game.sim.marked, isNull);
    await finger.up();
    await tester.pump(const Duration(seconds: 1));
  });
}

/// Markable targets whose screen position is well inside the view.
List<RaidTarget> _onScreen(RaidGame game) {
  final view = Rect.fromLTWH(60, 60, game.size.x - 120, game.size.y - 120);
  return [
    for (final t in game.sim.targets)
      if (game.sim.canMark(t) && view.contains(game.painter.screenOf(t))) t,
  ];
}
