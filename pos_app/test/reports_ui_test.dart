import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/db/app_db.dart';
import 'package:pos_app/core/router.dart';
import 'package:pos_app/core/session/secure_session.dart';
import 'package:pos_app/features/auth/auth_provider.dart';
import 'package:pos_app/features/auth/auth_state.dart';

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

Future<ProviderContainer> makeEnv(WidgetTester tester) async {
  late AppDb db;
  await tester.runAsync(() async {
    db = AppDb.openMemory();
    await db.upsertStore(
      LocalStoresCompanion.insert(serverId: 'store-1', name: 'Toko Evan'),
    );
    await db.upsertProduct(
      ProductsCompanion.insert(
        id: 'p1',
        storeId: 'store-1',
        name: 'Indomie',
        barcode: const Value.absent(),
        costPrice: 2500,
        sellPrice: 3500,
        stock: const Value(100),
        createdAt: 1,
        updatedAt: 1,
      ),
    );
    await db.checkoutSale(
      sale: SalesCompanion.insert(
        id: 's-ok',
        storeId: 'store-1',
        number: 's-ok',
        total: 7000,
        paid: 7000,
        change: const Value(0),
        method: 'tunai',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
      items: [
        SaleItemsCompanion.insert(
          id: 'i-ok',
          saleId: 's-ok',
          productId: const Value('p1'),
          name: 'Indomie',
          price: 3500,
          costPrice: const Value(2500),
          qty: 2,
          subtotal: 7000,
        ),
      ],
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
  group('laporan UI', () {
    testWidgets('home punya Laporan -> layar tampil ringkasan + chart', (
      tester,
    ) async {
      final container = await makeEnv(tester);
      await pumpAt(tester, container, '/home');

      await tester.tap(find.byKey(const Key('reportsButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('revenueValue')), findsOneWidget);
      expect(find.byKey(const Key('profitValue')), findsOneWidget);
      expect(find.textContaining('7.000'), findsWidgets);
      // Chart berada di bawah viewport: ListView membangunnya lazy.
      // Geser dulu agar item ter-build, bukan drag pada finder tak-ketemunya.
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pump();
      expect(find.byKey(const Key('profitChart')), findsOneWidget);
    });

    testWidgets('pemilih periode + navigasi mengubah judul rentang', (
      tester,
    ) async {
      final container = await makeEnv(tester);
      await pumpAt(tester, container, '/reports');

      await tester.tap(find.byKey(const Key('periodWeekButton')));
      await tester.pump();
      expect(find.byKey(const Key('rangeLabel')), findsOneWidget);

      await tester.tap(find.byKey(const Key('prevPeriodButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('rangeLabel')), findsOneWidget);

      await tester.tap(find.byKey(const Key('todayButton')));
      await tester.pump();
      expect(find.byKey(const Key('periodDayButton')), findsOneWidget);
    });
  });
}
