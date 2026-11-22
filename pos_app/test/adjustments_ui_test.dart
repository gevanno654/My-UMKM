import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/db/app_db.dart';
import 'package:pos_app/core/router.dart';
import 'package:pos_app/features/auth/auth_provider.dart';
import 'package:pos_app/features/auth/auth_state.dart';
import 'package:pos_app/features/products/products_provider.dart';

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

/// Seeding Drift HARUS di dalam tester.runAsync.
Future<ProviderContainer> makeOpname(WidgetTester tester) async {
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
        stock: const Value(10),
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
  // Boot katalog agar ProductDetailScreen menemukan produk.
  await tester.runAsync(() async {
    await container.read(productsProvider.notifier).load('store-1');
  });
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
  group('dialog sesuaikan stok', () {
    testWidgets('simpan fisik + alasan -> stok tampil baru', (tester) async {
      final container = await makeOpname(tester);
      await pumpAt(tester, container, '/products/p1');

      await tester.tap(find.byKey(const Key('adjustButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(
        find.byKey(const Key('physicalField')),
        '14',
      );
      await tester.enterText(
        find.byKey(const Key('reasonField')),
        'selip',
      );
      await tester.tap(find.byKey(const Key('saveAdjustButton')));
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      expect(find.byKey(const Key('physicalField')), findsNothing);      expect(find.text('Stok: 14'), findsOneWidget);
    });

    testWidgets('fisik == stok -> pesan tidak ada perubahan', (tester) async {
      final container = await makeOpname(tester);
      await pumpAt(tester, container, '/products/p1');

      await tester.tap(find.byKey(const Key('adjustButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(
        find.byKey(const Key('physicalField')),
        '10',
      );
      await tester.enterText(
        find.byKey(const Key('reasonField')),
        'cek',
      );
      await tester.tap(find.byKey(const Key('saveAdjustButton')));
      await tester.pump();

      expect(find.byKey(const Key('adjustErrorText')), findsOneWidget);
      expect(
        find.textContaining('tidak ada perubahan'),
        findsOneWidget,
      );
    });

    testWidgets('alasan kosong -> pesan wajib isi', (tester) async {
      final container = await makeOpname(tester);
      await pumpAt(tester, container, '/products/p1');

      await tester.tap(find.byKey(const Key('adjustButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(
        find.byKey(const Key('physicalField')),
        '12',
      );
      await tester.tap(find.byKey(const Key('saveAdjustButton')));
      await tester.pump();

      expect(find.byKey(const Key('adjustErrorText')), findsOneWidget);
    });
  });

  group('layar opname', () {
    testWidgets('riwayat + sinkron + void butuh alasan', (tester) async {
      final container = await makeOpname(tester);
      final db = container.read(appDbProvider);
      await tester.runAsync(() async {
        await db.saveAdjustmentFull(
          adjustment: AdjustmentsCompanion.insert(
            id: 'a1',
            storeId: 'store-1',
            productId: const Value('p1'),
            name: 'Indomie',
            stockBefore: 10,
            stockAfter: 14,
            diff: 4,
            reason: 'selip',
            createdAt: 2,
          ),
          physicalStock: 14,
        );
      });
      await pumpAt(tester, container, '/adjustments');

      expect(find.textContaining('selip'), findsOneWidget);
      // Sync per halaman dihapus: sinkron hanya via Sinkron Semua di Home.
      expect(find.byKey(const Key('syncButton')), findsNothing);

      await tester.tap(find.byKey(const Key('void-a1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('voidButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Void tanpa alasan ditolak -> snackbar error,
      // baris belum BATAL.
      expect(find.text('Alasan batal wajib diisi'), findsWidgets);
      expect(find.text('BATAL'), findsNothing);
    });
  });
}
