import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/db/app_db.dart';
import 'package:pos_app/features/auth/auth_provider.dart';
import 'package:pos_app/features/reports/reports_provider.dart';
import 'package:pos_app/features/sales/sales_provider.dart'
    as sales_feature;

Future<({ReportsNotifier notifier, AppDb db})> makeReports({
  DateTime? now,
}) async {
  final container = ProviderContainer(
    overrides: [appDbProvider.overrideWithValue(AppDb.openMemory())],
  );
  addTearDown(container.dispose);
  final db = container.read(appDbProvider);
  addTearDown(db.close);
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
  final notifier = container.read(reportsProvider.notifier);
  await notifier.load('store-1');
  return (notifier: notifier, db: db);
}

Future<void> seedSale(
  AppDb db, {
  required String id,
  required int createdAtMillis,
  int qty = 2,
  String status = 'ok',
}) async {
  await db.checkoutSale(
    sale: SalesCompanion.insert(
      id: id,
      storeId: 'store-1',
      number: id,
      total: 3500 * qty,
      paid: 3500 * qty,
      change: const Value(0),
      method: 'tunai',
      status: Value(status),
      createdAt: createdAtMillis,
    ),
    items: [
      SaleItemsCompanion.insert(
        id: 'i-$id',
        saleId: id,
        productId: const Value('p1'),
        name: 'Indomie',
        price: 3500,
        costPrice: const Value(2500),
        qty: qty,
        subtotal: 3500 * qty,
      ),
    ],
  );
}

void main() {
  group('rangeOf', () {
    test('mingguan = Senin-Minggu walau anchor akhir pekan', () {
      // Minggu 22 Nov 2026 -> Senin 16 Nov s.d. Senin 23 Nov.
      final range = rangeOf(ReportPeriod.week, DateTime(2026, 11, 22, 12));
      final start = DateTime.fromMillisecondsSinceEpoch(range.startMillis);
      final end = DateTime.fromMillisecondsSinceEpoch(range.endMillis);
      expect(start.weekday, DateTime.monday);
      expect(start.day, 16);
      expect(end.day, 23);
    });

    test('bulanan = tanggal 1 s.d. awal bulan berikut', () {
      final range = rangeOf(ReportPeriod.month, DateTime(2026, 11, 23, 12));
      final start = DateTime.fromMillisecondsSinceEpoch(range.startMillis);
      final end = DateTime.fromMillisecondsSinceEpoch(range.endMillis);
      expect(start.day, 1);
      expect(start.month, 11);
      expect(end.month, 12);
      expect(end.day, 1);
    });
  });

  group('agregasi', () {
    test('ringkasan harian abaikan void + laba dari snapshot', () async {
      final env = await makeReports();
      final today = DateTime.now().millisecondsSinceEpoch;
      await seedSale(env.db, id: 'ok1', createdAtMillis: today, qty: 2);
      await seedSale(
        env.db,
        id: 'void1',
        createdAtMillis: today,
        qty: 1,
        status: 'voided',
      );
      await env.notifier.load('store-1');

      final summary = env.notifier.state.summary;
      expect(summary.revenue, 7000);
      expect(summary.profit, 2000); // (3500-2500)*2
      expect(summary.txCount, 1);
      expect(summary.avgTicket, 7000);
      expect(env.notifier.state.sales.length, 1);
      expect(
        env.notifier.state.topProducts.single,
        predicate<TopProduct>((t) => t.name == 'Indomie' && t.qty == 2),
      );
    });
  });
}
