import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/db/app_db.dart';
import 'package:pos_app/features/auth/auth_provider.dart';
import 'package:pos_app/features/adjustments/adjustments_api.dart';
import 'package:pos_app/features/adjustments/adjustments_provider.dart'
    as adj;
import 'package:pos_app/features/products/products_api.dart';
import 'package:pos_app/features/products/products_provider.dart'
    as products;

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

Map<String, dynamic> adjustmentJson({
  String id = 'a1',
  int stockBefore = 10,
  int stockAfter = 14,
  int diff = 4,
  String status = 'ok',
}) => {
  'id': id,
  'productId': 'p1',
  'name': 'Indomie',
  'stockBefore': stockBefore,
  'stockAfter': stockAfter,
  'diff': diff,
  'reason': 'selip',
  'status': status,
  'voidReason': null,
  'createdAt': '2026-01-01T00:00:00.000Z',
  'voidedAt': null,
};

/// Env notifier opname: produk p1 (Indomie, stok 10).
Future<({adj.AdjustmentsNotifier notifier, AppDb db})> makeAdjustments({
  Future<Response<dynamic>> Function(RequestOptions options)? apiHandler,
}) async {
  final dio = apiHandler == null ? Dio() : fakeDio(apiHandler);
  final container = ProviderContainer(
    overrides: [
      appDbProvider.overrideWithValue(AppDb.openMemory()),
      adj.adjustmentsApiProvider.overrideWithValue(AdjustmentsApi(dio: dio)),
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
  // upsertProduct selalu menandai dirty=1; seed dianggap sudah tersinkron.
  await db.markClean(['p1']);
  final notifier = container.read(adj.adjustmentsProvider.notifier);
  await notifier.load('store-1');
  return (notifier: notifier, db: db);
}

void main() {
  group('sesuaikan stok', () {
    test('fisik naik 10 -> 14: stok 14, riwayat ada', () async {
      final env = await makeAdjustments();
      final err = await env.notifier.adjustStock(
        productId: 'p1',
        physicalStock: 14,
        reason: 'selip',
      );

      expect(err, isNull);
      expect((await env.db.getProduct('p1'))!.stock, 14);
      expect(env.notifier.state.history.single.diff, 4);
    });

    test('fisik turun 10 -> 7: diff -3', () async {      final env = await makeAdjustments();
      final err = await env.notifier.adjustStock(
        productId: 'p1',
        physicalStock: 7,
        reason: 'rusak',
      );

      expect(err, isNull);
      expect((await env.db.getProduct('p1'))!.stock, 7);
      expect(env.notifier.state.history.single.diff, -3);
    });

    test('fisik == stok -> error, tidak ada dokumen', () async {
      final env = await makeAdjustments();
      final err = await env.notifier.adjustStock(
        productId: 'p1',
        physicalStock: 10,
        reason: 'cek',
      );

      expect(err, contains('tidak ada perubahan'));
      expect(env.notifier.state.history, isEmpty);
    });

    test('alasan kosong -> error', () async {
      final env = await makeAdjustments();
      final err = await env.notifier.adjustStock(
        productId: 'p1',
        physicalStock: 12,
        reason: '  ',
      );

      expect(err, contains('wajib diisi'));
      expect((await env.db.getProduct('p1'))!.stock, 10);
    });

    test('produk arsip -> diblokir', () async {
      final env = await makeAdjustments();
      await env.db.archiveProduct('p1', true);

      final err = await env.notifier.adjustStock(
        productId: 'p1',
        physicalStock: 12,
        reason: 'x',
      );

      expect(err, contains('diarsipkan'));
      expect((await env.db.getProduct('p1'))!.stock, 10);
    });

    test('void + alasan -> stok kembali', () async {
      final env = await makeAdjustments();
      await env.notifier.adjustStock(
        productId: 'p1',
        physicalStock: 14,
        reason: 'selip',
      );
      final id = env.notifier.state.history.single.id;

      final err = await env.notifier.voidAdjustment(id, 'salah hitung');

      expect(err, isNull);
      expect((await env.db.getProduct('p1'))!.stock, 10);
      expect(
        env.notifier.state.history.singleWhere((e) => e.id == id).isVoided,
        isTrue,
      );
    });

    test('void tanpa alasan -> error', () async {
      final env = await makeAdjustments();
      await env.notifier.adjustStock(
        productId: 'p1',
        physicalStock: 14,
        reason: 'selip',
      );
      final id = env.notifier.state.history.single.id;

      final err = await env.notifier.voidAdjustment(id, '  ');

      expect(err, contains('wajib diisi'));
    });
  });

  group('sinkron manual', () {
    test('adjust kotor -> bersih + pull server masuk', () async {
      final env = await makeAdjustments(
        apiHandler: (options) async {
          if (options.method == 'PUT') {
            return ok(options, {
              'id': 'p1',
              'name': 'Indomie',
              'barcode': null,
              'costPrice': 2500,
              'sellPrice': 3500,
              'stock': 14,
              'category': '',
              'photoPath': '',
              'updatedAt': '2026-01-01T00:00:00.000Z',
              'deletedAt': null,
            });
          }
          if (options.method == 'POST') {
            return ok(options, adjustmentJson(), 201);
          }
          return ok(options, [
            adjustmentJson(id: 'srv1', stockBefore: 14, stockAfter: 15, diff: 1),
          ]);
        },
      );
      await env.notifier.adjustStock(
        productId: 'p1',
        physicalStock: 14,
        reason: 'selip',
      );

      await env.notifier.syncNow(accessToken: 'token');

      expect(env.notifier.state.syncStatus, adj.SyncStatus.idle);
      expect(env.notifier.state.history.length, 2);
    });

    test('void lokal lalu sync -> POST /void terkirim, idle, bersih',
        () async {
      final events = <String>[];
      final env = await makeAdjustments(
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
            return ok(options, adjustmentJson(status: 'voided'));
          }
          if (options.method == 'POST' &&
              options.path.endsWith('/adjustments')) {
            events.add('adjust');
            return ok(options, adjustmentJson(), 201);
          }
          return ok(options, []);
        },
      );
      await env.notifier.adjustStock(
        productId: 'p1',
        physicalStock: 14,
        reason: 'selip',
      );
      final id = env.notifier.state.history.single.id;

      await env.notifier.syncNow(accessToken: 'token');
      expect(events, ['adjust']);

      await env.notifier.voidAdjustment(id, 'salah hitung');
      expect((await env.db.getProduct('p1'))!.stock, 10);

      await env.notifier.syncNow(accessToken: 'token');

      expect(events, ['adjust', 'void']);
      expect(env.notifier.state.syncStatus, adj.SyncStatus.idle);
      expect(env.notifier.state.lastError, isNull);
      expect(
        env.notifier.state.history.singleWhere((e) => e.id == id).isVoided,
        isTrue,
      );
    });

    test('adjust sync 2x: tidak di-POST ulang (anti stok-dobel)', () async {
      var adjustPosts = 0;
      final env = await makeAdjustments(
        apiHandler: (options) async {
          if (options.method == 'PUT') {
            return ok(options, {
              'id': 'p1',
              'name': 'Indomie',
              'barcode': null,
              'costPrice': 2500,
              'sellPrice': 3500,
              'stock': 14,
              'category': '',
              'photoPath': '',
              'updatedAt': '2026-01-01T00:00:00.000Z',
              'deletedAt': null,
            });
          }
          if (options.method == 'POST' &&
              options.path.endsWith('/adjustments')) {
            adjustPosts++;
            return ok(options, adjustmentJson(), 201);
          }
          return ok(options, []);
        },
      );
      await env.notifier.adjustStock(
        productId: 'p1',
        physicalStock: 14,
        reason: 'selip',
      );

      await env.notifier.syncNow(accessToken: 'token');
      await env.notifier.syncNow(accessToken: 'token');

      expect(adjustPosts, 1);
      expect(env.notifier.state.lastError, isNull);
    });

    test('syncNow offline -> status offline', () async {
      final env = await makeAdjustments(
        apiHandler: (options) async {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        },
      );
      await env.notifier.adjustStock(
        productId: 'p1',
        physicalStock: 14,
        reason: 'selip',
      );

      await env.notifier.syncNow(accessToken: 'token');

      expect(env.notifier.state.syncStatus, adj.SyncStatus.offline);
    });

    test(
      'REGRESI: opname tidak menandai produk dirty '
      '(stok terkirim via POST, PUT abaikan stok)', () async {
        final env = await makeAdjustments();
        await env.notifier.adjustStock(
          productId: 'p1',
          physicalStock: 14,
          reason: 'selip',
        );

        expect((await env.db.getProduct('p1'))!.stock, 14);
        expect((await env.db.getProduct('p1'))!.dirty, 0);
      },
    );

    test(
      'REGRESI: void tidak menandai produk dirty', () async {
        final env = await makeAdjustments();
        await env.notifier.adjustStock(
          productId: 'p1',
          physicalStock: 14,
          reason: 'selip',
        );
        final id = env.notifier.state.history.single.id;
        await env.notifier.voidAdjustment(id, 'salah hitung');

        expect((await env.db.getProduct('p1'))!.stock, 10);
        expect((await env.db.getProduct('p1'))!.dirty, 0);
      },
    );
  });
}
