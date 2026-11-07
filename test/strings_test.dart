import 'dart:io';

import 'package:bulut_korsanlari/campaign/campaign.dart';
import 'package:bulut_korsanlari/campaign/missions.dart';
import 'package:bulut_korsanlari/game/mission_result.dart';
import 'package:bulut_korsanlari/l10n/strings.dart';
import 'package:flutter_test/flutter_test.dart';

Set<String> placeholders(String s) =>
    RegExp(r'\{(\w+)\}').allMatches(s).map((m) => m.group(1)!).toSet();

void main() {
  final tr = AppStrings.table['tr']!;
  final en = AppStrings.table['en']!;

  test('Turkish and English have exactly the same keys', () {
    expect(tr.keys.toSet().difference(en.keys.toSet()), isEmpty);
    expect(en.keys.toSet().difference(tr.keys.toSet()), isEmpty);
  });

  test('placeholders match in both languages', () {
    for (final k in tr.keys) {
      expect(placeholders(tr[k]!), placeholders(en[k]!), reason: k);
    }
  });

  test('every mission, chapter, rank and outcome has its text', () {
    final needed = <String>[
      for (final m in campaignMissions) ...[
        m.titleKey,
        m.briefKey,
        m.winKey,
        m.loseKey,
      ],
      for (var c = 1; c <= chapterCount; c++) 'chapter.$c',
      for (var r = 0; r <= 4; r++) 'rank.$r',
      for (final o in MissionOutcome.values) 'debrief.title.${o.name}',
      for (final k in LogKind.values) 'log.entry.${k.name}',
      for (final k in MissionKind.values) 'log.kind.${k.name}',
    ];
    for (final k in needed) {
      expect(tr.containsKey(k), isTrue, reason: k);
    }
  });

  test('every key used in the code exists', () {
    final used = <String>{};
    final pattern = RegExp(r"""tr\('([a-zA-Z0-9_.]+)'""");
    for (final f in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      used.addAll(
        pattern.allMatches(f.readAsStringSync()).map((m) => m.group(1)!),
      );
    }
    expect(used, isNotEmpty);
    for (final k in used) {
      expect(tr.containsKey(k), isTrue, reason: '$k is used but missing');
    }
  });

  test('t() fills placeholders and falls back to the key', () {
    const s = AppStrings('en');
    expect(s.t('log.day', {'n': 3}), 'Day 3');
    expect(s.t('no.such.key'), 'no.such.key');
  });
}
