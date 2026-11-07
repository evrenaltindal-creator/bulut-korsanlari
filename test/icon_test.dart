import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Width, height and PNG colour type (2 = RGB, 6 = RGB with alpha).
(int, int, int) pngInfo(File f) {
  final b = f.readAsBytesSync();
  expect(b.sublist(1, 4), 'PNG'.codeUnits, reason: f.path);
  final d = ByteData.sublistView(b);
  return (d.getUint32(16), d.getUint32(20), b[25]);
}

void main() {
  test('the icon source is a square, opaque 1024 px picture', () {
    final (w, h, type) = pngInfo(File('assets/branding/app_icon_source.png'));
    expect((w, h), (1024, 1024));
    expect(type, 2, reason: 'no alpha channel');
  });

  test('every iOS icon exists at its size and has no alpha', () {
    // The App Store rejects icons with transparency.
    const dir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    final contents =
        jsonDecode(File('$dir/Contents.json').readAsStringSync()) as Map;
    for (final e in (contents['images'] as List).cast<Map>()) {
      final size = double.parse((e['size'] as String).split('x').first);
      final scale = int.parse((e['scale'] as String).replaceAll('x', ''));
      final px = (size * scale).round();
      final (w, h, type) = pngInfo(File('$dir/${e['filename']}'));
      expect((w, h), (px, px), reason: e['filename'] as String);
      expect(type, 2, reason: '${e['filename']} must be opaque');
    }
  });

  test('Android has square icons and an adaptive icon at every density', () {
    const res = 'android/app/src/main/res';
    const densities = {
      'mdpi': 1.0,
      'hdpi': 1.5,
      'xhdpi': 2.0,
      'xxhdpi': 3.0,
      'xxxhdpi': 4.0,
    };
    densities.forEach((name, k) {
      final legacy = pngInfo(File('$res/mipmap-$name/ic_launcher.png'));
      expect(
        (legacy.$1, legacy.$2),
        ((48 * k).round(), (48 * k).round()),
        reason: name,
      );
      for (final layer in [
        'ic_launcher_background',
        'ic_launcher_foreground',
      ]) {
        final info = pngInfo(File('$res/mipmap-$name/$layer.png'));
        expect(
          (info.$1, info.$2),
          ((108 * k).round(), (108 * k).round()),
          reason: '$name $layer',
        );
      }
    });
    final xml = File('$res/mipmap-anydpi-v26/ic_launcher.xml')
        .readAsStringSync();
    expect(xml, contains('@mipmap/ic_launcher_background'));
    expect(xml, contains('@mipmap/ic_launcher_foreground'));
  });

  test('the web has its icons and favicon', () {
    for (final (path, px) in [
      ('web/icons/Icon-192.png', 192),
      ('web/icons/Icon-512.png', 512),
      ('web/icons/Icon-maskable-192.png', 192),
      ('web/icons/Icon-maskable-512.png', 512),
      ('web/favicon.png', 32),
    ]) {
      final (w, h, _) = pngInfo(File(path));
      expect((w, h), (px, px), reason: path);
    }
  });

  test('the icon source is not shipped inside the app', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      isNot(contains('assets/branding')),
    );
  });
}
