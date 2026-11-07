import 'package:bulut_korsanlari/audio/music.dart';
import 'package:bulut_korsanlari/campaign/missions.dart';
import 'package:bulut_korsanlari/campaign/characters.dart';
import 'package:bulut_korsanlari/ui/art.dart';
import 'package:bulut_korsanlari/ui/debrief_screen.dart';
import 'package:bulut_korsanlari/ui/logbook_screen.dart';
import 'package:bulut_korsanlari/ui/music_cue.dart';
import 'package:bulut_korsanlari/ui/scope.dart';
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
    // The first chapter opens with its cover; a tap goes on.
    expect(find.text('BÖLÜM 1'), findsOneWidget);
    expect(find.text('İlk Rüzgâr'), findsOneWidget);
    await tester.tap(find.text('İlk Rüzgâr'));
    await frames(tester, 30);

    expect(find.text('Meyve Bahçeleri Üstünde'), findsOneWidget);
    expect(find.text('Uçuşa çık'), findsOneWidget);
    expect(find.text('Komutan Selvi Ardıç'), findsOneWidget);
    expect(find.byType(Illustration), findsOneWidget);
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

  testWidgets('abandoning a mission leads to the debriefing; music follows', (
    tester,
  ) async {
    await landscape(tester);
    final store = await freshStore();
    await store.startCampaign('Ece');
    await tester.pumpWidget(CloudCorsairsApp(store: store));
    await frames(tester, 3);
    expect(store.music.wanted, MusicTrack.menu);
    await tester.tap(find.text('Devam et'));
    await frames(tester, 30);
    expect(store.music.wanted, MusicTrack.logbook);
    await tester.ensureVisible(find.text('Uçuşa çık'));
    await tester.tap(find.text('Uçuşa çık'));
    await frames(tester, 40);
    expect(find.byIcon(Icons.pause), findsOneWidget);
    expect(store.music.wanted, MusicTrack.dogfight);

    await tester.tap(find.byIcon(Icons.pause));
    await frames(tester, 3);
    await tester.tap(find.text('Görevi bırak'));
    await frames(tester, 40);
    expect(find.text('Hedef tutturulamadı'), findsOneWidget);
    // The painting is stamped across.
    expect(find.text('HEDEF TUTTURULAMADI'), findsOneWidget);
    expect(store.campaign!.missionIndex, 0);
    expect(store.campaign!.log.single.missionId, 'm1');
    expect(store.music.wanted, MusicTrack.defeat);

    await tester.tap(find.text('Devam'));
    await frames(tester, 30);
    expect(find.text('Bu görev yeniden deneniyor.'), findsOneWidget);
    expect(store.music.wanted, MusicTrack.logbook);

    // Back to the title: its music comes back too.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await frames(tester, 30);
    expect(find.text('Bulut Korsanları'), findsOneWidget);
    expect(store.music.wanted, MusicTrack.menu);
  });

  testWidgets('finishing a chapter opens the next chapter cover', (
    tester,
  ) async {
    await landscape(tester);
    final store = await freshStore();
    await store.startCampaign('Ada');
    // Fly straight to the last mission of chapter 1.
    store.campaign!.missionIndex =
        campaignMissions.indexWhere((m) => m.chapter == 2) - 1;
    final debrief = await store.recordResult(
      const MissionResult(outcome: MissionOutcome.success, kills: 3),
    );
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: MaterialApp(
          navigatorObservers: [musicRouteObserver],
          home: DebriefScreen(debrief: debrief),
        ),
      ),
    );
    await frames(tester, 10);
    expect(find.text('Görev başarılı'), findsOneWidget);
    await tester.ensureVisible(find.text('Devam'));
    await tester.tap(find.text('Devam'));
    await frames(tester, 30);
    expect(find.text('BÖLÜM 2'), findsOneWidget);
    expect(find.text('Kara Bora'), findsOneWidget);
    await tester.tap(find.text('Kara Bora'));
    await frames(tester, 30);
    expect(
      find.text(AppStrings('tr').t(store.campaign!.currentMission.titleKey)),
      findsOneWidget,
    );
  });

  testWidgets('pirates are briefed as the target', (tester) async {
    await landscape(tester);
    final store = await freshStore();
    await store.startCampaign('Ada');
    store.campaign!.missionIndex = campaignMissions.indexWhere(
      (m) => m.briefBy == Character.surmeli,
    );
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: const MaterialApp(home: LogbookScreen()),
      ),
    );
    await frames(tester, 10);
    expect(find.text('HEDEF'), findsOneWidget);
    expect(find.text('Sürmeli'), findsOneWidget);
  });

  testWidgets('the music volume setting is saved and applied', (tester) async {
    await landscape(tester);
    final store = await freshStore();
    await tester.pumpWidget(CloudCorsairsApp(store: store));
    await frames(tester, 3);
    await tester.tap(find.text('Ayarlar'));
    await frames(tester, 20);
    expect(find.text('Müzik sesi'), findsOneWidget);
    await store.setMusicVolume(0.3);
    await frames(tester, 3);
    expect(store.music.volume, closeTo(0.3, 1e-9));
    final again = await GameStore.load(deviceLang: 'tr');
    expect(again.musicVolume, closeTo(0.3, 1e-9));
  });

  testWidgets('the About box credits the music', (tester) async {
    await landscape(tester);
    final store = await freshStore();
    await tester.pumpWidget(CloudCorsairsApp(store: store));
    await frames(tester, 3);
    await tester.tap(find.text('Hakkında'));
    await frames(tester, 20);
    expect(find.textContaining('Gemini'), findsOneWidget);
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
