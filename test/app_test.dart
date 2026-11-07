import 'package:bulut_korsanlari/campaign/missions.dart';
import 'package:bulut_korsanlari/campaign/store.dart';
import 'package:bulut_korsanlari/game/bombing/bombing_sim.dart';
import 'package:bulut_korsanlari/game/mission_result.dart';
import 'package:bulut_korsanlari/l10n/strings.dart';
import 'package:bulut_korsanlari/main.dart';
import 'package:bulut_korsanlari/ui/mission_screen.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> frames(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<GameStore> freshStore({String lang = 'tr'}) async {
  SharedPreferences.setMockInitialValues({});
  return GameStore.load(deviceLang: lang);
}

void main() {
  /// A phone held sideways.
  Future<void> landscape(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 740);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  testWidgets('title screen, new campaign, logbook', (tester) async {
    await landscape(tester);
    final store = await freshStore();
    await tester.pumpWidget(CloudCorsairsApp(store: store));
    await frames(tester, 3);
    expect(find.text('Bulut Korsanları'), findsOneWidget);
    expect(find.text('Devam et'), findsNothing);

    await tester.tap(find.text('Yeni sefer'));
    await frames(tester, 30);
    expect(find.text('Esinti Takımadası'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Deniz Kaya');
    await tester.ensureVisible(find.text('Filoya katıl'));
    await tester.tap(find.text('Filoya katıl'));
    await frames(tester, 30);

    expect(store.campaign?.activePilot.name, 'Deniz Kaya');
    expect(find.text('Meyve Bahçeleri Üstünde'), findsOneWidget);
    expect(find.text('Uçuşa çık'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching language changes the menu', (tester) async {
    await landscape(tester);
    final store = await freshStore();
    await tester.pumpWidget(CloudCorsairsApp(store: store));
    await frames(tester, 3);
    await store.setLang('en');
    await frames(tester, 3);
    expect(find.text('Cloud Corsairs'), findsOneWidget);
    expect(find.text('New campaign'), findsOneWidget);
  });

  testWidgets('abandoning a mission leads to the debriefing', (tester) async {
    await landscape(tester);
    final store = await freshStore();
    await store.startCampaign('Ece');
    await tester.pumpWidget(CloudCorsairsApp(store: store));
    await frames(tester, 3);
    await tester.tap(find.text('Devam et'));
    await frames(tester, 30);
    await tester.ensureVisible(find.text('Uçuşa çık'));
    await tester.tap(find.text('Uçuşa çık'));
    await frames(tester, 40);
    expect(find.byIcon(Icons.pause), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause));
    await frames(tester, 3);
    await tester.tap(find.text('Görevi bırak'));
    await frames(tester, 40);
    expect(find.text('Hedef tutturulamadı'), findsOneWidget);
    expect(store.campaign!.missionIndex, 0);
    expect(store.campaign!.log.single.missionId, 'm1');

    await tester.tap(find.text('Devam'));
    await frames(tester, 30);
    expect(find.text('Bu görev yeniden deneniyor.'), findsOneWidget);
  });

  for (final kind in MissionKind.values) {
    testWidgets('${kind.name}: the game runs and the touch controls reach it', (
      tester,
    ) async {
      await landscape(tester);
      final mission = campaignMissions.firstWhere((m) => m.kind == kind);
      MissionResult? finished;
      final game = createMissionGame(
        mission,
        skills: const PilotSkills(),
        tr: const AppStrings('tr').t,
        onFinished: (r) => finished = r,
      );
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await frames(tester, 60);
      expect(game.sim.time, greaterThan(0.5));
      expect(tester.takeException(), isNull);

      final size = tester.view.physicalSize / tester.view.devicePixelRatio;

      // Thumb on the left half, slide right: the stick reports right.
      final stick = await tester.startGesture(
        Offset(size.width * 0.2, size.height * 0.6),
      );
      await frames(tester, 2);
      await stick.moveBy(const Offset(50, 0));
      await frames(tester, 2);
      expect(game.controls.stickX, greaterThan(0.5));

      // Second finger on the right half: fire (or drop) while steering.
      final fire = await tester.startGesture(
        Offset(size.width * 0.8, size.height * 0.6),
      );
      await frames(tester, 20);
      if (kind == MissionKind.bombing) {
        final sim = game.sim as BombingSim;
        expect(sim.bombsLeft, lessThan(mission.bombing!.bombs));
      } else {
        expect(game.controls.fire, isTrue);
      }
      await fire.up();
      await stick.up();
      await frames(tester, 2);
      expect(game.controls.fire, isFalse);
      expect(game.controls.stickX, 0);
      expect(finished, isNull);
      expect(tester.takeException(), isNull);
    });
  }
}
