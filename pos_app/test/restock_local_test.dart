import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/db/app_db.dart';

AppDb makeDb() => AppDb.openMemory();

Future<void> seedProduct(
  AppDb db, {
  String id = 'p1',
  int stock = 10,
  int costPrice = 2500,
  int sellPrice = 3500,
}) =>
    db.upsertProduct(
      ProductsCompanion.insert(
        id: id,
        storeId: 'store-1',
        name: 'Indomie',
        barcode: const Value.absent(),
        costPrice: costPrice,
        sellPrice: sellPrice,
        stock: Value(stock),
        createdAt: 1,
        updatedAt: 1,
      ),
    );

RestocksCompanion restockOf(String id, int total) => RestocksCompanion.insert(
      id: id,
      storeId: 'store-1',
      total: total,
      createdAt: 2,
    );

RestockItemsCompanion itemOf({
  required String restockId,
  String productId = 'p1',
  int qty = 2,
  int costPrice = 2600,
  int? sellPrice,
}) =>
    RestockItemsCompanion.insert(
      id: 'ri-${restockId.hashCode}-$productId',
      restockId: restockId,
      productId: Value(productId),
      name: 'Indomie',
      qty: qty,
      costPrice: costPrice,
      sellPrice: Value(sellPrice),
      subtotal: qty * costPrice,
    );

void main() {
  test('simpan restock: stok += qty, harga katalog update, totalModal benar',
      () async {
    final db = makeDb();
    addTearDown(db.close);
    await seedProduct(db);

    await db.saveRestockFull(
      restock: restockOf('r1', 2 * 2600),
      items: [itemOf(restockId: 'r1', sellPrice: 3600)],
    );

    final p = await db.getProduct('p1');
    expect(p!.stock, 12);
    expect(p.costPrice, 2600);
    expect(p.sellPrice, 3600);
    final history = await db.restocksHistory('store-1');
    expect(history.length, 1);
    expect(history.first.total, 5200);
    expect(history.first.status, 'ok');
  });

  test('tanpa sellPrice: harga jual katalog tetap', () async {
    final db = makeDb();
    addTearDown(db.close);
    await seedProduct(db);

    await db.saveRestockFull(
      restock: restockOf('r1', 2 * 2600),
      items: [itemOf(restockId: 'r1')],
    );

    final p = await db.getProduct('p1');
    expect(p!.stock, 12);
    expect(p.costPrice, 2600);
    expect(p.sellPrice, 3500);
  });

  test('produk tidak ada -> throw, tidak ada restock terbuat', () async {
    final db = makeDb();
    addTearDown(db.close);

    expect(
      () => db.saveRestockFull(
        restock: restockOf('r1', 100),
        items: [itemOf(restockId: 'r1')],
      ),
      throwsStateError,
    );
    expect(await db.restocksHistory('store-1'), isEmpty);
  });

  test('void ok: status voided + stok kembali', () async {
    final db = makeDb();
    addTearDown(db.close);
    await seedProduct(db);
    await db.saveRestockFull(
      restock: restockOf('r1', 2 * 2600),
      items: [itemOf(restockId: 'r1')],
    );

    await db.voidRestock(id: 'r1', reason: 'salah input', nowMillis: 3);

    final r = await db.getRestock('r1');
    expect(r!.status, 'voided');
    expect(r.voidReason, 'salah input');
    final p = await db.getProduct('p1');
    expect(p!.stock, 10);
  });

  test('void tanpa alasan -> throw', () async {
    final db = makeDb();
    addTearDown(db.close);
    await seedProduct(db);
    await db.saveRestockFull(
      restock: restockOf('r1', 2 * 2600),
      items: [itemOf(restockId: 'r1')],
    );

    expect(
      () => db.voidRestock(id: 'r1', reason: '  ', nowMillis: 3),
      throwsArgumentError,
    );
  });

  test('void stok kurang (terjual) -> throw, stok tidak berubah', () async {
    final db = makeDb();
    addTearDown(db.close);
    await seedProduct(db, stock: 10);
    await db.saveRestockFull(
      restock: restockOf('r1', 5 * 2600),
      items: [itemOf(restockId: 'r1', qty: 5)],
    );
    // Jual 13 dari 15: sisa 2 < qty restock 5.
    final p = await db.getProduct('p1');
    await (db.update(db.products)..where((t) => t.id.equals('p1'))).write(
      ProductsCompanion(
        stock: Value(p!.stock - 13),
        updatedAt: const Value(3),
        dirty: const Value(1),
      ),
    );

    expect(
      () => db.voidRestock(id: 'r1', reason: 'salah', nowMillis: 4),
      throwsStateError,
    );
    final after = await db.getProduct('p1');
    expect(after!.stock, 2);
    final r = await db.getRestock('r1');
    expect(r!.status, 'ok');
  });
}
