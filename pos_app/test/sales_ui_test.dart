import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/db/app_db.dart';
import 'package:pos_app/core/router.dart';
import 'package:pos_app/features/auth/auth_provider.dart';
import 'package:pos_app/features/auth/auth_state.dart';
import 'package:pos_app/features/sales/sale_model.dart';
import 'package:pos_app/features/sales/sales_provider.dart';

/// Auth state palsu: langsung terautentikasi (untuk boot layar kasir).
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

/// Seeding Drift HARUS di dalam tester.runAsync (zona fake-async
/// testWidgets tidak bisa await future isolate SQLite langsung).
Future<ProviderContainer> makeKasir(WidgetTester tester) async {
  late AppDb db;
  await tester.runAsync(() async {
    db = AppDb.openMemory();
    await db.upsertProduct(
      ProductsCompanion.insert(
        id: 'p1',
        storeId: 'store-1',
        name: 'Indomie',
        barcode: const Value.absent(),
        costPrice: 2500,
        sellPrice: 3500,
        stock: const Value(5),
        createdAt: 1,
        updatedAt: 1,
      ),
    );
  });
  addTearDown(db.close);
  _FakeAuthNotifier.profile = _kProfile;
  addTearDown(() => _FakeAuthNotifier.profile = null);
  final container = ProviderContainer(
    overrides: [
      appDbProvider.overrideWithValue(db),
      authProvider.overrideWith(_FakeAuthNotifier.new),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> pumpKasir(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: buildRouter(
          authSnapshot: () => container.read(authProvider),
        ),
      ),
    ),
  );
  // Boot layar async (postFrame + Drift): pump manual + runAsync delay,
  // bukan pumpAndSettle (spinner/timer tak berujung menggantung).
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('layar kasir', () {
    testWidgets('tambah item via search + total tampil', (tester) async {
      final container = await makeKasir(tester);
      await pumpKasir(tester, container);

      expect(find.text('Halo, Budi!'), findsOneWidget);

      await tester.tap(find.byKey(const Key('kasirButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(find.byKey(const Key('kasirSearchField')), 'Indo');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Indomie').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Indomie').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Rp7.000'), findsWidgets);
    });

    testWidgets('bayar tunai -> struk tampil (nomor TE + kembalian)', (
      tester,
    ) async {
      final container = await makeKasir(tester);
      await tester.runAsync(() async {
        final notifier = container.read(salesProvider.notifier);
        await notifier.load('store-1', storeName: 'Toko Evan');
        await notifier.addItem('p1', 2);
      });
      await pumpKasir(tester, container);

      await tester.tap(find.byKey(const Key('kasirButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const Key('payButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byKey(const Key('paidField')), '10000');
      await tester.pump();
      await tester.tap(find.byKey(const Key('confirmPayButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('TE'), findsWidgets);
      expect(find.textContaining('3.000'), findsWidgets);
    });

    testWidgets('riwayat tampil setelah checkout', (tester) async {
      final container = await makeKasir(tester);
      await tester.runAsync(() async {
        final notifier = container.read(salesProvider.notifier);
        await notifier.load('store-1', storeName: 'Toko Evan');
        await notifier.addItem('p1', 1);
        await notifier.checkout(paid: 3500, method: PayMethod.tunai);
      });
      await pumpKasir(tester, container);

      await tester.tap(find.byKey(const Key('kasirButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const Key('historyButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('TE'), findsWidgets);
    });

    testWidgets('void butuh alasan', (tester) async {
      final container = await makeKasir(tester);
      await tester.runAsync(() async {
        final notifier = container.read(salesProvider.notifier);
        await notifier.load('store-1', storeName: 'Toko Evan');
        await notifier.addItem('p1', 1);
        await notifier.checkout(paid: 3500, method: PayMethod.tunai);
      });
      await pumpKasir(tester, container);

      await tester.tap(find.byKey(const Key('kasirButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const Key('historyButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const Key('voidButton')).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const Key('confirmVoidButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Alasan void wajib diisi'), findsOneWidget);
    });
  });
}
