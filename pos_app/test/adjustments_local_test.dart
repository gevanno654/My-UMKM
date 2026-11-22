import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/db/app_db.dart';

AppDb makeDb() => AppDb.openMemory();

Future<void> seedProduct(AppDb db) => db.upsertProduct(
  ProductsCompanion.insert(
    id: 'p1',
    storeId: 's1',
    name: 'Indomie',
    barcode: const Value.absent(),
    costPrice: 2500,
    sellPrice: 3500,
    stock: const Value(10),
    createdAt: 1,
    updatedAt: 1,
  ),
);

AdjustmentsCompanion adjOf({
  required String id,
  int stockBefore = 10,
  int stockAfter = 14,
  int diff = 4,
  String reason = 'selip',
  int createdAt = 2,
}) => AdjustmentsCompanion.insert(
  id: id,
  storeId: 's1',
  productId: const Value('p1'),
  name: 'Indomie',
  stockBefore: stockBefore,
  stockAfter: stockAfter,
  diff: diff,
  reason: reason,
  createdAt: createdAt,
);

void main() {
  group('penyesuaian stok lokal (opname)', () {
    test('simpan fisik naik 10 -> 14: stok 14, diff +4, produk dirty', () async {
      final db = makeDb();
      addTearDown(db.close);
      await seedProduct(db);

      await db.saveAdjustmentFull(
        adjustment: adjOf(id: 'a1'),
        physicalStock: 14,
      );

      final p = await db.getProduct('p1');
      expect(p!.stock, 14);
      expect(p.dirty, 1);
      final rows = await db.adjustmentsHistory('s1');
      expect(rows.single.diff, 4);
    });

    test('simpan fisik turun 14 -> 11: diff -3', () async {
      final db = makeDb();
      addTearDown(db.close);
      await seedProduct(db);

      await db.saveAdjustmentFull(
        adjustment: adjOf(id: 'a1'),
        physicalStock: 14,
      );
      await db.saveAdjustmentFull(
        adjustment: adjOf(
          id: 'a2',
          stockBefore: 14,
          stockAfter: 11,
          diff: -3,
          reason: 'rusak',
          createdAt: 3,
        ),
        physicalStock: 11,
      );

      expect((await db.getProduct('p1'))!.stock, 11);
    });

    test('diff 0 -> ArgumentError, stok tidak berubah', () async {
      final db = makeDb();
      addTearDown(db.close);
      await seedProduct(db);

      await expectLater(
        db.saveAdjustmentFull(
          adjustment: adjOf(
            id: 'a1',
            stockBefore: 10,
            stockAfter: 10,
            diff: 0,
            reason: 'cek',
          ),
          physicalStock: 10,
        ),
        throwsArgumentError,
      );
      expect((await db.getProduct('p1'))!.stock, 10);
    });

    test('alasan kosong -> ArgumentError', () async {
      final db = makeDb();
      addTearDown(db.close);
      await seedProduct(db);

      expect(
        () => db.saveAdjustmentFull(
          adjustment: adjOf(id: 'a1', reason: '  '),
          physicalStock: 12,
        ),
        throwsArgumentError,
      );
    });

    test('produk tidak ada -> StateError, tidak ada yang berubah', () async {
      final db = makeDb();
      addTearDown(db.close);
      await seedProduct(db);

      await expectLater(
        db.saveAdjustmentFull(
          adjustment: AdjustmentsCompanion.insert(
            id: 'a1',
            storeId: 's1',
            productId: const Value('hilang'),
            name: '?',
            stockBefore: 0,
            stockAfter: 5,
            diff: 5,
            reason: 'x',
            createdAt: 2,
          ),
          physicalStock: 5,
        ),
        throwsStateError,
      );
      expect((await db.getProduct('p1'))!.stock, 10);
    });

    test('void ok: status voided, stok kembali', () async {
      final db = makeDb();
      addTearDown(db.close);
      await seedProduct(db);

      await db.saveAdjustmentFull(
        adjustment: adjOf(id: 'a1'),
        physicalStock: 14,
      );
      await db.voidAdjustment(
        id: 'a1',
        reason: 'salah hitung',
        nowMillis: 3,
      );

      expect((await db.getProduct('p1'))!.stock, 10);
      final rows = await db.adjustmentsHistory('s1');
      expect(rows.single.status, 'voided');
      expect(rows.single.voidReason, 'salah hitung');
    });

    test('void tanpa alasan -> ArgumentError', () async {
      final db = makeDb();
      addTearDown(db.close);
      await seedProduct(db);

      expect(
        () => db.voidAdjustment(id: 'a1', reason: ' ', nowMillis: 3),
        throwsArgumentError,
      );
    });

    test('void saat stok kurang -> StateError, stok tidak berubah', () async {
      final db = makeDb();
      addTearDown(db.close);
      await seedProduct(db);

      await db.saveAdjustmentFull(
        adjustment: adjOf(id: 'a1'),
        physicalStock: 14,
      );
      // Jual 11 dari 14 -> sisa 3 < diff 4.
      await db.checkoutSale(
        sale: SalesCompanion.insert(
          id: 'sale1',
          storeId: 's1',
          number: 'N1',
          total: 11 * 3500,
          paid: 11 * 3500,
          method: 'tunai',
          createdAt: 3,
        ),
        items: [
          SaleItemsCompanion.insert(
            id: 'i1',
            saleId: 'sale1',
            productId: const Value('p1'),
            name: 'Indomie',
            price: 3500,
            qty: 11,
            subtotal: 11 * 3500,
          ),
        ],
      );

      await expectLater(
        db.voidAdjustment(id: 'a1', reason: 'batal', nowMillis: 4),
        throwsStateError,
      );
      expect((await db.getProduct('p1'))!.stock, 3);
    });
  });
}
