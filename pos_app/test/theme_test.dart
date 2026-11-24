import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/session/secure_session.dart';
import 'package:pos_app/core/theme/app_theme.dart';
import 'package:pos_app/core/theme/theme_mode_provider.dart';
import 'package:pos_app/features/auth/auth_provider.dart';

class _MemoryStorage implements SecureStorage {
  final map = <String, String>{};
  @override
  Future<void> delete(String key) async => map.remove(key);
  @override
  Future<void> deleteAll() async => map.clear();
  @override
  Future<String?> read(String key) async => map[key];
  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      map.remove(key);
    } else {
      map[key] = value;
    }
  }
}

void main() {
  test('light memakai biru logo sebagai primary', () {
    expect(AppTheme.light().colorScheme.primary, AppColors.primaryBlue);
    expect(AppTheme.light().brightness, Brightness.light);
  });

  test('dark tetap memakai aksen biru logo di permukaan gelap', () {
    final dark = AppTheme.dark();
    expect(dark.brightness, Brightness.dark);
    expect(dark.colorScheme.primary, AppColors.primaryBlue);
  });

  test('setMode tersimpan dan terbaca ulang', () async {
    final storage = _MemoryStorage();
    final container = ProviderContainer(
      overrides: [
        secureSessionProvider.overrideWithValue(
          SecureSession(storage: storage),
        ),
      ],
    );
    addTearDown(container.dispose);
    final before =
        await container.read(themeModeProvider.future);
    expect(before, ThemeMode.system);
    await container
        .read(themeModeProvider.notifier)
        .setMode(ThemeMode.dark);
    expect(container.read(themeModeProvider).value, ThemeMode.dark);
    expect(storage.map['theme_mode'], 'dark');
  });
}
