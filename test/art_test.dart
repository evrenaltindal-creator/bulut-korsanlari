import 'dart:io';

import 'package:bulut_korsanlari/campaign/characters.dart';
import 'package:bulut_korsanlari/campaign/missions.dart';
import 'package:bulut_korsanlari/l10n/strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final paths = <String>[
    for (var c = 1; c <= chapterCount; c++) Art.chapter(c),
    for (final m in campaignMissions) m.image,
    for (final ch in Character.values) ch.asset,
  ];

  test('every chapter, mission and character has its picture', () {
    for (final p in paths) {
      expect(File(p).existsSync(), isTrue, reason: p);
    }
  });

  test('pictures are small enough to ship', () {
    for (final p in paths) {
      expect(File(p).lengthSync(), lessThan(400 * 1024), reason: p);
    }
  });

  test('no stray pictures and every folder is bundled', () {
    final onDisk = Directory('assets/images')
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path.replaceAll(r'\', '/'))
        .where((p) => p.endsWith('.jpg'))
        .toSet();
    expect(onDisk, paths.toSet());
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final dir in ['chapters', 'missions', 'portraits']) {
      expect(pubspec, contains('- assets/images/$dir/'));
    }
  });

  test('the source note lists every picture', () {
    final note = File('assets/images/IMAGE_SOURCE.txt').readAsStringSync();
    for (var c = 1; c <= chapterCount; c++) {
      expect(note, contains('chapter$c.jpg'));
    }
    expect(note, contains('m1.jpg ... m9.jpg'));
    expect(
      campaignMissions.length,
      9,
      reason: 'update the note if this changes',
    );
    for (final ch in Character.values) {
      expect(note, contains('portraits/${ch.name}.jpg'));
    }
  });

  test(
    'the About text says the pictures are AI-generated, in both languages',
    () {
      for (final lang in AppStrings.supported) {
        expect(
          AppStrings.table[lang]!['about.art'],
          contains('Nano Banana'),
          reason: lang,
        );
      }
    },
  );

  test('every character has a name in both languages', () {
    for (final lang in AppStrings.supported) {
      for (final ch in Character.values) {
        expect(
          AppStrings.table[lang]!.containsKey(ch.nameKey),
          isTrue,
          reason: '$lang ${ch.name}',
        );
      }
    }
  });
}
