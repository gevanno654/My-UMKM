import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/db/app_db.dart';
import 'package:pos_app/core/router.dart';
import 'package:pos_app/core/session/secure_session.dart';
import 'package:pos_app/features/auth/auth_provider.dart';
import 'package:pos_app/features/auth/auth_state.dart';

/// Auth state palsu: langsung terautentikasi (untuk boot layar).
class _FakeAuthNotifier extends AuthNotifier {
  static AuthProfile? profile;

  @override
  AuthState build() {
    final p = profile;
    if (p == null) return const AuthUnauthenticated();
    return AuthAuthenticated(p);
  }
}

final _kProfile = AuthProfile(
  id: 'user-1',
  storeId: 'store-1',
  name: 'Budi',
  email: 'budi@warung.id',
  storeName: 'Toko Evan',
);

/// Storage in-memory untuk test (tanpa binding platform).
class _MemStorage implements SecureStorage {
  final map = <String, String?>{};

  @override
  Future<String?> read(String key) async => map[key];

  @override
  Future<void> write(String key, String? value) async => map[key] = value;

  @override
  Future<void> delete(String key) async => map.remove(key);

  @override
  Future<void> deleteAll() async => map.clear();
}

Future<ProviderContainer> makeHome(WidgetTester tester) async {
  late AppDb db;
  await tester.runAsync(() async {
    db = AppDb.openMemory();
    await db.upsertStore(
      LocalStoresCompanion.insert(serverId: 'store-1', name: 'Toko Evan'),
    );
  });
  addTearDown(db.close);
  _FakeAuthNotifier.profile = _kProfile;
  addTearDown(() => _FakeAuthNotifier.profile = null);
  final container = ProviderContainer(
    overrides: [
      appDbProvider.overrideWithValue(db),
      authProvider.overrideWith(_FakeAuthNotifier.new),
      secureSessionProvider.overrideWithValue(
        SecureSession(storage: _MemStorage()),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> pumpAt(
  WidgetTester tester,
  ProviderContainer container,
  String location,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: buildRouter(
          initialLocation: location,
          authSnapshot: () => container.read(authProvider),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('tombol sinkron', () {
    testWidgets('home punya Sinkron Semua; halaman lain tanpa sync', (
      tester,
    ) async {
      final container = await makeHome(tester);
      await pumpAt(tester, container, '/home');

      expect(find.byKey(const Key('syncAllButton')), findsOneWidget);

      await pumpAt(tester, container, '/products');
      expect(find.byKey(const Key('syncButton')), findsNothing);

      await pumpAt(tester, container, '/sales/history');
      expect(find.byKey(const Key('syncButton')), findsNothing);

      await pumpAt(tester, container, '/restocks');
      expect(find.byKey(const Key('syncButton')), findsNothing);

      await pumpAt(tester, container, '/adjustments');
      expect(find.byKey(const Key('syncButton')), findsNothing);
    });
  });
}
