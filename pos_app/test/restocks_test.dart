import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/db/app_db.dart';
import 'package:pos_app/features/auth/auth_provider.dart';
import 'package:pos_app/features/products/products_api.dart';
import 'package:pos_app/features/products/products_provider.dart' as products;
import 'package:pos_app/features/restocks/restocks_api.dart';
import 'package:pos_app/features/restocks/restocks_provider.dart' as restocks;

/// Notifier palsu: Dio di-intercept, respons dari handler per URL+method.
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

Map<String, dynamic> restockJson({
  String id = 'r1',
  int total = 5200,
  String status = 'ok',
}) => {
  'id': id,
  'total': total,
  'status': status,
  'voidReason': null,
  'createdAt': '2026-01-01T00:00:00.000Z',
  'items': [
    {
      'id': 'ri1',
      'productId': 'p1',
      'name': 'Indomie',
      'qty': 2,
      'costPrice': 2600,
      'sellPrice': null,
      'subtotal': 5200,
    },
  ],
};

/// Env notifier restock: produk p1 (Indomie, beli 2500/jual 3500, stok 10).
Future<({restocks.RestocksNotifier notifier, AppDb db})> makeRestocks({
  Future<Response<dynamic>> Function(RequestOptions options)? apiHandler,
}) async {
  final dio = apiHandler == null ? Dio() : fakeDio(apiHandler);
  final container = ProviderContainer(
    overrides: [
      appDbProvider.overrideWithValue(AppDb.openMemory()),
      restocks.restocksApiProvider.overrideWithValue(RestocksApi(dio: dio)),
      products.productsApiProvider.overrideWithValue(ProductsApi(dio: dio)),
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
      stock: const Value(10),
      createdAt: 1,
      updatedAt: 1,
    ),
  );
  final notifier = container.read(restocks.restocksProvider.notifier);
  await notifier.load('store-1');
  return (notifier: notifier, db: db);
}

void main() {
  group('draft', () {
    test('tambah produk -> total modal benar', () async {
      final env = await makeRestocks();
      final err = await env.notifier.addToDraft('p1', qty: 2);

      expect(err, isNull);
      expect(env.notifier.state.draftLines.length, 1);
      expect(env.notifier.state.draftTotalModal, 5000);
    });

    test('produk sama 2x -> gabung (qty jumlah, harga terakhir menang)',
        () async {
      final env = await makeRestocks();
      await env.notifier.addToDraft('p1', qty: 2);
      await env.notifier.setDraftPrices('p1', costPrice: 2600);
      await env.notifier.addToDraft('p1', qty: 3);

      expect(env.notifier.state.draftLines.length, 1);
      final line = env.notifier.state.draftLines.first;
      expect(line.qty, 5);
      // Harga terakhir menang: harga katalog 2500 (addToDraft pakai katalog).
      expect(line.costPrice, 2500);
      expect(env.notifier.state.draftTotalModal, 5 * 2500);
    });

    test('setQty 0 -> baris hapus; negatif -> error', () async {
      final env = await makeRestocks();
      await env.notifier.addToDraft('p1', qty: 2);

      expect(await env.notifier.setDraftQty('p1', -1), isNotNull);
      expect(env.notifier.state.draftLines.length, 1);

      expect(await env.notifier.setDraftQty('p1', 0), isNull);
      expect(env.notifier.state.draftLines, isEmpty);
    });

    test('harga di luar batas -> error + tidak berubah', () async {
      final env = await makeRestocks();
      await env.notifier.addToDraft('p1', qty: 2);

      expect(
        await env.notifier.setDraftPrices('p1', costPrice: 1000000000),
        isNotNull,
      );
      expect(env.notifier.state.draftLines.first.costPrice, 2500);
    });
  });

  group('simpan', () {
    test('save -> stok + harga beli katalog update, jual tetap', () async {
      final env = await makeRestocks();
      await env.notifier.addToDraft('p1', qty: 2);
      await env.notifier.setDraftPrices('p1', costPrice: 2600);

      final err = await env.notifier.saveRestock();

      expect(err, isNull);
      expect(env.notifier.state.draftLines, isEmpty);
      expect((await env.db.getProduct('p1'))!.stock, 12);
      expect((await env.db.getProduct('p1'))!.costPrice, 2600);
      // Harga jual katalog tidak berubah lewat restock v1.
      expect((await env.db.getProduct('p1'))!.sellPrice, 3500);
      expect(env.notifier.state.history.length, 1);
      expect(env.notifier.state.history.first.total, 5200);
    });

    test('save draft kosong -> error', () async {
      final env = await makeRestocks();

      expect(await env.notifier.saveRestock(), isNotNull);
    });

    test('save produk diarsip setelah masuk draft -> diblokir', () async {
      final env = await makeRestocks();
      await env.notifier.addToDraft('p1', qty: 1);
      await env.db.archiveProduct('p1', true);

      final err = await env.notifier.saveRestock();

      expect(err, contains('arsip'));
      expect((await env.db.getProduct('p1'))!.stock, 10);
      expect(env.notifier.state.history, isEmpty);
    });

    test('save produk dihapus setelah masuk draft -> diblokir', () async {
      final env = await makeRestocks();
      await env.notifier.addToDraft('p1', qty: 1);
      await env.db.softDeleteProduct('p1', 99);

      final err = await env.notifier.saveRestock();

      expect(err, isNotNull);
      expect(env.notifier.state.history, isEmpty);
    });
  });

  group('void', () {
    test('void + alasan -> stok kembali', () async {
      final env = await makeRestocks();
      await env.notifier.addToDraft('p1', qty: 2);
      await env.notifier.saveRestock();
      final id = env.notifier.state.history.first.id;

      final err = await env.notifier.voidRestock(id, 'salah input');

      expect(err, isNull);
      expect((await env.db.getProduct('p1'))!.stock, 10);
      expect(env.notifier.state.history.first.status, 'voided');
    });

    test('void tanpa alasan -> error', () async {
      final env = await makeRestocks();
      await env.notifier.addToDraft('p1', qty: 1);
      await env.notifier.saveRestock();
      final id = env.notifier.state.history.first.id;

      expect(await env.notifier.voidRestock(id, '  '), isNotNull);
      expect((await env.db.getProduct('p1'))!.stock, 11);
    });

    test('void stok kurang (terjual) -> error, stok tetap', () async {
      final env = await makeRestocks();
      await env.notifier.addToDraft('p1', qty: 5);
      await env.notifier.saveRestock();
      final id = env.notifier.state.history.first.id;
      // Jual 13 dari 15: sisa 2 < qty restock 5.
      final p = await env.db.getProduct('p1');
      await (env.db.update(env.db.products)
            ..where((t) => t.id.equals('p1')))
          .write(
        ProductsCompanion(
          stock: Value(p!.stock - 13),
          updatedAt: const Value(3),
          dirty: const Value(1),
        ),
      );

      final err = await env.notifier.voidRestock(id, 'salah');

      expect(err, isNotNull);
      expect((await env.db.getProduct('p1'))!.stock, 2);
    });
  });

  group('sinkron manual', () {
    test('restock + produk sync: push produk dulu baru restock', () async {
      final events = <String>[];
      final env = await makeRestocks(
        apiHandler: (options) async {
          if (options.method == 'PUT') {
            events.add('product');
            return ok(options, {
              'id': 'p1',
              'name': 'Indomie',
              'barcode': null,
              'costPrice': 2600,
              'sellPrice': 3500,
              'stock': 12,
              'category': '',
              'photoPath': '',
              'updatedAt': '2026-01-01T00:00:00.000Z',
              'deletedAt': null,
            });
          }
          if (options.method == 'POST' &&
              options.path.endsWith('/products')) {
            events.add('product');
            return ok(options, {
              'id': 'p1',
              'name': 'Indomie',
              'barcode': null,
              'costPrice': 2600,
              'sellPrice': 3500,
              'stock': 12,
              'category': '',
              'photoPath': '',
              'updatedAt': '2026-01-01T00:00:00.000Z',
              'deletedAt': null,
            }, 201);
          }
          if (options.method == 'POST' &&
              options.path.endsWith('/restocks')) {
            events.add('restock');
            return ok(options, restockJson(), 201);
          }
          return ok(options, []);
        },
      );
      await env.notifier.addToDraft('p1', qty: 2);
      await env.notifier.setDraftPrices('p1', costPrice: 2600);
      await env.notifier.saveRestock();

      await env.notifier.syncNow(accessToken: 'token');

      expect(events, ['product', 'restock']);
      expect(env.notifier.state.syncStatus, restocks.SyncStatus.idle);
      expect(env.notifier.state.lastError, isNull);
      // Produk bersih: sinkron berikutnya tidak push ulang.
      expect((await env.db.getProduct('p1'))!.dirty, 0);
    });

    test(
      'sinkron 2x: restock tidak di-POST ulang',
      () async {
        var restockPosts = 0;
        final env = await makeRestocks(
          apiHandler: (options) async {
            if (options.method == 'PUT') {
              return ok(options, {
                'id': 'p1',
                'name': 'Indomie',
                'barcode': null,
                'costPrice': 2500,
                'sellPrice': 3500,
                'stock': 12,
                'category': '',
                'photoPath': '',
                'updatedAt': '2026-01-01T00:00:00.000Z',
                'deletedAt': null,
              });
            }
            if (options.method == 'POST' &&
                options.path.endsWith('/restocks')) {
              restockPosts++;
              return ok(options, restockJson(id: 'r$restockPosts'), 201);
            }
            return ok(options, []);
          },
        );
        await env.notifier.addToDraft('p1', qty: 2);
        await env.notifier.saveRestock();

        await env.notifier.syncNow(accessToken: 'token');
        await env.notifier.syncNow(accessToken: 'token');

        // Hanya 1 POST restock: stok server hanya +2 sekali.
        expect(restockPosts, 1);
        expect(env.notifier.state.lastError, isNull);
        expect((await env.db.getProduct('p1'))!.dirty, 0);
        expect((await env.db.getProduct('p1'))!.stock, 12);
      },
    );

    test('syncNow offline -> status offline', () async {
      final env = await makeRestocks(
        apiHandler: (options) async {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        },
      );
      await env.notifier.addToDraft('p1', qty: 1);
      await env.notifier.saveRestock();

      await env.notifier.syncNow(accessToken: 'token');

      expect(env.notifier.state.syncStatus, restocks.SyncStatus.offline);
    });

    test(
      'produk di server sudah ada (PUT ok) -> restock terkirim, idle',
      () async {
        final events = <String>[];
        final env = await makeRestocks(
          apiHandler: (options) async {
            if (options.method == 'PUT') {
              events.add('product');
              return ok(options, {
                'id': 'p1',
                'name': 'Indomie',
                'barcode': null,
                'costPrice': 2600,
                'sellPrice': 3500,
                'stock': 12,
                'category': '',
                'photoPath': '',
                'updatedAt': '2026-01-01T00:00:00.000Z',
                'deletedAt': null,
              });
            }
            if (options.method == 'POST' &&
                options.path.endsWith('/restocks')) {
              events.add('restock');
              return ok(options, restockJson(), 201);
            }
            return ok(options, []);
          },
        );
        await env.notifier.addToDraft('p1', qty: 1);
        await env.notifier.saveRestock();

        await env.notifier.syncNow(accessToken: 'token');

        expect(events, ['product', 'restock']);
        expect(env.notifier.state.syncStatus, restocks.SyncStatus.idle);
        expect(env.notifier.state.lastError, isNull);
      },
    );

    test(
      'produk gagal push (barcode bentrok 409) -> restock tidak dipaksa, '
      'pesan jelas bukan 404 generik',
      () async {
        final events = <String>[];
        final env = await makeRestocks(
          apiHandler: (options) async {
            if (options.method == 'PUT') {
              return fail(options, 404, {'error': 'not found'});
            }
            // POST produk bentrok barcode dengan produk lain di server.
            if (options.method == 'POST' &&
                options.path.endsWith('/products')) {
              events.add('product-attempt');
              return fail(options, 409, {'error': 'barcode taken'});
            }
            if (options.method == 'POST' &&
                options.path.endsWith('/restocks')) {
              events.add('restock');
              return ok(options, restockJson(), 201);
            }
            return ok(options, []);
          },
        );
        await env.notifier.addToDraft('p1', qty: 1);
        await env.notifier.saveRestock();

        await env.notifier.syncNow(accessToken: 'token');

        // Restock TIDAK boleh di-POST buta saat produknya gagal push.
        expect(events, isNot(contains('restock')));
        expect(env.notifier.state.syncStatus, restocks.SyncStatus.error);
        expect(
          env.notifier.state.lastError,
          contains('Barcode sudah dipakai'),
        );
      },
    );

    test(
      'void lokal lalu sync -> POST /void terkirim, idle, bersih',
      () async {
        final events = <String>[];
        final env = await makeRestocks(
          apiHandler: (options) async {
            if (options.method == 'PUT') {
              return ok(options, {
                'id': 'p1',
                'name': 'Indomie',
                'barcode': null,
                'costPrice': 2500,
                'sellPrice': 3500,
                'stock': 10,
                'category': '',
                'photoPath': '',
                'updatedAt': '2026-01-01T00:00:00.000Z',
                'deletedAt': null,
              });
            }
            if (options.path.endsWith('/void')) {
              events.add('void');
              return ok(options, restockJson(status: 'voided'));
            }
            if (options.method == 'POST' &&
                options.path.endsWith('/restocks')) {
              events.add('restock');
              return ok(options, restockJson(), 201);
            }
            return ok(options, []);
          },
        );
        await env.notifier.addToDraft('p1', qty: 2);
        await env.notifier.saveRestock();
        final id = env.notifier.state.history.single.id;

        await env.notifier.syncNow(accessToken: 'token');
        expect(events, ['restock']);

        // Batalkan lokal, lalu sinkron lagi: harus POST /void, bukan
        // POST ulang dokumen (yang pasti 404/gagal). Stok lokal kembali.
        await env.notifier.voidRestock(id, 'salah input');
        expect((await env.db.getProduct('p1'))!.stock, 10);

        await env.notifier.syncNow(accessToken: 'token');

        // RED: kode saat ini POST ulang dokumen untuk baris voided
        // (tidak ada cabang void) -> events ['restock','restock'].
        expect(events, ['restock', 'void']);
        expect(env.notifier.state.syncStatus, restocks.SyncStatus.idle);
        expect(env.notifier.state.lastError, isNull);
        expect(
          env.notifier.state.history.singleWhere((e) => e.id == id).isVoided,
          isTrue,
        );
      },
    );
  });
}
