import 'package:flutter/material.dart';

/// Token warna identitas: biru diambil dari logo "G".
abstract final class AppColors {
  static const primaryBlue = Color(0xFF1E6FDB);
}

/// Skema Material 3: permukaan netral hangat (light) / arang (dark),
/// biru logo hanya untuk aksi utama dan status aktif.
abstract final class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryBlue,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primaryBlue,
      surface: const Color(0xFFFAF7F2),
      surfaceContainerLowest: const Color(0xFFFFFDF9),
      surfaceContainer: const Color(0xFFF1EBE1),
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryBlue,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.primaryBlue,
      surface: const Color(0xFF16181D),
      surfaceContainerLowest: const Color(0xFF1D2026),
      surfaceContainer: const Color(0xFF23262D),
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
    );
  }
}
