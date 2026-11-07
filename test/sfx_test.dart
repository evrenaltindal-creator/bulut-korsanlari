import 'dart:io';
import 'dart:typed_data';

import 'package:bulut_korsanlari/audio/sfx.dart';
import 'package:bulut_korsanlari/core/controls.dart';
import 'package:bulut_korsanlari/game/bombing/bombing_sim.dart';
import 'package:bulut_korsanlari/game/dogfight/dogfight_sim.dart';
import 'package:bulut_korsanlari/game/mission_game.dart';
import 'package:bulut_korsanlari/game/mission_result.dart';
import 'package:bulut_korsanlari/l10n/strings.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeLoop implements SfxLoop {
  FakeLoop(this.sfx, this.volume);

  final Sfx sfx;
  double volume;
  double rate = 1;
  bool paused = false;
  bool stopped = false;

  @override
  Future<void> setVolume(double v) async => volume = v;
  @override
  Future<void> setRate(double r) async => rate = r;
  @override
  Future<void> pause() async => paused = true;
  @override
  Future<void> resume() async => paused = false;
  @override
  Future<void> stop() async => stopped = true;
}

class FakeSfx implements SfxBackend {
  final played = <Sfx>[];
  final loops = <FakeLoop>[];

  Iterable<FakeLoop> get live => loops.where((l) => !l.stopped);

  @override
  Future<void> preload() async {}

  @override
  Future<void> play(Sfx sfx, double volume) async => played.add(sfx);

  @override
  SfxLoop loop(Sfx sfx, double volume) {
    final l = FakeLoop(sfx, volume);
    loops.add(l);
    return l;
  }
}

void main() {
  late FakeSfx backend;
  late SfxDirector d;

  setUp(() {
    backend = FakeSfx();
    d = SfxDirector(backend);
  });

  group('director', () {
    test('events become sounds', () {
      for (final e in SimEvent.values) {
        d.tick(1);
        d.event(e);
      }
      expect(backend.played, [
        Sfx.hit,
        Sfx.explosion,
        Sfx.explosion,
        Sfx.damage,
        Sfx.flak,
        Sfx.bomb,
        Sfx.jam,
        Sfx.explosion,
        Sfx.warning,
      ]);
    });

    test('a burst of hits in one moment plays once', () {
      d.event(SimEvent.hit);
      d.event(SimEvent.hit);
      d.event(SimEvent.hit);
      expect(backend.played, [Sfx.hit]);
      d.tick(Sfx.hit.gap + 0.001);
      d.event(SimEvent.hit);
      expect(backend.played, [Sfx.hit, Sfx.hit]);
    });

    test('guns and engine loop until told to stop', () {
      d.guns(on: true);
      d.engine(on: true);
      expect(
        backend.live.map((l) => l.sfx),
        unorderedEquals([Sfx.gun, Sfx.engine]),
      );
      d.guns(on: true);
      expect(backend.loops, hasLength(2), reason: 'no second gun loop');
      d.guns(on: false);
      expect(backend.live.single.sfx, Sfx.engine);
      d.stopLoops();
      expect(backend.live, isEmpty);
    });

    test('engine pitch follows speed but ignores tiny changes', () {
      d.engine(on: true, rate: 1);
      final engine = backend.loops.single;
      d.engine(on: true, rate: 1.01);
      expect(engine.rate, 1);
      d.engine(on: true, rate: 1.2);
      expect(engine.rate, 1.2);
    });

    test('pause holds loops and drops one-shots', () {
      d.guns(on: true);
      d.pause();
      expect(backend.loops.single.paused, isTrue);
      d.event(SimEvent.blast);
      expect(backend.played, isEmpty);
      d.resume();
      expect(backend.loops.single.paused, isFalse);
    });

    test('volume zero is silent and volume reaches running loops', () {
      d.engine(on: true);
      d.volume = 0.5;
      expect(
        backend.loops.single.volume,
        closeTo(Sfx.engine.level * 0.5, 1e-9),
      );
      d.stopLoops();
      d.volume = 0;
      d.event(SimEvent.blast);
      d.guns(on: true);
      expect(backend.played, isEmpty);
      expect(backend.live, isEmpty);
    });
  });

  group('simulations report what can be heard', () {
    test('dogfight: hits, a kill, being hit and going down', () {
      final s = DogfightSim(
        config: const DogfightConfig(enemies: [PirateClass.scout], seed: 3),
        skills: const PilotSkills(gunnery: 1, handling: 0.5),
      );
      final e = s.pirates.first;
      e.pos.setFrom(s.player.pos + s.player.forward * 350);
      e.yaw = s.player.yaw;
      e.mode = PirateMode.breakAway;
      e.breakDir = s.player.forward;
      e.modeTimer = 100;
      final c = ControlState()..fire = true;
      for (var i = 0; i < 60 * 6; i++) {
        s.update(1 / 60, c);
      }
      expect(s.events, containsAll([SimEvent.hit, SimEvent.kill]));
      s.events.clear();
      s.damagePlayer(1);
      expect(s.events, [SimEvent.playerHit, SimEvent.down]);
    });

    test('dogfight: holding the trigger too long jams the guns', () {
      final s = DogfightSim(
        config: const DogfightConfig(enemies: [PirateClass.scout], seed: 3),
      );
      final c = ControlState()..fire = true;
      for (var t = 0.0; t < 10 && !s.jammed; t += 1 / 60) {
        s.update(1 / 60, c);
      }
      expect(s.jammed, isTrue);
      expect(s.events.where((e) => e == SimEvent.jam), hasLength(1));
    });

    test('bombing: a bomb leaves the rack and blows up on landing', () {
      final s = BombingSim(
        config: const BombingConfig(
          targets: [BombTargetSpec(BombTargetKind.depot)],
          bombs: 3,
        ),
      );
      s.dropBomb();
      expect(s.events, [SimEvent.bombDrop]);
      for (var i = 0; i < 120; i++) {
        s.update(1 / 60, ControlState());
      }
      expect(s.events, contains(SimEvent.blast));
    });
  });

  testWidgets('a running mission plays its engine and guns, and stops them', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 740);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final game = DogfightGame(
      config: const DogfightConfig(enemies: [PirateClass.scout]),
      tr: const AppStrings('tr').t,
      onFinished: (_) {},
      sfx: d,
    );
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(d.engineOn, isTrue);
    expect(d.gunOn, isFalse);

    final finger = await tester.startGesture(const Offset(640, 200));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(d.gunOn, isTrue);
    await finger.up();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(d.gunOn, isFalse);

    game.setPaused(true);
    expect(backend.loops.firstWhere((l) => l.sfx == Sfx.engine).paused, isTrue);
    game.setPaused(false);

    // Leaving the mission silences every loop.
    await tester.pumpWidget(const SizedBox());
    expect(backend.live, isEmpty);
  });

  group('files', () {
    ({int channels, int rate, int bits, Int16List samples}) readWav(File f) {
      final b = f.readAsBytesSync();
      final data = ByteData.sublistView(b);
      expect(String.fromCharCodes(b.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(b.sublist(8, 12)), 'WAVE');
      final channels = data.getUint16(22, Endian.little);
      final rate = data.getUint32(24, Endian.little);
      final bits = data.getUint16(34, Endian.little);
      final samples = Int16List.sublistView(b, 44);
      return (channels: channels, rate: rate, bits: bits, samples: samples);
    }

    test('every effect is a small mono 16-bit WAV', () {
      for (final s in Sfx.values) {
        final f = File('assets/${s.asset}');
        expect(f.existsSync(), isTrue, reason: f.path);
        expect(f.lengthSync(), lessThan(120 * 1024), reason: f.path);
        final w = readWav(f);
        expect((w.channels, w.rate, w.bits), (1, 22050, 16), reason: f.path);
      }
    });

    test('loops join without a click', () {
      for (final s in Sfx.values.where((s) => s.loop)) {
        final w = readWav(File('assets/${s.asset}'));
        final jump = (w.samples.first - w.samples.last).abs() / 32768;
        expect(jump, lessThan(0.01), reason: s.name);
      }
    });

    test('the source note covers every effect, and recordings are CC0', () {
      final note = File('assets/audio/SFX_SOURCE.txt').readAsStringSync();
      for (final s in Sfx.values) {
        expect(note, contains('sfx/${s.name}.wav'), reason: s.name);
      }
      expect(note, contains('CC0'));
      for (final lang in AppStrings.supported) {
        expect(
          AppStrings.table[lang]!['about.sfx'],
          contains('CC0'),
          reason: lang,
        );
      }
    });

    test('no stray files and the folder is bundled', () {
      final names = Directory('assets/audio/sfx')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .toSet();
      expect(names, Sfx.values.map((s) => '${s.name}.wav').toSet());
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('- assets/audio/sfx/'),
      );
    });
  });
}
