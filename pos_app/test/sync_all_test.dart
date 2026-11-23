import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/db/app_db.dart';
import 'package:pos_app/core/session/secure_session.dart';
import 'package:pos_app/core/sync/sync_all_provider.dart';
import 'package:pos_app/features/auth/auth_provider.dart';
import 'package:pos_app/features/auth/auth_state.dart';
import 'package:pos_app/features/products/photo_store.dart';
import 'package:pos_app/features/products/products_api.dart';
import 'package:pos_app/features/products/products_provider.dart' as products;
import 'package:pos_app/features/restocks/restocks_api.dart';
import 'package:pos_app/features/restocks/restocks_provider.dart' as restocks;
import 'package:pos_app/features/sales/sales_api.dart';
import 'package:pos_app/features/sales/sales_provider.dart' as sales;
import 'package:pos_app/features/sales/sale_model.dart';
import 'package:pos_app/features/adjustments/adjustments_api.dart';
import 'package:pos_app/features/adjustments/adjustments_provider.dart'
    as adj;

/// Storage in-memory untuk test (tanpa binding platform).
class _MemStorage implements SecureStorage {
  final map = <String, String?>{};

  @override
  Future<String?> read(String key) async => map[key];

  @override
  Future<void> write(String key, String? value) async => map[key] = value;

  @override
  Future<void> delete(String key) async => map.remove(key);

  @override
  Future<void> deleteAll() async => map.clear();
}

/// Auth palsu: langsung terautentikasi sebagai pemilik toko store-1.
class _FakeAuthNotifier extends AuthNotifier {
  static const _profile = AuthProfile(
    id: 'user-1',
    storeId: 'store-1',
    name: 'Budi',
    email: 'budi@warung.id',
    storeName: 'Toko Evan',
  );

  @override
  AuthState build() => const AuthAuthenticated(_profile);
}

/// Env sync global: produk p1 stok 0 + restock qty 5 tersimpan lokal.
Future<
  ({SyncAllNotifier notifier, AppDb db, ProviderContainer container})
>
makeSyncAll({
  required Future<Response<dynamic>> Function(RequestOptions options)
  apiHandler,
  int initialStock = 0,
  bool seedRestock = true,
  PhotoStore? photoStore,
}) async {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handlerFn) async {
        try {
          handlerFn.resolve(await apiHandler(options));
        } on DioException catch (e) {
          handlerFn.reject(e);
        }
      },
    ),
  );
  final container = ProviderContainer(
    overrides: [
      appDbProvider.overrideWithValue(AppDb.openMemory()),
      secureSessionProvider.overrideWithValue(
        SecureSession(storage: _MemStorage()),
      ),
      authProvider.overrideWith(_FakeAuthNotifier.new),
      products.productsApiProvider.overrideWithValue(ProductsApi(dio: dio)),
      sales.salesApiProvider.overrideWithValue(SalesApi(dio: dio)),
      restocks.restocksApiProvider.overrideWithValue(RestocksApi(dio: dio)),
      adj.adjustmentsApiProvider.overrideWithValue(AdjustmentsApi(dio: dio)),
      photoStoreProvider.overrideWithValue(photoStore ?? PhotoStore()),
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
      stock: Value(initialStock),
      createdAt: 1,
      updatedAt: 1,
    ),
  );
  await db.markClean(['p1']);
  if (seedRestock) {
    // Restock lokal qty 5 -> stok jadi initialStock + 5, dokumen dirty.
    final restocksNotifier = container.read(
      restocks.restocksProvider.notifier,
    );
    await restocksNotifier.load('store-1');
    final draftErr = await restocksNotifier.addToDraft('p1', qty: 5);
    assert(draftErr == null, draftErr);
    final saveErr = await restocksNotifier.saveRestock();
    assert(saveErr == null, saveErr);
  }
  final notifier = container.read(syncAllProvider.notifier);
  return (notifier: notifier, db: db, container: container);
}

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

Map<String, dynamic> saleJson() => {
  'id': 's1',
  'number': 'TE010120260001',
  'total': 17500,
  'paid': 17500,
  'change': 0,
  'method': 'tunai',
  'status': 'ok',
  'voidReason': null,
  'createdAt': '2026-01-01T00:00:00.000Z',
  'items': [
    {
      'id': 'i1',
      'productId': 'p1',
      'name': 'Indomie',
      'price': 3500,
      'qty': 5,
      'subtotal': 17500,
    },
  ],
};

Response<dynamic> ok(RequestOptions options, Object data, [int code = 200]) =>
    Response(requestOptions: options, statusCode: code, data: data);

Map<String, dynamic> serverProduct({
  int stock = 0,
  String updatedAt = '2026-01-01T00:00:00.000Z',
}) => {
  'id': 'p1',
  'name': 'Indomie',
  'barcode': null,
  'costPrice': 2500,
  'sellPrice': 3500,
  'stock': stock,
  'category': '',
  'photoPath': '',
  'updatedAt': updatedAt,
  'deletedAt': null,
};

void main() {
  group('sinkron global', () {
    test(
      'REGRESI laporan: produk baru + 2 restock + 1 sale -> stok tetap 5, '
      'tanpa error stok server',
      () async {
        // Server tiruan realistis: punya logika stok sendiri seperti
        // backend asli (stok hanya berubah via dokumen, bukan PUT).
        var serverStock = 0;
        var productExists = false;
        final seenDocIds = <String>{};
        var saleAttempts = 0;
        final env = await makeSyncAll(
          seedRestock: false,
          apiHandler: (options) async {
            final path = options.path;
            // POST produk baru: stok awal 0 (baseline server).
            if (options.method == 'POST' && path.endsWith('/products')) {
              productExists = true;
              serverStock = 0;
              final body = options.data as Map<String, dynamic>;
              return ok(options, serverProduct(
                stock: 0,
                updatedAt: '2026-11-22T00:00:01.000Z',
              )..['name'] = body['name'], 201);
            }
            // PUT katalog: stok diabaikan (seperti backend asli).
            if (options.method == 'PUT' && path.contains('/products/')) {
              if (!productExists) {
                return fail(options, 404, {'error': 'not found'});
              }
              return ok(options, serverProduct(stock: serverStock));
            }
            // POST restock: stok server += qty (idempoten per id).
            if (options.method == 'POST' && path.endsWith('/restocks')) {
              final body = options.data as Map<String, dynamic>;
              if (!productExists) {
                return fail(options, 404, {'error': 'product not found'});
              }
              final id = body['id'] as String?;
              if (id != null && !seenDocIds.add(id)) {
                return ok(options, {
                  'id': id,
                  'total': 0,
                  'status': 'ok',
                  'voidReason': null,
                  'createdAt': '2026-01-01T00:00:00.000Z',
                  'items': [],
                }, 201);
              }
              var qty = 0;
              for (final i in (body['items'] as List)) {
                qty += (i as Map<String, dynamic>)['qty'] as int;
              }
              serverStock += qty;
              return ok(options, {
                'id': id ?? 'r-x',
                'total': 0,
                'status': 'ok',
                'voidReason': null,
                'createdAt': '2026-01-01T00:00:00.000Z',
                'items': [],
              }, 201);
            }
            // POST sale: tolak bila stok server kurang (seperti backend).
            if (options.method == 'POST' && path.endsWith('/sales')) {
              saleAttempts++;
              if (!productExists) {
                return fail(options, 404, {'error': 'product not found'});
              }
              final body = options.data as Map<String, dynamic>;
              final id = body['id'] as String?;
              if (id != null && !seenDocIds.add(id)) {
                return ok(options, saleJson(), 201);
              }
              var qty = 0;
              for (final i in (body['items'] as List)) {
                qty += (i as Map<String, dynamic>)['qty'] as int;
              }
              if (serverStock < qty) {
                return fail(
                  options,
                  409,
                  {'error': 'insufficient stock'},
                );
              }
              serverStock -= qty;
              return ok(options, saleJson(), 201);
            }
            if (options.method == 'GET' && path.endsWith('/products')) {
              if (!productExists) return ok(options, []);
              return ok(options, [serverProduct(stock: serverStock)]);
            }
            return ok(options, []);
          },
        );

        final db = env.db;
        final container = env.container;
        // Skenario laporan: 2x restock 5 lalu jual 5 (stok lokal 5).
        final restocksNotifier = container.read(
          restocks.restocksProvider.notifier,
        );
        await restocksNotifier.load('store-1');
        assert(await restocksNotifier.addToDraft('p1', qty: 5) == null);
        assert(await restocksNotifier.saveRestock() == null);
        restocksNotifier.clearDraft();
        assert(await restocksNotifier.addToDraft('p1', qty: 5) == null);
        assert(await restocksNotifier.saveRestock() == null);
        final salesNotifier = container.read(sales.salesProvider.notifier);
        await salesNotifier.load('store-1', storeName: 'Toko Evan');
        assert(await salesNotifier.addItem('p1', 5) == null);
        assert(
          await salesNotifier.checkout(
                paid: 17500,
                method: PayMethod.tunai,
              ) ==
              null,
        );
        expect((await db.getProduct('p1'))!.stock, 5);

        final err = await env.notifier.syncAll();

        expect(err, isNull, reason: 'sync backup tidak boleh error');
        expect(saleAttempts, 1);
        expect((await db.getProduct('p1'))!.stock, 5);
        // Pull dokumen tidak mengubah stok lokal.
        expect((await db.getProduct('p1'))!.dirty, 0);
      },
    );

    test(
      'REGRESI (+5 jadi +10): restock lalu syncAll -> stok tepat 5',
      () async {
        // Server tiruan yang benar: PUT abaikan stok, POST terapkan stok.
        var serverStock = 0;
        var restockPosts = 0;
        final env = await makeSyncAll(
          apiHandler: (options) async {
            if (options.method == 'PUT' &&
                options.path.endsWith('/products/p1')) {
              return ok(options, serverProduct(stock: serverStock));
            }
            if (options.method == 'POST' &&
                options.path.endsWith('/restocks')) {
              restockPosts++;
              serverStock = 5;
              return ok(options, {
                'id': 'r1',
                'total': 12500,
                'status': 'ok',
                'voidReason': null,
                'createdAt': '2026-01-01T00:00:00.000Z',
                'items': [],
              }, 201);
            }
            if (options.method == 'GET' &&
                options.path.endsWith('/products')) {
              return ok(options, [serverProduct(stock: serverStock)]);
            }
            return ok(options, []);
          },
        );

        await env.notifier.syncAll();

        expect(restockPosts, 1);
        expect((await env.db.getProduct('p1'))!.stock, 5);
      },
    );

    test('offline total -> status offline, data lokal utuh', () async {
      final env = await makeSyncAll(
        apiHandler: (options) async {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        },
      );

      await env.notifier.syncAll();

      expect(env.notifier.state.status, SyncStatus.offline);
      expect((await env.db.getProduct('p1'))!.stock, 5);
    });

    test('fase foto: manifest dipanggil, hash server baru → file terunduh',
        () async {
      var manifestCalls = 0;
      var downloadCalls = 0;
      final tmp = await Directory.systemTemp.createTemp('sync_all_photo');
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });
      final env = await makeSyncAll(
        seedRestock: false,
        photoStore: PhotoStore(docsDirOverride: tmp),
        apiHandler: (options) async {
          final path = options.path;
          if (options.method == 'GET' && path.endsWith('/photo-manifest')) {
            manifestCalls++;
            return ok(options, [
              {'id': 'p1', 'photoHash': 'c' * 64},
            ]);
          }
          if (options.method == 'GET' && path.contains('/photos/')) {
            downloadCalls++;
            return ok(options, [0xff, 0xd8, 0xff, 0xd9]);
          }
          if (options.method == 'GET' && path.endsWith('/products')) {
            return ok(options, [serverProduct()]);
          }
          return ok(options, []);
        },
      );

      final err = await env.notifier.syncAll();

      expect(err, isNull);
      expect(manifestCalls, 1);
      expect(downloadCalls, 1);
      final row = (await env.db.getProduct('p1'))!;
      expect(row.photoHash, 'c' * 64);
      expect(
        await File(
          '${tmp.path}/${row.photoPath}'.replaceAll('/', Platform.pathSeparator),
        ).exists(),
        isTrue,
      );
      expect(row.stock, 0);
    });
  });
}
