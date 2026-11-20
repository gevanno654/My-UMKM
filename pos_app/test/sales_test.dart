import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/db/app_db.dart';
import 'package:pos_app/features/auth/auth_provider.dart';
import 'package:pos_app/features/sales/sale_model.dart';
import 'package:pos_app/features/sales/sales_api.dart';
import 'package:pos_app/features/sales/sales_provider.dart';

/// Notifier palsu: Dio di-intercept, respons dari handler per URL+method.
/// Handler melempar DioException untuk mensimulasikan status error.
Dio fakeDio(
  Future<Response<dynamic>> Function(RequestOptions options) handler,
) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handlerFn) async {
        try {
          handlerFn.resolve(await handler(options));
        } on DioException catch (e) {
          handlerFn.reject(e);
        }
      },
    ),
  );
  return dio;
}

Response<dynamic> ok(RequestOptions options, Object data, [int code = 200]) =>
    Response(requestOptions: options, statusCode: code, data: data);

Never fail(RequestOptions options, int statusCode, Object? data) {
  throw DioException(
    requestOptions: options,
    response: Response(
      requestOptions: options,
      statusCode: statusCode,
      data: data,
    ),
    type: DioExceptionType.badResponse,
  );
}

Map<String, dynamic> saleJson({
  String id = 's1',
  String number = 'TE010120260001',
  int total = 7000,
  int paid = 10000,
  int change = 3000,
  String method = 'tunai',
}) => {
  'id': id,
  'number': number,
  'total': total,
  'paid': paid,
  'change': change,
  'method': method,
  'status': 'ok',
  'voidReason': null,
  'createdAt': '2026-01-01T00:00:00.000Z',
  'items': [
    {
      'id': 'i1',
      'productId': 'p1',
      'name': 'Indomie',
      'price': 3500,
      'qty': 2,
      'subtotal': 7000,
    },
  ],
};

/// Env notifier kasir: produk p1 (Indomie 3500, stok 5) sudah ada.
Future<({SalesNotifier notifier, AppDb db})> makeSales({
  Future<Response<dynamic>> Function(RequestOptions options)? apiHandler,
}) async {
  final container = ProviderContainer(
    overrides: [
      appDbProvider.overrideWithValue(AppDb.openMemory()),
      salesApiProvider.overrideWithValue(
        SalesApi(
          dio: apiHandler == null ? Dio() : fakeDio(apiHandler),
        ),
      ),
    ],
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
      stock: const Value(5),
      createdAt: 1,
      updatedAt: 1,
    ),
  );
  await db.upsertProduct(
    ProductsCompanion.insert(
      id: 'p2',
      storeId: 'store-1',
      name: 'Teh',
      barcode: const Value.absent(),
      costPrice: 2000,
      sellPrice: 3000,
      stock: const Value(1),
      createdAt: 1,
      updatedAt: 1,
    ),
  );
  final notifier = container.read(salesProvider.notifier);
  await notifier.load('store-1', storeName: 'Toko Evan');
  return (notifier: notifier, db: db);
}

void main() {
  group('receiptInitials', () {
    test('"Toko Evan" -> TE', () {
      expect(receiptInitials('Toko Evan'), 'TE');
    });

    test('"Warung Barokah Jaya" -> WBJ', () {
      expect(receiptInitials('Warung Barokah Jaya'), 'WBJ');
    });

    test('"Sembako" -> SEM', () {
      expect(receiptInitials('Sembako'), 'SEM');
    });
  });

  group('keranjang', () {
    test('tambah item -> total benar + persist', () async {
      final env = await makeSales();
      await env.notifier.addItem('p1', 2);

      expect(env.notifier.state.total, 7000);
      expect((await env.db.getCartLines('store-1')).length, 1);
    });

    test('setQty melebihi stok -> error, qty tidak berubah', () async {
      final env = await makeSales();
      await env.notifier.addItem('p1', 2);

      final error = await env.notifier.setQty('p1', 99);

      expect(error, contains('Stok'));
      expect(env.notifier.state.total, 7000);
    });

    test('produk arsip tidak bisa masuk keranjang', () async {
      final env = await makeSales();
      await env.db.archiveProduct('p1', true);

      final error = await env.notifier.addItem('p1', 1);

      expect(error, isNotNull);
      expect(env.notifier.state.cartLines, isEmpty);
    });
  });

  group('checkout', () {
    test('tunai kurang -> error, stok tetap', () async {
      final env = await makeSales();
      await env.notifier.addItem('p1', 2);

      final error = await env.notifier.checkout(
        paid: 1000,
        method: PayMethod.tunai,
      );

      expect(error, isNotNull);
      expect((await env.db.getProduct('p1'))!.stock, 5);
    });

    test('tunai pas -> stok berkurang + cart kosong + riwayat ada', () async {
      final env = await makeSales();
      await env.notifier.addItem('p1', 2);

      final error = await env.notifier.checkout(
        paid: 7000,
        method: PayMethod.tunai,
      );

      expect(error, isNull);
      expect((await env.db.getProduct('p1'))!.stock, 3);
      expect(await env.db.getCartLines('store-1'), isEmpty);
      expect(env.notifier.state.history.length, 1);
      expect(env.notifier.state.history.first.total, 7000);
      expect(
        env.notifier.state.history.first.number,
        startsWith('TE'),
      );
    });

    test('qris -> paid otomatis = total', () async {
      final env = await makeSales();
      await env.notifier.addItem('p1', 1);

      final error = await env.notifier.checkout(
        paid: 0, // diabaikan untuk non-tunai
        method: PayMethod.qris,
      );

      expect(error, isNull);
      expect(env.notifier.state.history.first.paid, 3500);
      expect(env.notifier.state.history.first.change, 0);
    });

    test('produk dihapus sebelum bayar -> diblokir', () async {
      final env = await makeSales();
      await env.notifier.addItem('p1', 1);
      await env.db.softDeleteProduct('p1', 999);

      final error = await env.notifier.checkout(
        paid: 3500,
        method: PayMethod.tunai,
      );

      expect(error, contains('tidak tersedia'));
      expect(env.notifier.state.history, isEmpty);
    });
  });

  group('void', () {
    test('void tanpa alasan -> error', () async {
      final env = await makeSales();
      await env.notifier.addItem('p1', 1);
      await env.notifier.checkout(paid: 3500, method: PayMethod.tunai);
      final id = env.notifier.state.history.first.id;

      final error = await env.notifier.voidSale(id, '  ');

      expect(error, isNotNull);
      expect((await env.db.getProduct('p1'))!.stock, 4);
    });

    test('void + alasan -> stok kembali', () async {
      final env = await makeSales();
      await env.notifier.addItem('p1', 1);
      await env.notifier.checkout(paid: 3500, method: PayMethod.tunai);
      final id = env.notifier.state.history.first.id;

      final error = await env.notifier.voidSale(id, 'salah input');

      expect(error, isNull);
      expect((await env.db.getProduct('p1'))!.stock, 5);
      expect(env.notifier.state.history.first.isVoided, isTrue);
    });
  });

  group('sinkron manual', () {
    test('push sale kotor -> bersih + pull server masuk', () async {
      final env = await makeSales(
        apiHandler: (options) async {
          if (options.method == 'POST') {
            return ok(options, saleJson(), 201);
          }
          return ok(options, [
            saleJson(id: 'srv1', number: 'TE020120260001'),
          ]);
        },
      );
      await env.notifier.addItem('p1', 2);
      await env.notifier.checkout(paid: 7000, method: PayMethod.tunai);

      await env.notifier.syncNow(accessToken: 'token');

      expect(env.notifier.state.syncStatus, SyncStatus.idle);
      expect(env.notifier.state.history.length, 2);
      expect(
        env.notifier.state.history.map((s) => s.id),
        contains('srv1'),
      );
    });

    test('nomor duplikat 409 -> pesan buat ulang', () async {
      final env = await makeSales(
        apiHandler: (options) async {
          if (options.method == 'POST') {
            return fail(options, 409, {'error': 'number taken'});
          }
          return ok(options, []);
        },
      );
      await env.notifier.addItem('p1', 1);
      await env.notifier.checkout(paid: 3500, method: PayMethod.tunai);

      await env.notifier.syncNow(accessToken: 'token');

      expect(env.notifier.state.syncStatus, SyncStatus.error);
      expect(
        env.notifier.state.lastError,
        contains('Nomor struk sudah dipakai'),
      );
    });
  });
}
