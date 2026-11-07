import 'package:flutter/material.dart';

import '../game/paint_kit.dart';

abstract final class AppColors {
  static const night = Color(0xFF0F2238);
  static const paper = Color(0xFFF3E7CF);
  static const paperEdge = Color(0xFFD9C29A);
  static const ink = Color(0xFF2B2118);
  static const inkSoft = Color(0xFF6B5A47);
  static const accent = Palette.hud;
  static const sail = Palette.pirateSail;
}

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF2A7C7E),
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppColors.accent,
        onPrimary: AppColors.ink,
        surface: AppColors.night,
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.night,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.ink,
        minimumSize: const Size(200, 48),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 16,
          letterSpacing: 0.5,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: const Color(0x9910202F),
        minimumSize: const Size(200, 46),
        side: const BorderSide(color: Color(0x88FFD27A)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );
}
