import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/db/app_db.dart';
import 'package:pos_app/core/router.dart';
import 'package:pos_app/features/auth/auth_provider.dart';
import 'package:pos_app/features/auth/auth_state.dart';
import 'package:pos_app/features/restocks/restocks_provider.dart';

/// Auth state palsu: langsung terautentikasi (untuk boot layar restock).
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
Future<ProviderContainer> makeRestock(WidgetTester tester) async {
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
  return container;
}

Future<void> pumpRestocks(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: buildRouter(
          initialLocation: '/restocks',
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

Future<void> openDraft(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('kulakanButton')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('layar restock', () {
    testWidgets('tambah produk via search -> baris + total modal tampil',
        (tester) async {
      final container = await makeRestock(tester);
      await pumpRestocks(tester, container);
      await openDraft(tester);

      await tester.enterText(
        find.byKey(const Key('restockSearchField')),
        'Indo',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Indomie').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('draftLine-p1')), findsOneWidget);
      expect(find.textContaining('2.500'), findsWidgets);
    });

    testWidgets('opsi ubah harga jual tidak tampil (ditunda ke v2)',
        (tester) async {
      final container = await makeRestock(tester);
      await pumpRestocks(tester, container);
      await openDraft(tester);

      await tester.enterText(
        find.byKey(const Key('restockSearchField')),
        'Indo',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Indomie').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('updateSell-p1')), findsNothing);
      expect(find.byKey(const Key('sellPriceField-p1')), findsNothing);
    });

    testWidgets('ubah harga beli -> total modal berubah live', (tester) async {
      final container = await makeRestock(tester);
      await pumpRestocks(tester, container);
      await openDraft(tester);

      await tester.enterText(
        find.byKey(const Key('restockSearchField')),
        'Indo',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Indomie').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.ensureVisible(find.byKey(const Key('costPriceField-p1')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('costPriceField-p1')),
        '2600',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('2.600'), findsWidgets);
    });

    testWidgets('ubah harga beli lalu simpan -> katalog ikut harga baru',
        (tester) async {
      final container = await makeRestock(tester);
      await pumpRestocks(tester, container);
      await openDraft(tester);

      await tester.enterText(
        find.byKey(const Key('restockSearchField')),
        'Indo',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Indomie').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.ensureVisible(find.byKey(const Key('costPriceField-p1')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('costPriceField-p1')),
        '2600',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byKey(const Key('saveRestockButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Riwayat pakai harga baru (1 x 2600), bukan harga lama 2500.
      expect(find.textContaining('2.600'), findsWidgets);
      await tester.runAsync(() async {
        final p =
            await container.read(appDbProvider).getProduct('p1');
        expect(p!.costPrice, 2600);
      });
    });

    testWidgets('tombol scan tersedia di draft', (tester) async {
      final container = await makeRestock(tester);
      await pumpRestocks(tester, container);
      await openDraft(tester);

      expect(find.byTooltip('Scan barcode'), findsOneWidget);
    });

    testWidgets('simpan -> riwayat tampil total modal benar', (tester) async {
      final container = await makeRestock(tester);
      await pumpRestocks(tester, container);
      await openDraft(tester);

      await tester.enterText(
        find.byKey(const Key('restockSearchField')),
        'Indo',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Indomie').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byKey(const Key('saveRestockButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Kembali ke daftar: riwayat 1 baris dengan total 2500.
      expect(find.textContaining('2.500'), findsWidgets);
    });

    testWidgets('riwayat -> detail -> batal butuh alasan', (tester) async {
      final container = await makeRestock(tester);
      // Seed restock via provider langsung.
      await tester.runAsync(() async {
        final notifier = container.read(restocksProvider.notifier);
        await notifier.load('store-1');
        await notifier.addToDraft('p1', qty: 2);
        await notifier.saveRestock();
      });
      await pumpRestocks(tester, container);

      await tester.tap(find.byType(ListTile).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byKey(const Key('voidRestockButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('voidReasonField')), findsOneWidget);
    });
  });
}

