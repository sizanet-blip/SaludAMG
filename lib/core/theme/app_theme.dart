import 'package:flutter/material.dart';

import '../../domain/enums/health_enums.dart';

/// Paleta alineada con TelAMG y TiroAMG: superficie clara, tinta azul gris
/// y acento cian. El naranja queda para el detalle de marca.
abstract final class AppColors {
  static const Color background = Color(0xFFF4F6F8);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE2E8EE);
  static const Color divider = Color(0xFFE8EEF2);
  static const Color appBar = Color(0xFFFFFFFF);
  static const Color appBarSection = Color(0xFF00A0E3);
  static const Color title = Color(0xFF263238);
  static const Color subtitle = Color(0xFF78909C);
  static const Color subtitleSoft = Color(0xFF90A4AE);
  static const Color chevron = Color(0xFFB0BEC5);
  static const Color primary = Color(0xFF37474F);
  static const Color accent = Color(0xFF00AEEF);
  static const Color accentOrange = Color(0xFFFF8C1A);
  static const Color brandInk = Color(0xFF1A1D21);
  static const Color ok = Color(0xFF2E7D32);
  static const Color warn = Color(0xFFEF6C00);
  static const Color danger = Color(0xFFC62828);
  static const Color systolic = Color(0xFFE53935);
  static const Color diastolic = Color(0xFF1565C0);
}

Color colorFor(ReferenceLevel level) => switch (level) {
      ReferenceLevel.within => AppColors.ok,
      ReferenceLevel.above => AppColors.danger,
      ReferenceLevel.below => AppColors.warn,
    };

abstract final class AppRadii {
  static const double card = 16;
  static const double iconBox = 12;
}

ThemeData buildSaludAmgTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: base.copyWith(
      primary: AppColors.primary,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.appBar,
      foregroundColor: AppColors.title,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      toolbarHeight: 100,
      titleSpacing: 8,
      iconTheme: IconThemeData(color: AppColors.title),
      actionsIconTheme: IconThemeData(color: AppColors.title),
      shape: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    // Como TiroAMG / boceto acceso: seleccionado en cian claro, no gris oscuro.
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        visualDensity: VisualDensity.comfortable,
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.title;
          return AppColors.primary;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFFB3E5FC);
          }
          return Colors.white;
        }),
        side: const WidgetStatePropertyAll(
          BorderSide(color: AppColors.border),
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      space: 1,
      thickness: 1,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
  );
}
