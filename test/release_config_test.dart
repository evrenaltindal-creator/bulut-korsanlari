import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The TestFlight workflow signs and looks up the app by one bundle id;
/// the Xcode project must build exactly that id or the upload is refused.
void main() {
  final workflow = File('.github/workflows/ios-testflight.yml')
      .readAsStringSync();
  final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj')
      .readAsStringSync();
  final plist = File('ios/Runner/Info.plist').readAsStringSync();

  String workflowBundleId() =>
      RegExp(r'BUNDLE_ID: (\S+)').firstMatch(workflow)!.group(1)!;

  test('the workflow signs the bundle id the app is built with', () {
    final ids = RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);')
        .allMatches(pbxproj)
        .map((m) => m.group(1)!)
        .where((id) => !id.endsWith('.RunnerTests'))
        .toSet();
    expect(ids, {workflowBundleId()});
    expect(workflowBundleId(), isNot(contains('bulutKorsanlari')));
  });

  test('iPhone only, landscape only', () {
    final families = RegExp(r'TARGETED_DEVICE_FAMILY = ([^;]+);')
        .allMatches(pbxproj)
        .map((m) => m.group(1))
        .toSet();
    expect(families, {'1'});
    final iphone = RegExp(
      r'<key>UISupportedInterfaceOrientations</key>\s*<array>(.*?)</array>',
      dotAll: true,
    ).firstMatch(plist)!.group(1)!;
    expect(iphone, isNot(contains('Portrait')));
    expect(iphone, contains('LandscapeLeft'));
  });

  test('no export-compliance question on every build', () {
    // Without this key each TestFlight build waits for a manual answer
    // before anyone can install it.
    expect(
      plist,
      matches(RegExp(r'<key>ITSAppUsesNonExemptEncryption</key>\s*<false/>')),
    );
  });

  test('the build carries notes and a store-style version', () {
    expect(workflow, contains('--whats-new @file:TESTFLIGHT_NOTES.txt'));
    final notes = File('TESTFLIGHT_NOTES.txt').readAsStringSync();
    expect(notes.trim(), isNotEmpty);
    expect(notes.length, lessThan(4000), reason: 'App Store Connect limit');
    final version = RegExp(
      r'^version: (\d+)\.(\d+)\.(\d+)\+(\d+)$',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync());
    expect(version, isNotNull);
    expect(int.parse(version!.group(1)!), greaterThanOrEqualTo(1));
  });
}
