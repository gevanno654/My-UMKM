import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_provider.dart';

/// Mode tema persisten (kunci `theme_mode` di secure storage yang ada).
final themeModeProvider =
    AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  static const storageKey = 'theme_mode';

  @override
  Future<ThemeMode> build() async {
    final session = ref.watch(secureSessionProvider);
    final raw = await session.readThemeMode();
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    final session = ref.read(secureSessionProvider);
    final raw = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => null,
    };
    await session.writeThemeMode(raw);
    state = AsyncData(mode);
  }
}
