import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/db/app_db.dart';
import 'package:pos_app/features/products/product_model.dart';

/// Helper baris produk untuk test repo lokal.
ProductsCompanion productRow({
  required String id,
  String storeId = 'store-1',
  required String name,
  String? barcode,
  int costPrice = 5000,
  int sellPrice = 7000,
  int stock = 10,
  String category = '',
  bool archived = false,
  int createdAt = 1,
  int updatedAt = 1,
}) => ProductsCompanion.insert(
  id: id,
  storeId: storeId,
  name: name,
  barcode: Value(barcode),
  costPrice: costPrice,
  sellPrice: sellPrice,
  stock: Value(stock),
  category: Value(category),
  isArchived: Value(archived),
  createdAt: createdAt,
  updatedAt: updatedAt,
);

void main() {
  late AppDb db;

  setUp(() {
    db = AppDb.openMemory();
  });

  tearDown(() async {
    await db.close();
  });

  group('ProductModel', () {
    test('normalizeBarcode: trim dan string kosong menjadi null', () {
      expect(ProductModel.normalizeBarcode(null), isNull);
      expect(ProductModel.normalizeBarcode(''), isNull);
      expect(ProductModel.normalizeBarcode('   '), isNull);
      expect(ProductModel.normalizeBarcode('  899123  '), '899123');
    });

    test('validate: nama kosong ditolak', () {
      expect(
        ProductModel.validate(
          name: '',
          costPrice: 1000,
          sellPrice: 1500,
          stock: 5,
        ),
        isNotNull,
      );
      expect(
        ProductModel.validate(
          name: '   ',
          costPrice: 1000,
          sellPrice: 1500,
          stock: 5,
        ),
        isNotNull,
      );
    });

    test('validate: harga -1 ditolak', () {
      expect(
        ProductModel.validate(
          name: 'Gula',
          costPrice: -1,
          sellPrice: 1500,
          stock: 5,
        ),
        isNotNull,
      );
      expect(
        ProductModel.validate(
          name: 'Gula',
          costPrice: 1000,
          sellPrice: -1,
          stock: 5,
        ),
        isNotNull,
      );
    });

    test('validate: stok -1 ditolak', () {
      expect(
        ProductModel.validate(
          name: 'Gula',
          costPrice: 1000,
          sellPrice: 1500,
          stock: -1,
        ),
        isNotNull,
      );
    });

    test('validate: data valid lolos', () {
      expect(
        ProductModel.validate(
          name: 'Gula Pasir 1kg',
          costPrice: 1000,
          sellPrice: 1500,
          stock: 5,
          category: 'Sembako',
        ),
        isNull,
      );
    });
  });

  group('AppDb produk', () {
    test('insert + read kembali', () async {
      await db.upsertProduct(
        productRow(id: 'p-1', name: 'Gula Pasir 1kg', barcode: '899123'),
      );

      final got = await db.getProduct('p-1');

      expect(got, isNotNull);
      expect(got!.id, 'p-1');
      expect(got.storeId, 'store-1');
      expect(got.name, 'Gula Pasir 1kg');
      expect(got.barcode, '899123');
      expect(got.costPrice, 5000);
      expect(got.sellPrice, 7000);
      expect(got.stock, 10);
      expect(got.dirty, 1);
    });

    test('barcode null ganda boleh (tanpa error unique)', () async {
      await db.upsertProduct(productRow(id: 'p-1', name: 'Gula'));
      await db.upsertProduct(productRow(id: 'p-2', name: 'Kopi'));

      expect((await db.getProduct('p-1'))!.barcode, isNull);
      expect((await db.getProduct('p-2'))!.barcode, isNull);
    });

    test('watchActiveProducts sembunyikan arsip + soft-delete', () async {
      await db.upsertProduct(
        productRow(id: 'p-aktif', name: 'Gula', updatedAt: 3),
      );
      await db.upsertProduct(
        productRow(id: 'p-arsip', name: 'Teh', archived: true, updatedAt: 2),
      );
      await db.upsertProduct(
        productRow(id: 'p-hapus', name: 'Kopi', updatedAt: 4),
      );
      await db.softDeleteProduct('p-hapus', 100);

      final aktif = await db.watchActiveProducts('store-1').first;

      expect(aktif.map((e) => e.id), ['p-aktif']);
    });

    test('watchArchivedProducts hanya tampilkan arsip', () async {
      await db.upsertProduct(productRow(id: 'p-aktif', name: 'Gula'));
      await db.upsertProduct(
        productRow(id: 'p-arsip', name: 'Teh', archived: true),
      );

      final arsip = await db.watchArchivedProducts('store-1').first;

      expect(arsip.map((e) => e.id), ['p-arsip']);
    });

    test('searchProducts ketemu via nama dan via barcode exact', () async {
      await db.upsertProduct(
        productRow(id: 'p-1', name: 'Gula Pasir 1kg', barcode: '899123'),
      );
      await db.upsertProduct(
        productRow(id: 'p-2', name: 'Kopi Tubruk', barcode: '899456'),
      );

      final viaNama = await db.searchProducts('store-1', 'gula');
      expect(viaNama.map((e) => e.id), ['p-1']);

      final viaBarcode = await db.searchProducts('store-1', '899123');
      expect(viaBarcode.map((e) => e.id), ['p-1']);

      // Barcode hanya exact: potongan digit tidak cocok.
      final parsial = await db.searchProducts('store-1', '899');
      expect(parsial, isEmpty);
    });

    test('archiveProduct + markClean menulis flag lokal', () async {
      await db.upsertProduct(productRow(id: 'p-1', name: 'Gula'));

      await db.archiveProduct('p-1', true);
      expect((await db.getProduct('p-1'))!.isArchived, isTrue);

      await db.markClean(['p-1']);
      expect((await db.getProduct('p-1'))!.dirty, 0);
    });
  });
}
