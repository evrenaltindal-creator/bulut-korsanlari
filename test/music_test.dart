import 'dart:async';
import 'dart:io';

import 'package:bulut_korsanlari/audio/music.dart';
import 'package:bulut_korsanlari/campaign/missions.dart';
import 'package:bulut_korsanlari/l10n/strings.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeVoice implements MusicVoice {
  FakeVoice(this.id);

  final int id;
  String? asset;
  double volume = 0;
  bool playing = false;
  bool paused = false;
  int starts = 0;
  bool failNextStart = false;
  bool hangNextStart = false;

  @override
  Future<void> start(String asset, double volume) async {
    starts++;
    if (failNextStart) {
      failNextStart = false;
      throw StateError('autoplay blocked');
    }
    if (hangNextStart) {
      // Chrome keeps the start waiting until the page is touched.
      hangNextStart = false;
      return Completer<void>().future;
    }
    this.asset = asset;
    this.volume = volume;
    playing = true;
  }

  @override
  Future<void> setVolume(double v) async => volume = v;

  @override
  Future<void> stop() async => playing = false;

  @override
  Future<void> pause() async => paused = true;

  @override
  Future<void> resume() async => paused = false;
}

class FakeBackend implements MusicBackend {
  final voices = <FakeVoice>[];

  @override
  MusicVoice createVoice() {
    final v = FakeVoice(voices.length);
    voices.add(v);
    return v;
  }

  Iterable<FakeVoice> get audible =>
      voices.where((v) => v.playing && v.volume > 0.001);
}

void ticks(MusicDirector d, double seconds) {
  for (var t = 0.0; t < seconds; t += 0.1) {
    d.tick(0.1);
  }
}

void main() {
  late FakeBackend backend;
  late MusicDirector d;

  setUp(() {
    backend = FakeBackend();
    d = MusicDirector(backend, volume: 1, autoTick: false);
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('the first track starts at full volume straight away', () async {
    d.play(MusicTrack.menu);
    await settle();
    expect(backend.audible.single.asset, 'audio/music/menu.mp3');
    expect(backend.audible.single.volume, closeTo(1, 1e-9));
  });

  test('asking for the playing track again does not restart it', () async {
    d.play(MusicTrack.menu);
    ticks(d, 5);
    d.play(MusicTrack.menu);
    await settle();
    expect(backend.voices.fold(0, (a, v) => a + v.starts), 1);
  });

  test('changing track crossfades and then stops the old one', () async {
    d.play(MusicTrack.menu);
    ticks(d, 3);
    d.play(MusicTrack.dogfight);
    ticks(d, 1);
    await settle();
    expect(backend.audible.map((v) => v.asset).toSet(), {
      'audio/music/menu.mp3',
      'audio/music/dogfight.mp3',
    });
    ticks(d, MusicDirector.crossfade + 0.5);
    await settle();
    expect(backend.audible.single.asset, 'audio/music/dogfight.mp3');
    expect(backend.audible.single.volume, closeTo(1, 1e-9));
    expect(d.playing, MusicTrack.dogfight);
  });

  test('a loop hands over to a fresh copy before it ends', () async {
    d.play(MusicTrack.raid);
    ticks(d, MusicTrack.raid.seconds - MusicDirector.crossfade + 0.3);
    await settle();
    final raid = backend.voices.where(
      (v) => v.playing && v.asset == 'audio/music/raid.mp3',
    );
    expect(
      raid,
      hasLength(2),
      reason: 'old copy fading out, new copy fading in',
    );
    ticks(d, MusicDirector.crossfade + 0.5);
    await settle();
    expect(backend.audible.single.asset, 'audio/music/raid.mp3');
    expect(d.playing, MusicTrack.raid);
  });

  test('a one-shot plays once and stays quiet', () async {
    d.play(MusicTrack.victory);
    ticks(d, MusicTrack.victory.seconds + 3);
    await settle();
    expect(backend.audible, isEmpty);
    expect(backend.voices.fold(0, (a, v) => a + v.starts), 1);
  });

  test('volume, per-track level and ducking', () async {
    d.volume = 0.5;
    d.play(MusicTrack.defeat);
    await settle();
    expect(
      backend.audible.single.volume,
      closeTo(0.5 * MusicTrack.defeat.level, 1e-6),
    );
    d.duck(true);
    await settle();
    expect(
      backend.audible.single.volume,
      closeTo(0.5 * MusicTrack.defeat.level * MusicDirector.duckLevel, 1e-6),
    );
    d.duck(false);
    d.volume = 0;
    await settle();
    expect(backend.audible, isEmpty);
  });

  test('pausing the app pauses the music and freezes its clock', () async {
    d.play(MusicTrack.menu);
    d.pause();
    await settle();
    expect(backend.voices.where((v) => v.playing).single.paused, isTrue);
    ticks(d, 400);
    d.resume();
    await settle();
    expect(backend.voices.where((v) => v.playing).single.paused, isFalse);
    expect(
      backend.voices.fold(0, (a, v) => a + v.starts),
      1,
      reason: 'no loop while paused',
    );
  });

  test('stop fades everything out', () async {
    d.play(MusicTrack.menu);
    d.stop();
    ticks(d, MusicDirector.crossfade + 0.5);
    await settle();
    expect(backend.audible, isEmpty);
    expect(d.wanted, isNull);
  });

  test('a start the browser refused is retried on the first touch', () async {
    final first = MusicDirector(backend, volume: 1, autoTick: false);
    backend.voices[2].failNextStart = true;
    first.play(MusicTrack.menu);
    await settle();
    expect(backend.audible, isEmpty);
    first.unlock();
    await settle();
    expect(backend.audible.single.asset, 'audio/music/menu.mp3');
  });

  test(
    'a start the browser keeps waiting is retried on the first touch',
    () async {
      final first = MusicDirector(backend, volume: 1, autoTick: false);
      backend.voices[2].hangNextStart = true;
      first.play(MusicTrack.menu);
      await settle();
      expect(backend.audible, isEmpty);
      first.unlock();
      await settle();
      expect(backend.audible.single.asset, 'audio/music/menu.mp3');
    },
  );

  test('a touch does not restart music that is already playing', () async {
    d.play(MusicTrack.menu);
    await settle();
    d.unlock();
    await settle();
    expect(backend.voices.fold(0, (a, v) => a + v.starts), 1);
  });

  group('files', () {
    test('every track has its file, at the stated length', () {
      for (final t in MusicTrack.values) {
        final f = File('assets/${t.asset}');
        expect(f.existsSync(), isTrue, reason: f.path);
        // 128 kbit/s constant bitrate: 16000 bytes a second.
        expect(f.lengthSync() / 16000, closeTo(t.seconds, 0.6), reason: f.path);
      }
    });

    test('no stray files in the music folder', () {
      final names = Directory('assets/audio/music')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .toSet();
      expect(names, MusicTrack.values.map((t) => '${t.name}.mp3').toSet());
    });

    test('the source note lists every file', () {
      final note = File('assets/audio/MUSIC_SOURCE.txt').readAsStringSync();
      for (final t in MusicTrack.values) {
        expect(note, contains('music/${t.name}.mp3'));
      }
    });

    test('the music folder is bundled', () {
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('- assets/audio/music/'),
      );
    });

    test(
      'the About text says the music is AI-generated, in both languages',
      () {
        for (final lang in AppStrings.supported) {
          expect(
            AppStrings.table[lang]!['about.music'],
            contains('Gemini'),
            reason: lang,
          );
        }
      },
    );
  });

  test('every mission has music and the last two share the finale', () {
    expect(campaignMissions.first.musicTrack, MusicTrack.dogfight);
    expect(
      campaignMissions
          .where((m) => m.musicTrack == MusicTrack.finale)
          .map((m) => m.id),
      ['m8', 'm9'],
    );
  });
}
