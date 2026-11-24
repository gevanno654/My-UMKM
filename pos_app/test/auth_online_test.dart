import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/db/app_db.dart';
import 'package:pos_app/core/nav/app_shell.dart';
import 'package:pos_app/core/router.dart';
import 'package:pos_app/core/session/secure_session.dart';
import 'package:pos_app/features/auth/auth_api.dart';
import 'package:pos_app/features/auth/auth_provider.dart';
import 'package:pos_app/features/auth/auth_state.dart';
import 'package:pos_app/features/auth/home_screen.dart';
import 'package:pos_app/features/auth/login_screen.dart';
import 'package:pos_app/features/auth/register_screen.dart';

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

Map<String, dynamic> authSuccessBody() => {
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

Response<dynamic> ok(RequestOptions options, Map<String, dynamic> data,
        [int statusCode = 200]) =>
    Response(requestOptions: options, statusCode: statusCode, data: data);

Never fail(
  RequestOptions options,
  int statusCode,
  Map<String, dynamic> data,
) {
  throw DioException(
    requestOptions: options,
    response:
        Response(requestOptions: options, statusCode: statusCode, data: data),
    type: DioExceptionType.badResponse,
  );
}

/// Dio yang di-stub via interceptor: meniru semantik Dio asli
/// (status non-2xx → [DioException] dengan response terlampir).
Dio stubDio(FutureOr<Response<dynamic>> Function(RequestOptions) respond) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          handler.resolve(await respond(options));
        } on DioException catch (e) {
          handler.reject(e);
        }
      },
    ),
  );
  return dio;
}

({AuthNotifier notifier, SecureSession session, AppDb db, ProviderContainer container}) makeNotifier(
  FutureOr<Response<dynamic>> Function(RequestOptions) respond,
) {
  final session = SecureSession(storage: MemorySecureStorage());
  final db = AppDb.openMemory();
  final container = ProviderContainer(
    overrides: [
      secureSessionProvider.overrideWithValue(session),
      appDbProvider.overrideWithValue(db),
      authApiProvider.overrideWithValue(AuthApi(dio: stubDio(respond))),
    ],
  );
  addTearDown(container.dispose);
  final notifier = container.read(authProvider.notifier);
  return (notifier: notifier, session: session, db: db, container: container);
}

Future<void> pumpAuthScreen(
  WidgetTester tester,
  Widget screen,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pompa [HomeScreen] di dalam [AppShell] (cangkang produksi).
Future<void> pumpHomeShell(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AppShell(child: HomeScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('AuthNotifier + AuthApi (mock Dio)', () {
    test('login 200 → saveTokens dipanggil + state pinSetupRequired', () async {
      final env = makeNotifier((options) => ok(options, authSuccessBody()));

      await env.notifier.login(email: 'budi@warung.id', password: 'rahasia123');

      final tokens = await env.session.readTokens();
      expect(tokens.accessToken, 'access-123');
      expect(tokens.refreshToken, 'refresh-456');
      expect(env.notifier.state, isA<AuthPinSetupRequired>());
      final profile = (env.notifier.state as AuthPinSetupRequired).profile;
      expect(profile.email, 'budi@warung.id');

      // Profil ter-cache ke Drift.
      final cached = await env.db.getUser('user-1');
      expect(cached, isNotNull);
      expect(cached!.name, 'Budi');
      expect((await env.db.getStore('store-1'))!.name, 'Warung Barokah');
    });

    test('login 200 + PIN sudah ada → state authenticated', () async {
      final env = makeNotifier((options) => ok(options, authSuccessBody()));
      await env.session.savePinHash(pin: '123456', userId: 'user-1');

      await env.notifier.login(email: 'budi@warung.id', password: 'rahasia123');

      expect(env.notifier.state, isA<AuthAuthenticated>());
    });

    test('register 201 → token tersimpan + state pinSetupRequired', () async {
      final env = makeNotifier(
        (options) => ok(options, authSuccessBody(), 201),
      );

      await env.notifier.register(
        storeName: 'Warung Barokah',
        ownerName: 'Budi',
        email: 'budi@warung.id',
        password: 'rahasia123',
      );

      final tokens = await env.session.readTokens();
      expect(tokens.accessToken, 'access-123');
      expect(env.notifier.state, isA<AuthPinSetupRequired>());
      expect((await env.db.getUser('user-1'))!.email, 'budi@warung.id');
    });

    test('bootstrap tanpa token → unauthenticated', () async {
      final env = makeNotifier((options) => ok(options, authSuccessBody()));

      await env.notifier.bootstrap();

      expect(env.notifier.state, isA<AuthUnauthenticated>());
    });

    test('refresh memutar token tersimpan', () async {
      final env = makeNotifier((options) {
        if (options.path == '/api/v1/auth/refresh') {
          return ok(options, {
            'accessToken': 'access-baru',
            'refreshToken': 'refresh-baru',
          });
        }
        return ok(options, authSuccessBody());
      });

      await env.notifier.login(email: 'budi@warung.id', password: 'rahasia123');
      await env.notifier.refresh();

      final rotated = await env.session.readTokens();
      expect(rotated.accessToken, 'access-baru');
      expect(rotated.refreshToken, 'refresh-baru');
    });

    test('refresh 401 (revoked) → token dibersihkan + login ulang', () async {
      final env = makeNotifier((options) {
        if (options.path == '/api/v1/auth/refresh') {
          return fail(options, 401, {'error': 'invalid refresh token'});
        }
        return ok(options, authSuccessBody());
      });

      await env.notifier.login(email: 'budi@warung.id', password: 'rahasia123');
      await env.notifier.refresh();

      final tokens = await env.session.readTokens();
      expect(tokens.accessToken, isNull);
      expect(tokens.refreshToken, isNull);
      expect(tokens.profileJson, isNull);
      expect(env.notifier.state, isA<AuthUnauthenticated>());
      expect(env.notifier.state.error, contains('login ulang'));
    });
  });

  group('widget (mock Dio)', () {
    testWidgets('login 401 → pesan error tampil', (tester) async {
      final env = makeNotifier(
        (options) => fail(options, 401, {'error': 'wrong credentials'}),
      );
      await pumpAuthScreen(tester, const LoginScreen(), env.container);
      await tester.enterText(
        find.byKey(const Key('emailField')),
        'budi@warung.id',
      );
      await tester.enterText(
        find.byKey(const Key('passwordField')),
        'salah1234',
      );
      await tester.tap(find.byKey(const Key('loginButton')));
      await tester.pumpAndSettle();

      expect(find.text('Email atau password salah'), findsOneWidget);
      expect(env.notifier.state, isA<AuthUnauthenticated>());
    });

    testWidgets('register 409 → pesan "email sudah terdaftar"', (
      tester,
    ) async {
      final env = makeNotifier(
        (options) => fail(options, 409, {'error': 'email taken'}),
      );
      await pumpAuthScreen(tester, const RegisterScreen(), env.container);

      await tester.enterText(
        find.byKey(const Key('storeField')),
        'Warung Barokah',
      );
      await tester.enterText(find.byKey(const Key('ownerField')), 'Budi');
      await tester.enterText(
        find.byKey(const Key('emailField')),
        'budi@warung.id',
      );
      await tester.enterText(
        find.byKey(const Key('passwordField')),
        'rahasia123',
      );
      await tester.enterText(
        find.byKey(const Key('confirmField')),
        'rahasia123',
      );
      await tester.tap(find.byKey(const Key('registerButton')));
      await tester.pumpAndSettle();

      expect(find.text('Email sudah terdaftar'), findsOneWidget);
    });

    testWidgets('home: ketuk Keluar → konfirmasi → sesi terhapus', (
      tester,
    ) async {
      final env = makeNotifier((options) => ok(options, authSuccessBody()));
      await tester.runAsync(() async {
        await env.notifier.login(
          email: 'budi@warung.id',
          password: 'rahasia123',
        );
        await env.notifier.completePinSetup(
          pin: '123456',
          confirmPin: '123456',
        );
      });
      expect(env.notifier.state, isA<AuthAuthenticated>());
      // Alur produksi: Kasir (dalam ShellRoute) → drawer → Keluar.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: env.container,
          child: MaterialApp.router(
            routerConfig: buildRouter(
              initialLocation: '/sales',
              authSnapshot: () => env.container.read(authProvider),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tombol Keluar kini di drawer navigasi.
      await tester.tap(find.byKey(const Key('navDrawerButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('logoutButton')));
      await tester.pumpAndSettle();
      // Dialog konfirmasi 2 langkah.
      expect(find.text('Keluar dari akun?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirmLogoutButton')));
      await tester.pumpAndSettle();

      expect(env.notifier.state, isA<AuthUnauthenticated>());
      final tokens = await env.session.readTokens();
      expect(tokens.accessToken, isNull);
      expect(tokens.profileJson, isNull);
    });
  });
}
