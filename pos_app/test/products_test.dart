import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/db/app_db.dart';
import 'package:pos_app/features/auth/auth_provider.dart';
import 'package:pos_app/features/products/product_model.dart';
import 'package:pos_app/features/products/products_api.dart';
import 'package:pos_app/features/products/products_provider.dart';

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

  group('ProductsNotifier + ProductsApi (mock Dio)', () {
    ProductModel product({
      required String id,
      String name = 'Gula Pasir 1kg',
      String? barcode,
      int updatedAt = 1000,
      int stock = 5,
    }) => ProductModel(
      id: id,
      storeId: 'store-1',
      name: name,
      barcode: barcode,
      costPrice: 4000,
      sellPrice: 5000,
      stock: stock,
      createdAt: 1000,
      updatedAt: updatedAt,
    );

    Map<String, dynamic> serverRow({
      required String id,
      String name = 'Gula Pasir 1kg',
      String? barcode,
      required int updatedAtMillis,
      String? deletedAt,
    }) => {
      'id': id,
      'name': name,
      'barcode': barcode,
      'costPrice': 4000,
      'sellPrice': 5000,
      'stock': 5,
      'category': '',
      'photoPath': '',
      'updatedAt': DateTime.fromMillisecondsSinceEpoch(
        updatedAtMillis,
        isUtc: true,
      ).toIso8601String(),
      'deletedAt': deletedAt,
    };

    Response<dynamic> ok(RequestOptions options, Object? data,
            [int statusCode = 200]) =>
        Response(requestOptions: options, statusCode: statusCode, data: data);

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

    Dio stubDio(FutureOr<Response<dynamic>> Function(RequestOptions) respond) {
      final dio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:3000'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            try {
              handler.resolve(await respond(options));
            } on DioException catch (e) {
              handler.reject(e);
            }
          },
        ),
      );
      return dio;
    }

    ({ProductsNotifier notifier, AppDb db, ProviderContainer container})
    makeNotifier(FutureOr<Response<dynamic>> Function(RequestOptions) respond) {
      final db = AppDb.openMemory();
      final container = ProviderContainer(
        overrides: [
          appDbProvider.overrideWithValue(db),
          productsApiProvider.overrideWithValue(
            ProductsApi(dio: stubDio(respond)),
          ),
        ],
      );
      addTearDown(db.close);
      addTearDown(container.dispose);
      final notifier = container.read(productsProvider.notifier);
      return (notifier: notifier, db: db, container: container);
    }

    test('save valid → tampil di state', () async {
      final env = makeNotifier((options) => ok(options, []));
      await env.notifier.load('store-1');

      await env.notifier.saveProduct(product(id: 'p-1'));

      expect(
        env.notifier.state.products.map((e) => e.id),
        contains('p-1'),
      );
      expect(env.notifier.state.loading, isFalse);
      expect(env.notifier.state.lastError, isNull);
      expect((await env.db.getProduct('p-1'))!.name, 'Gula Pasir 1kg');
    });

    test('save nama kosong → error tampil, tidak macet', () async {
      final env = makeNotifier((options) => ok(options, []));
      await env.notifier.load('store-1');

      await env.notifier.saveProduct(product(id: 'p-1', name: '   '));

      expect(env.notifier.state.lastError, isNotNull);
      expect(env.notifier.state.loading, isFalse);
      expect(env.notifier.state.products, isEmpty);
    });

    test('save stok negatif → error tampil, tidak macet', () async {
      final env = makeNotifier((options) => ok(options, []));
      await env.notifier.load('store-1');

      await env.notifier.saveProduct(product(id: 'p-1', stock: -1));

      expect(env.notifier.state.lastError, isNotNull);
      expect(env.notifier.state.loading, isFalse);
      expect(env.notifier.state.products, isEmpty);
    });

    test('barcode duplikat lokal → error', () async {
      final env = makeNotifier((options) => ok(options, []));
      await env.notifier.load('store-1');
      await env.notifier.saveProduct(
        product(id: 'p-1', barcode: '899123'),
      );

      await env.notifier.saveProduct(
        product(id: 'p-2', name: 'Kopi', barcode: '899123'),
      );

      expect(env.notifier.state.lastError, isNotNull);
      expect(
        env.notifier.state.products.map((e) => e.id),
        isNot(contains('p-2')),
      );
    });

    test('sync: server lebih baru menang (LWW)', () async {
      final env = makeNotifier((options) {
        if (options.method == 'PUT') {
          return ok(options, serverRow(id: 'p-1', updatedAtMillis: 1000));
        }
        return ok(options, [
          serverRow(
            id: 'p-1',
            name: 'Gula Baru',
            updatedAtMillis:
                DateTime.now().toUtc().millisecondsSinceEpoch + 3600000,
          ),
        ]);
      });
      await env.notifier.load('store-1');
      await env.notifier.saveProduct(product(id: 'p-1', updatedAt: 1000));

      await env.notifier.syncNow(accessToken: 'access-1');

      expect(env.notifier.state.syncStatus, SyncStatus.idle);
      expect(
        env.notifier.state.products.singleWhere((e) => e.id == 'p-1').name,
        'Gula Baru',
      );
      expect((await env.db.getProduct('p-1'))!.dirty, 0);
    });

    test('sync: server deleted menang atas edit lokal', () async {
      final env = makeNotifier((options) {
        if (options.method == 'PUT') {
          return ok(options, serverRow(id: 'p-1', updatedAtMillis: 1000));
        }
        return ok(options, [
          serverRow(
            id: 'p-1',
            updatedAtMillis: 1000,
            deletedAt: DateTime.now()
                .toUtc()
                .add(const Duration(hours: 1))
                .toIso8601String(),
          ),
        ]);
      });
      await env.notifier.load('store-1');
      await env.notifier.saveProduct(product(id: 'p-1', updatedAt: 1000));

      await env.notifier.syncNow(accessToken: 'access-1');

      expect(env.notifier.state.syncStatus, SyncStatus.idle);
      expect(
        env.notifier.state.products.where((e) => e.id == 'p-1'),
        isEmpty,
      );
      expect((await env.db.getProduct('p-1'))!.deletedAt, isNotNull);
    });

    test('sync: 401 → status error + pesan login ulang', () async {
      final env = makeNotifier(
        (options) => fail(options, 401, {'error': 'missing token'}),
      );
      await env.notifier.load('store-1');
      await env.notifier.saveProduct(product(id: 'p-1'));

      await env.notifier.syncNow(accessToken: 'kedaluwarsa');

      expect(env.notifier.state.syncStatus, SyncStatus.error);
      expect(env.notifier.state.lastError, contains('login ulang'));
    });

    test('sync: 404 saat PUT → POST ulang lalu bersih', () async {
      var postCalled = false;
      final env = makeNotifier((options) {
        if (options.method == 'PUT') {
          return fail(options, 404, {'error': 'not found'});
        }
        if (options.method == 'POST') {
          postCalled = true;
          return ok(options, serverRow(id: 'p-1', updatedAtMillis: 1000), 201);
        }
        return ok(options, <Map<String, dynamic>>[]);
      });
      await env.notifier.load('store-1');
      await env.notifier.saveProduct(product(id: 'p-1'));

      await env.notifier.syncNow(accessToken: 'access-1');

      expect(postCalled, isTrue);
      expect(env.notifier.state.syncStatus, SyncStatus.idle);
      expect((await env.db.getProduct('p-1'))!.dirty, 0);
    });

    test('sync: 409 barcode → lastError per baris, baris lain lanjut', () async {
      final env = makeNotifier((options) {
        if (options.method == 'PUT' &&
            options.path.endsWith('p-konflik')) {
          return fail(options, 409, {'error': 'barcode taken'});
        }
        if (options.method == 'PUT') {
          return ok(options, serverRow(id: 'p-ok', updatedAtMillis: 3000));
        }
        return ok(options, <Map<String, dynamic>>[]);
      });
      await env.notifier.load('store-1');
      await env.notifier.saveProduct(
        product(id: 'p-konflik', barcode: '899999', updatedAt: 3000),
      );
      await env.db.upsertProduct(
        productRow(id: 'p-ok', name: 'Teh', barcode: '111', updatedAt: 3000),
      );

      await env.notifier.syncNow(accessToken: 'access-1');

      expect(env.notifier.state.lastError, contains('Barcode sudah dipakai'));
      expect((await env.db.getProduct('p-ok'))!.dirty, 0);
      expect((await env.db.getProduct('p-konflik'))!.dirty, 1);
    });
  });
}
