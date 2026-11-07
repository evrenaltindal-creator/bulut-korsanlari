import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/music.dart';
import '../audio/sfx.dart';
import '../game/mission_result.dart';
import '../l10n/strings.dart';
import 'campaign.dart';

/// App-wide state: settings plus the saved campaign.
///
/// Everything is stored on the device; the game never talks to a server.
class GameStore extends ChangeNotifier {
  GameStore._(
    this._prefs, {
    required this.lang,
    required this.invertY,
    required this.music,
    required this.musicVolume,
    required this.sfx,
    required this.sfxVolume,
    this.campaign,
  });

  static const _campaignKey = 'campaign_v1';
  static const _langKey = 'lang';
  static const _invertKey = 'invert_y';
  static const _musicKey = 'music_volume';
  static const _sfxKey = 'sfx_volume';
  static const defaultSfxVolume = 0.8;
  static const defaultMusicVolume = 0.7;

  /// [backend] plays the music; without one the game stays silent.
  /// Tests pass [autoTick] false and drive the music clock themselves.
  static Future<GameStore> load({
    String? deviceLang,
    MusicBackend? backend,
    SfxBackend? sfxBackend,
    bool autoTick = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final fallback = AppStrings.supported.contains(deviceLang)
        ? deviceLang!
        : 'en';
    Campaign? campaign;
    final raw = prefs.getString(_campaignKey);
    if (raw != null) {
      try {
        campaign = Campaign.fromJson(
          (jsonDecode(raw) as Map).cast<String, Object?>(),
        );
      } on Object catch (e) {
        // A corrupt save must not lock the player out of the game.
        debugPrint('Discarding unreadable save: $e');
      }
    }
    final volume = prefs.getDouble(_musicKey) ?? defaultMusicVolume;
    final sfxVolume = prefs.getDouble(_sfxKey) ?? defaultSfxVolume;
    return GameStore._(
      prefs,
      lang: prefs.getString(_langKey) ?? fallback,
      invertY: prefs.getBool(_invertKey) ?? false,
      music: MusicDirector(
        backend ?? SilentMusicBackend(),
        volume: volume,
        autoTick: backend != null && autoTick,
      ),
      musicVolume: volume,
      sfx: SfxDirector(sfxBackend ?? SilentSfxBackend(), volume: sfxVolume),
      sfxVolume: sfxVolume,
      campaign: campaign,
    );
  }

  final SharedPreferences _prefs;
  final math.Random rng = math.Random();

  String lang;
  bool invertY;
  final MusicDirector music;

  /// 0 (off) .. 1.
  double musicVolume;
  final SfxDirector sfx;

  /// 0 (off) .. 1.
  double sfxVolume;
  Campaign? campaign;

  AppStrings get strings => AppStrings(lang);

  bool get hasCampaign => campaign != null;

  Future<void> setLang(String value) async {
    lang = value;
    notifyListeners();
    await _prefs.setString(_langKey, value);
  }

  Future<void> setInvertY(bool value) async {
    invertY = value;
    notifyListeners();
    await _prefs.setBool(_invertKey, value);
  }

  Future<void> setMusicVolume(double value) async {
    musicVolume = value.clamp(0.0, 1.0);
    music.volume = musicVolume;
    notifyListeners();
    await _prefs.setDouble(_musicKey, musicVolume);
  }

  Future<void> setSfxVolume(double value) async {
    sfxVolume = value.clamp(0.0, 1.0);
    sfx.volume = sfxVolume;
    notifyListeners();
    await _prefs.setDouble(_sfxKey, sfxVolume);
  }

  Future<void> startCampaign(String pilotName) async {
    campaign = Campaign.start(
      pilotName.trim().isEmpty ? randomPilotName(rng) : pilotName.trim(),
    );
    notifyListeners();
    await _save();
  }

  Future<Debrief> recordResult(MissionResult result) async {
    final c = campaign!;
    final d = c.apply(
      result,
      rng: rng,
      recruitName: () => randomPilotName(rng),
    );
    notifyListeners();
    await _save();
    return d;
  }

  Future<void> _save() async {
    final c = campaign;
    if (c == null) {
      await _prefs.remove(_campaignKey);
    } else {
      await _prefs.setString(_campaignKey, jsonEncode(c.toJson()));
    }
  }
}
