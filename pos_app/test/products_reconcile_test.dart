import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/db/app_db.dart';

/// Rekonsiliasi ID produk: adopsi ID server saat ID lokal asing (409).
void main() {
  late AppDb db;

  setUp(() {
    db = AppDb.openMemory();
  });

  tearDown(() async {
    await db.close();
  });

  test('adoptProductId: ganti PK + FK atomik, stok lokal utuh, tetap dirty', () async {
    await db.upsertProduct(
      ProductsCompanion.insert(
        id: 'p-lokal',
        storeId: 'store-1',
        name: 'Minion',
        barcode: const Value('767062281296'),
        costPrice: 5000,
        sellPrice: 7000,
        stock: const Value(9),
        createdAt: 100,
        updatedAt: 100,
      ),
    );
    await db.into(db.saleItems).insert(
      SaleItemsCompanion.insert(
        id: 'si-1',
        saleId: 's-1',
        productId: const Value('p-lokal'),
        name: 'Minion',
        price: 7000,
        qty: 1,
        subtotal: 7000,
      ),
    );
    await db.into(db.restockItems).insert(
      RestockItemsCompanion.insert(
        id: 'ri-1',
        restockId: 'r-1',
        productId: const Value('p-lokal'),
        name: 'Minion',
        qty: 2,
        costPrice: 5000,
        subtotal: 10000,
      ),
    );
    await db.into(db.adjustments).insert(
      AdjustmentsCompanion.insert(
        id: 'a-1',
        storeId: 'store-1',
        productId: const Value('p-lokal'),
        name: 'Minion',
        stockBefore: 7,
        stockAfter: 9,
        diff: 2,
        reason: 'opname',
        createdAt: 100,
      ),
    );
    await db.upsertCartLine(
      CartLinesCompanion.insert(
        storeId: 'store-1',
        productId: 'p-lokal',
        qty: 3,
      ),
    );

    final server = ProductsCompanion.insert(
      id: 'p-server',
      storeId: 'store-1',
      name: 'Minion',
      barcode: const Value('767062281296'),
      costPrice: 5000,
      sellPrice: 8000,
      createdAt: 50,
      updatedAt: 200,
    );
    await db.adoptProductId(oldId: 'p-lokal', server: server);

    expect(await db.getProduct('p-lokal'), isNull);
    final adopted = await db.getProduct('p-server');
    expect(adopted, isNotNull);
    expect(adopted!.stock, 9);
    expect(adopted.sellPrice, 8000);
    expect(adopted.dirty, 1);

    final si = await (db.select(
      db.saleItems,
    )..where((t) => t.id.equals('si-1'))).getSingle();
    expect(si.productId, 'p-server');
    final ri = await (db.select(
      db.restockItems,
    )..where((t) => t.id.equals('ri-1'))).getSingle();
    expect(ri.productId, 'p-server');
    final adj = await (db.select(
      db.adjustments,
    )..where((t) => t.id.equals('a-1'))).getSingle();
    expect(adj.productId, 'p-server');
    final cart = await db.getCartLines('store-1');
    expect(cart.map((c) => c.productId), contains('p-server'));
    expect(cart.map((c) => c.productId), isNot(contains('p-lokal')));
  });
}
