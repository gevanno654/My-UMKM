import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/db/app_db.dart';
import 'package:pos_app/core/router.dart';
import 'package:pos_app/core/session/secure_session.dart';
import 'package:pos_app/features/auth/auth_provider.dart';

/// In-memory fake dari [SecureStorage] agar test tidak menyentuh
/// platform channel (flutter_secure_storage).
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
  Future<void> delete(String key) async {
    _data.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _data.clear();
  }
}

void main() {
  group('AppDb', () {
    late AppDb db;

    setUp(() {
      db = AppDb.openMemory();
    });

    tearDown(() async {
      await db.close();
    });

    test('insert + read store', () async {
      await db.upsertStore(
        LocalStoresCompanion.insert(
          serverId: 'store-1',
          name: 'Warung Barokah',
        ),
      );

      final store = await db.getStore('store-1');

      expect(store, isNotNull);
      expect(store!.serverId, 'store-1');
      expect(store.name, 'Warung Barokah');
    });

    test('insert + read user', () async {
      await db.upsertUser(
        LocalUsersCompanion.insert(
          serverId: 'user-1',
          storeId: 'store-1',
          name: 'Budi',
          email: 'budi@warung.id',
        ),
      );

      final user = await db.getUser('user-1');

      expect(user, isNotNull);
      expect(user!.serverId, 'user-1');
      expect(user.storeId, 'store-1');
      expect(user.name, 'Budi');
      expect(user.email, 'budi@warung.id');
    });
  });

  group('SecureSession', () {
    test('save/read tokens round-trip', () async {
      final session = SecureSession(storage: MemorySecureStorage());

      await session.saveTokens(
        accessToken: 'access-123',
        refreshToken: 'refresh-456',
        profileJson: '{"name":"Budi"}',
      );
      final tokens = await session.readTokens();

      expect(tokens.accessToken, 'access-123');
      expect(tokens.refreshToken, 'refresh-456');
      expect(tokens.profileJson, '{"name":"Budi"}');
    });

    test('savePinHash menyimpan hash, bukan plaintext', () async {
      final session = SecureSession(storage: MemorySecureStorage());

      await session.savePinHash(pin: '123456', userId: 'user-1');
      final hash = await session.readPinHash('user-1');

      expect(hash, isNotNull);
      expect(hash, isNot('123456'));
      expect(hash, isNotEmpty);
    });

    test('clear menghapus semua sesi termasuk PIN', () async {
      final session = SecureSession(storage: MemorySecureStorage());

      await session.saveTokens(
        accessToken: 'access-123',
        refreshToken: 'refresh-456',
      );
      await session.savePinHash(pin: '123456', userId: 'user-1');
      await session.clear();
      final tokens = await session.readTokens();

      expect(tokens.accessToken, isNull);
      expect(tokens.refreshToken, isNull);
      expect(await session.readPinHash('user-1'), isNull);
      expect(tokens.profileJson, isNull);
    });
  });

  group('router', () {
    const expectedPaths = [
      '/splash',
      '/login',
      '/register',
      '/pin-setup',
      '/pin-unlock',
      '/home',
      '/products',
      '/products/new',
      '/products/scan',
      '/products/:id',
      '/products/:id/edit',
      '/sales',
      '/sales/pay',
      '/sales/receipt',
      '/sales/history',
      '/restocks',
      '/restocks/new',
      '/restocks/:id',
    ];

    test('memetakan 18 route', () {
      expect(appRoutePaths, unorderedEquals(expectedPaths));
    });

    // PIN sudah screen asli (Task 5): butuh ProviderScope karena ConsumerWidget.
    for (final entry in {
      '/pin-setup': 'Buat PIN',
      '/pin-unlock': 'Buka dengan PIN',
    }.entries) {
      testWidgets('route ${entry.key} membangun screen PIN', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp.router(
              routerConfig: buildRouter(initialLocation: entry.key),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(entry.value), findsWidgets);
      });
    }

    testWidgets('route /splash menampilkan loading', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: buildRouter(initialLocation: '/splash'),
          ),
        ),
      );
      await tester.pump();

      // Splash langsung menampilkan indikator; redirect terjadi setelah frame.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    for (final entry in {'/login': 'Masuk', '/register': 'Daftar'}.entries) {
      testWidgets('route ${entry.key} membangun screen ${entry.value}', (
        tester,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp.router(
              routerConfig: buildRouter(initialLocation: entry.key),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(entry.value), findsWidgets);
      });
    }

    testWidgets('route /home membangun HomePlaceholder', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: buildRouter(initialLocation: '/home'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Halo,'), findsOneWidget);
    });

    testWidgets('logout otomatis redirect ke /login tanpa navigasi manual', (
      tester,
    ) async {
      late AppDb db;
      await tester.runAsync(() async {
        db = AppDb.openMemory();
      });
      final container = ProviderContainer(
        overrides: [
          appDbProvider.overrideWithValue(db),
          secureSessionProvider.overrideWithValue(
            SecureSession(storage: MemorySecureStorage()),
          ),
        ],
      );
      // Cerminkan wiring produksi: setiap perubahan auth me-refresh router.
      final refresh = ChangeNotifier();
      final sub = container.listen(authProvider, (prev, next) {
        refresh.notifyListeners();
      });
      addTearDown(() async {
        sub.close();
        refresh.dispose();
        container.dispose();
        await db.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: buildRouter(
              initialLocation: '/home',
              authSnapshot: () => container.read(authProvider),
              refreshListenable: refresh,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Halo,'), findsOneWidget);

      await tester.runAsync(() async {
        await container.read(authProvider.notifier).logout();
      });
      await tester.pumpAndSettle();

      expect(find.text('Masuk'), findsWidgets);
      expect(find.textContaining('Halo,'), findsNothing);
    });
  });
}
