import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pos_app/core/db/app_db.dart';
import 'package:pos_app/core/router.dart';
import 'package:pos_app/core/session/secure_session.dart';
import 'package:pos_app/features/auth/auth_api.dart';
import 'package:pos_app/features/auth/auth_provider.dart';
import 'package:pos_app/features/auth/auth_state.dart';
import 'package:pos_app/features/auth/pin_guard.dart';
import 'package:pos_app/features/auth/pin_setup_screen.dart';
import 'package:pos_app/features/auth/pin_unlock_screen.dart';

/// In-memory fake dari [SecureStorage] agar test tidak menyentuh platform channel.
class MemorySecureStorage implements SecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<void> deleteAll() async => _data.clear();
}

const _kProfile = AuthProfile(
  id: 'user-1',
  storeId: 'store-1',
  name: 'Budi',
  email: 'budi@warung.id',
  storeName: 'Warung Barokah',
);

Map<String, dynamic> _authSuccessBody() => {
      'user': {
        'id': 'user-1',
        'storeId': 'store-1',
        'name': 'Budi',
        'email': 'budi@warung.id',
      },
      'store': {'id': 'store-1', 'name': 'Warung Barokah'},
      'accessToken': 'access-123',
      'refreshToken': 'refresh-456',
    };

({AuthNotifier notifier, SecureSession session, AppDb db, ProviderContainer container})
    makePinEnv({bool failNetwork = false}) {
  final session = SecureSession(storage: MemorySecureStorage());
  final db = AppDb(NativeDatabase.memory());
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (failNetwork) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
            ),
          );
          return;
        }
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: _authSuccessBody(),
          ),
        );
      },
    ),
  );
  final container = ProviderContainer(
    overrides: [
      secureSessionProvider.overrideWithValue(session),
      appDbProvider.overrideWithValue(db),
      authApiProvider.overrideWithValue(AuthApi(dio: dio)),
    ],
  );
  addTearDown(container.dispose);
  final notifier = container.read(authProvider.notifier);
  return (notifier: notifier, session: session, db: db, container: container);
}

/// Menyemai sesi lengkap (token + profil + PIN) seperti setelah login + set PIN.
Future<void> seedFullSession(SecureSession session) async {
  await session.saveTokens(
    accessToken: 'access-123',
    refreshToken: 'refresh-456',
    profileJson: jsonEncode(_kProfile.toJson()),
  );
  await session.savePinHash(pin: '123456');
}

/// Menjalankan [fn] di luar zona fake-async widget tester agar Dio/Drift
/// (yang memakai Timer/microtask nyata) bisa selesai.
Future<void> runRealAsync(WidgetTester tester, Future<void> Function() fn) =>
    tester.runAsync(fn);

/// Memompa [screen] di dalam GoRouter minimal (agar `context.go` berfungsi).
Future<void> pumpPinScreen(
  WidgetTester tester,
  ProviderContainer container,
  Widget screen,
) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, state) => screen),
      GoRoute(
        path: '/home',
        builder: (_, state) =>
            const Scaffold(body: Text('home-ok', key: Key('homeMarker'))),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('PinGuard.canUnlockOffline', () {
    test('false saat storage kosong', () async {
      final env = makePinEnv();
      addTearDown(env.db.close);

      expect(await PinGuard(session: env.session).canUnlockOffline(), isFalse);
    });

    test('true bila pinHash + profileJson + accessToken ada', () async {
      final env = makePinEnv();
      addTearDown(env.db.close);
      await seedFullSession(env.session);

      expect(await PinGuard(session: env.session).canUnlockOffline(), isTrue);
    });

    test('false bila PIN belum diset', () async {
      final env = makePinEnv();
      addTearDown(env.db.close);
      await env.session.saveTokens(
        accessToken: 'access-123',
        refreshToken: 'refresh-456',
        profileJson: jsonEncode(_kProfile.toJson()),
      );

      expect(await PinGuard(session: env.session).canUnlockOffline(), isFalse);
    });
  });

  group('set PIN (PinSetupScreen)', () {
    testWidgets('PIN 123456 2x sama → hash tersimpan (bukan plaintext) + authenticated',
        (tester) async {
      final env = makePinEnv();
      addTearDown(env.db.close);
      await pumpPinScreen(tester, env.container, const PinSetupScreen());
      // Login online dulu agar state = pinSetupRequired (PIN belum ada).
      // runRealAsync: Dio/Drift memakai Timer nyata yang macet di fake-async.
      await runRealAsync(
        tester,
        () => env.notifier.login(
          email: 'budi@warung.id',
          password: 'rahasia123',
        ),
      );
      expect(env.notifier.state, isA<AuthPinSetupRequired>());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('pinField')), '123456');
      await tester.enterText(find.byKey(const Key('confirmPinField')), '123456');
      await tester.tap(find.byKey(const Key('pinSetupButton')));
      await tester.pumpAndSettle();

      expect(env.notifier.state, isA<AuthAuthenticated>());
      final tokens = await env.session.readTokens();
      expect(tokens.pinHash, isNotNull);
      expect(tokens.pinHash, isNot(contains('123456')));
      // Berhasil → navigasi ke /home.
      expect(find.byKey(const Key('homeMarker')), findsOneWidget);
    });

    testWidgets('konfirmasi beda → error + tetap pinSetupRequired', (tester) async {
      final env = makePinEnv();
      addTearDown(env.db.close);
      await pumpPinScreen(tester, env.container, const PinSetupScreen());
      await runRealAsync(
        tester,
        () => env.notifier.login(
          email: 'budi@warung.id',
          password: 'rahasia123',
        ),
      );

      await tester.enterText(find.byKey(const Key('pinField')), '123456');
      await tester.enterText(find.byKey(const Key('confirmPinField')), '654321');
      await tester.tap(find.byKey(const Key('pinSetupButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('errorText')), findsOneWidget);
      expect(env.notifier.state, isA<AuthPinSetupRequired>());
      expect((await env.session.readTokens()).pinHash, isNull);
    });
  });

  group('unlock offline (PinGuard + AuthNotifier)', () {
    test('bootstrap sesi ber-PIN → pinLocked; unlock benar → authenticated',
        () async {
      final env = makePinEnv();
      addTearDown(env.db.close);
      await seedFullSession(env.session);

      await env.notifier.bootstrap();
      expect(env.notifier.state, isA<AuthPinLocked>());

      final ok = await env.notifier.unlockSession('123456');
      expect(ok, isTrue);
      expect(env.notifier.state, isA<AuthAuthenticated>());
      expect(
        (env.notifier.state as AuthAuthenticated).profile.email,
        'budi@warung.id',
      );
    });

    test('5x salah → lockedUntil ~60 detik; PIN benar ikut ditolak',
        () async {
      final env = makePinEnv();
      addTearDown(env.db.close);
      await seedFullSession(env.session);
      final guard = PinGuard(session: env.session);

      for (var i = 0; i < 5; i++) {
        expect(await guard.verifyPin('000000'), isFalse);
      }
      expect(await guard.failCount(), 5);

      final locked = await guard.lockedUntil();
      expect(locked, isNotNull);
      final remaining = locked!.difference(DateTime.now());
      expect(remaining.inSeconds, greaterThanOrEqualTo(50));
      expect(remaining.inSeconds, lessThanOrEqualTo(60));

      // Lockout tersimpan di storage: guard baru ikut melihat kunci.
      expect(await PinGuard(session: env.session).lockedUntil(), isNotNull);
      // PIN benar pun ditolak selama terkunci.
      expect(await guard.verifyPin('123456'), isFalse);
    });

    test('tanpa internet + sesi ada → PIN tetap bisa buka (murni offline)',
        () async {
      final env = makePinEnv(failNetwork: true);
      addTearDown(env.db.close);
      await seedFullSession(env.session);

      await env.notifier.bootstrap();
      expect(env.notifier.state, isA<AuthPinLocked>());

      // unlockSession tidak menyentuh jaringan walau Dio selalu gagal.
      expect(await env.notifier.unlockSession('123456'), isTrue);
      expect(env.notifier.state, isA<AuthAuthenticated>());
    });

    testWidgets('unlock salah → pesan error + tetap pinLocked', (tester) async {
      final env = makePinEnv();
      addTearDown(env.db.close);
      await seedFullSession(env.session);
      await pumpPinScreen(tester, env.container, const PinUnlockScreen());
      await runRealAsync(tester, () => env.notifier.bootstrap());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('pinField')), '000000');
      await tester.tap(find.byKey(const Key('pinUnlockButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('errorText')), findsOneWidget);
      expect(find.textContaining('PIN salah'), findsOneWidget);
      expect(env.notifier.state, isA<AuthPinLocked>());
    });

    testWidgets('unlock benar via screen → navigasi /home', (tester) async {
      final env = makePinEnv();
      addTearDown(env.db.close);
      await seedFullSession(env.session);
      await pumpPinScreen(tester, env.container, const PinUnlockScreen());
      await runRealAsync(tester, () => env.notifier.bootstrap());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('pinField')), '123456');
      await tester.tap(find.byKey(const Key('pinUnlockButton')));
      await tester.pumpAndSettle();

      expect(env.notifier.state, isA<AuthAuthenticated>());
      expect(find.byKey(const Key('homeMarker')), findsOneWidget);
    });
  });

  group('router gate', () {
    test('authRedirect: sesi terkunci selalu ke /pin-unlock', () {
      const locked = AuthPinLocked(_kProfile);
      expect(authRedirect(locked, '/home'), '/pin-unlock');
      expect(authRedirect(locked, '/login'), '/pin-unlock');
      expect(authRedirect(locked, '/pin-unlock'), isNull);
    });

    test('authRedirect: pinSetupRequired → /pin-setup; tamu → /login', () {
      expect(
        authRedirect(const AuthPinSetupRequired(_kProfile), '/home'),
        '/pin-setup',
      );
      expect(
        authRedirect(const AuthPinSetupRequired(_kProfile), '/pin-setup'),
        isNull,
      );
      expect(authRedirect(const AuthUnauthenticated(), '/home'), '/login');
      expect(authRedirect(const AuthUnauthenticated(), '/login'), isNull);
    });

    testWidgets('buka /home saat terkunci → tampil PinUnlockScreen',
        (tester) async {
      // Di dalam zona fake-async, bangun router + bootstrap via runAsync,
      // lalu pompa ulang agar redirect GoRouter dievaluasi.
      late GoRouter router;
      final session = SecureSession(storage: MemorySecureStorage());
      final db = AppDb(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          secureSessionProvider.overrideWithValue(session),
          appDbProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);
      await seedFullSession(session);
      await container.read(authProvider.notifier).bootstrap();

      router = buildRouter(
        initialLocation: '/home',
        authSnapshot: () => container.read(authProvider),
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Buka dengan PIN'), findsOneWidget);
    });
  });
}
