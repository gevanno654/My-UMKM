import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/db/app_db.dart';

/// Helper baris produk untuk test kasir lokal.
ProductsCompanion productRow({
  required String id,
  String storeId = 'store-1',
  required String name,
  int sellPrice = 3500,
  int stock = 10,
}) => ProductsCompanion.insert(
  id: id,
  storeId: storeId,
  name: name,
  barcode: const Value.absent(),
  costPrice: sellPrice,
  sellPrice: sellPrice,
  stock: Value(stock),
  createdAt: 1,
  updatedAt: 1,
);

void main() {
  late AppDb db;

  setUp(() {
    db = AppDb.openMemory();
  });

  tearDown(() async {
    await db.close();
  });

  group('checkout atomik lokal', () {
    test('sale + items tersimpan, stok berkurang, total benar', () async {
      await db.upsertProduct(productRow(id: 'p1', name: 'Indomie'));
      await db.upsertProduct(
        productRow(id: 'p2', name: 'Teh', sellPrice: 3000, stock: 5),
      );

      await db.checkoutSale(
        sale: SalesCompanion.insert(
          id: 's1',
          storeId: 'store-1',
          number: 'TE010120260001',
          total: 10000,
          paid: 10000,
          change: const Value(0),
          method: 'tunai',
          createdAt: 100,
        ),
        items: [
          SaleItemsCompanion.insert(
            id: 'i1',
            saleId: 's1',
            productId: const Value('p1'),
            name: 'Indomie',
            price: 3500,
            qty: 2,
            subtotal: 7000,
          ),
          SaleItemsCompanion.insert(
            id: 'i2',
            saleId: 's1',
            productId: const Value('p2'),
            name: 'Teh',
            price: 3000,
            qty: 1,
            subtotal: 3000,
          ),
        ],
      );

      expect((await db.getProduct('p1'))!.stock, 8);
      expect((await db.getProduct('p2'))!.stock, 4);
      final sales = await db.salesHistory('store-1');
      expect(sales.length, 1);
      expect(sales.first.number, 'TE010120260001');
      final items = await db.saleItemsOf('s1');
      expect(items.length, 2);
    });

    test('stok kurang -> throw, tidak ada sale terbuat', () async {
      await db.upsertProduct(
        productRow(id: 'p1', name: 'Indomie', stock: 1),
      );

      expect(
        () => db.checkoutSale(
          sale: SalesCompanion.insert(
            id: 's1',
            storeId: 'store-1',
            number: 'TE010120260001',
            total: 7000,
            paid: 7000,
            change: const Value(0),
            method: 'tunai',
            createdAt: 100,
          ),
          items: [
            SaleItemsCompanion.insert(
              id: 'i1',
              saleId: 's1',
              productId: const Value('p1'),
              name: 'Indomie',
              price: 3500,
              qty: 2,
              subtotal: 7000,
            ),
          ],
        ),
        throwsStateError,
      );
      expect(await db.salesHistory('store-1'), isEmpty);
      expect((await db.getProduct('p1'))!.stock, 1);
    });
  });

  group('void beraudit', () {
    test('void -> status voided + stok kembali', () async {
      await db.upsertProduct(productRow(id: 'p1', name: 'Indomie'));
      await db.checkoutSale(
        sale: SalesCompanion.insert(
          id: 's1',
          storeId: 'store-1',
          number: 'TE010120260001',
          total: 7000,
          paid: 10000,
          change: const Value(3000),
          method: 'tunai',
          createdAt: 100,
        ),
        items: [
          SaleItemsCompanion.insert(
            id: 'i1',
            saleId: 's1',
            productId: const Value('p1'),
            name: 'Indomie',
            price: 3500,
            qty: 2,
            subtotal: 7000,
          ),
        ],
      );
      expect((await db.getProduct('p1'))!.stock, 8);

      await db.voidSale(id: 's1', reason: 'salah input', nowMillis: 200);

      final sale = await db.getSale('s1');
      expect(sale!.status, 'voided');
      expect(sale.voidReason, 'salah input');
      expect((await db.getProduct('p1'))!.stock, 10);
    });

    test('void tanpa alasan -> throw', () async {
      await db.upsertProduct(productRow(id: 'p1', name: 'Indomie'));
      await db.checkoutSale(
        sale: SalesCompanion.insert(
          id: 's1',
          storeId: 'store-1',
          number: 'TE010120260001',
          total: 3500,
          paid: 3500,
          change: const Value(0),
          method: 'qris',
          createdAt: 100,
        ),
        items: [
          SaleItemsCompanion.insert(
            id: 'i1',
            saleId: 's1',
            productId: const Value('p1'),
            name: 'Indomie',
            price: 3500,
            qty: 1,
            subtotal: 3500,
          ),
        ],
      );

      expect(
        () => db.voidSale(id: 's1', reason: '  ', nowMillis: 200),
        throwsArgumentError,
      );
      expect((await db.getSale('s1'))!.status, 'ok');
    });
  });

  group('nomor struk harian', () {
    test('nextReceiptSeq reset per tanggal', () async {
      await db.upsertProduct(productRow(id: 'p1', name: 'Indomie'));
      Future<void> checkout(String id, String number) => db.checkoutSale(
        sale: SalesCompanion.insert(
          id: id,
          storeId: 'store-1',
          number: number,
          total: 3500,
          paid: 3500,
          change: const Value(0),
          method: 'tunai',
          createdAt: 100,
        ),
        items: [
          SaleItemsCompanion.insert(
            id: 'i-$id',
            saleId: id,
            productId: const Value('p1'),
            name: 'Indomie',
            price: 3500,
            qty: 1,
            subtotal: 3500,
          ),
        ],
      );

      // Tanggal 2026-11-22 (2 transaksi), lalu 2026-11-23 (reset).
      expect(await db.nextReceiptSeq('store-1', '22112026'), 1);
      await checkout('s1', 'TE221120260001');
      expect(await db.nextReceiptSeq('store-1', '22112026'), 2);
      await checkout('s2', 'TE221120260002');
      expect(await db.nextReceiptSeq('store-1', '23112026'), 1);
    });
  });

  group('keranjang persist', () {
    test('tambah/ubah/hapus baris bertahan di DB', () async {
      await db.upsertProduct(productRow(id: 'p1', name: 'Indomie'));

      await db.upsertCartLine(
        CartLinesCompanion.insert(
          storeId: 'store-1',
          productId: 'p1',
          qty: 2,
        ),
      );
      var lines = await db.getCartLines('store-1');
      expect(lines.length, 1);
      expect(lines.first.qty, 2);

      await db.upsertCartLine(
        CartLinesCompanion.insert(
          storeId: 'store-1',
          productId: 'p1',
          qty: 3,
        ),
      );
      lines = await db.getCartLines('store-1');
      expect(lines.length, 1);
      expect(lines.first.qty, 3);

      await db.removeCartLine('store-1', 'p1');
      expect(await db.getCartLines('store-1'), isEmpty);
    });
  });
}

