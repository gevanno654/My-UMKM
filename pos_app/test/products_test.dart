import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pos_app/core/db/app_db.dart';
import 'package:pos_app/core/router.dart';
import 'package:pos_app/features/auth/auth_provider.dart';
import 'package:pos_app/features/auth/auth_state.dart';
import 'package:pos_app/features/products/photo_store.dart';
import 'package:pos_app/features/products/product_form_screen.dart';
import 'package:pos_app/features/products/product_model.dart';
import 'package:pos_app/features/products/products_api.dart';
import 'package:pos_app/features/products/products_provider.dart';
import 'package:pos_app/features/products/products_screens.dart';
import 'package:pos_app/features/products/scan_screen.dart';

/// Auth state palsu: langsung terautentikasi (untuk repro boot layar produk).
class _FakeAuthNotifier extends AuthNotifier {
  static AuthProfile? profile;

  @override
  AuthState build() {
    final p = profile;
    if (p == null) return const AuthUnauthenticated();
    return AuthAuthenticated(p);
  }
}

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
      String photoPath = '',
      String photoHash = '',
      int photoSize = 0,
    }) => ProductModel(
      id: id,
      storeId: 'store-1',
      name: name,
      barcode: barcode,
      costPrice: 4000,
      sellPrice: 5000,
      stock: stock,
      photoPath: photoPath,
      photoHash: photoHash,
      photoSize: photoSize,
      createdAt: 1000,
      updatedAt: updatedAt,
    );

    Map<String, dynamic> serverRow({
      required String id,
      String name = 'Gula Pasir 1kg',
      String? barcode,
      required int updatedAtMillis,
      String? deletedAt,
      String photoHash = '',
      int photoSize = 0,
    }) => {
      'id': id,
      'name': name,
      'barcode': barcode,
      'costPrice': 4000,
      'sellPrice': 5000,
      'stock': 5,
      'category': '',
      'photoPath': '',
      'photoHash': photoHash,
      'photoSize': photoSize,
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

    test('save update bawa photoHash/photoSize', () async {
      final env = makeNotifier((options) => ok(options, []));
      await env.notifier.load('store-1');
      await env.notifier.saveProduct(product(id: 'p-1'));

      await env.notifier.saveProduct(
        product(id: 'p-1', photoHash: 'b' * 64, photoSize: 77),
      );

      final row = (await env.db.getProduct('p-1'))!;
      expect(row.photoHash, 'b' * 64);
      expect(row.photoSize, 77);
    });

    test(
        'push abaikan foto (single-writer = upload endpoint); pull pertahankan path lokal',
        () async {

      String? putPhotoHash;
      var putHasPhotoSize = false;
      final env = makeNotifier((options) {
        if (options.method == 'PUT') {
          final body = options.data as Map<String, dynamic>;
          putPhotoHash = body['photoHash'] as String?;
          putHasPhotoSize = body.containsKey('photoSize');
          return ok(options, serverRow(id: 'p-1', updatedAtMillis: 1000));
        }
        return ok(options, [
          serverRow(
            id: 'p-1',
            updatedAtMillis: 2000,
            photoHash: 'a' * 64,
            photoSize: 123,
          ),
        ]);
      });
      await env.notifier.load('store-1');
      await env.notifier.saveProduct(
        product(
          id: 'p-1',
          photoPath: 'product_photos/lokal.jpg',
          photoHash: 'c' * 64,
          photoSize: 9,
          updatedAt: 1000,
        ),
      );

      await env.notifier.syncNow(accessToken: 'access-1');

      // PUT tidak membawa foto: hash hanya ditulis server via upload
      // (upload otoritatif, mencegah hash-tanpa-file).
      expect(putPhotoHash, isNull);
      expect(putHasPhotoSize, isFalse);
      final row = (await env.db.getProduct('p-1'))!;
      expect(row.photoPath, 'product_photos/lokal.jpg');
      expect(row.photoHash, 'a' * 64);
      expect(row.photoSize, 123);
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

    test('pull: path lokal dipertahankan, hash ikut server', () async {      final env = makeNotifier((options) {
        if (options.method == 'GET' && options.path.endsWith('/products')) {
          return ok(options, [
            serverRow(
              id: 'p-1',
              updatedAtMillis: 2000,
              photoHash: 'a' * 64,
              photoSize: 123,
            ),
          ]);
        }
        return ok(options, []);
      });
      await env.notifier.load('store-1');
      await env.db.upsertProduct(
        ProductsCompanion.insert(
          id: 'p-1',
          storeId: 'store-1',
          name: 'Gula',
          barcode: const Value.absent(),
          costPrice: 4000,
          sellPrice: 5000,
          stock: const Value(10),
          photoPath: const Value('product_photos/lokal.jpg'),
          createdAt: 1000,
          updatedAt: 1000,
        ),
      );

      await env.notifier.pullCatalog('token');

      final row = (await env.db.getProduct('p-1'))!;
      expect(row.photoPath, 'product_photos/lokal.jpg');
      expect(row.photoHash, 'a' * 64);
      expect(row.photoSize, 123);
      expect(row.stock, 10);
    });
  });

  group('PhotoHash', () {
    test('sha256Of stabil 64-hex; baris bawa hash', () async {
      final tmp = await Directory.systemTemp.createTemp('photo_hash_test');
      final src = File('${tmp.path}/src.jpg');
      await src.writeAsBytes(const [0xff, 0xd8, 0xff, 0xd9]);
      final store = PhotoStore(docsDirOverride: tmp);

      final h1 = await store.sha256Of(src);
      final h2 = await store.sha256Of(src);
      expect(h1, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(h1, h2);

      await db.upsertStore(
        LocalStoresCompanion.insert(serverId: 'store-1', name: 'Toko Evan'),
      );
      await db.upsertProduct(
        ProductsCompanion.insert(
          id: 'p-hash',
          storeId: 'store-1',
          name: 'Kopi',
          barcode: const Value.absent(),
          costPrice: 2000,
          sellPrice: 3000,
          photoHash: Value(h1),
          photoSize: const Value(4),
          createdAt: 1,
          updatedAt: 1,
        ),
      );
      final row = (await db.getProduct('p-hash'))!;
      expect(row.photoHash, h1);
      expect(row.toModel().photoHash, h1);
    });
  });

  group('PhotoApi', () {
    Response<dynamic> okReq(RequestOptions o, Object? data,
            [int statusCode = 200]) =>
        Response(requestOptions: o, statusCode: statusCode, data: data);

    Never failReq(RequestOptions o, int statusCode, Object? data) {
      throw DioException(
        requestOptions: o,
        response: Response(
            requestOptions: o, statusCode: statusCode, data: data),
        type: DioExceptionType.badResponse,
      );
    }

    Dio photoDio(FutureOr<Response<dynamic>> Function(RequestOptions) respond) {
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

    test('upload kirim multipart field photo; 413 ramah', () async {
      String? uploadField;
      final api = ProductsApi(
        dio: photoDio((o) async {
          if (o.path.endsWith('/photo') && o.method == 'POST') {
            final form = o.data as FormData;
            uploadField = form.files.firstOrNull?.key;
            return okReq(o, {'photoHash': 'h' * 64, 'photoSize': 4});
          }
          return failReq(o, 413, {'error': 'photo too large'});
        }),
      );
      final tmp = await Directory.systemTemp.createTemp('photo_api_test');
      final src = File('${tmp.path}/a.jpg');
      await src.writeAsBytes(const [0xff, 0xd8, 0xff, 0xd9]);

      final r = await api.uploadPhoto(
          accessToken: 't', productId: 'p1', file: src);
      expect(uploadField, 'photo');
      expect(r.photoHash, hasLength(64));

      var msg = '';
      try {
        await ProductsApi(dio: photoDio((o) async => failReq(o, 413, {})))
            .uploadPhoto(accessToken: 't', productId: 'p1', file: src);
      } on DioException catch (e) {
        msg = ProductsApi.friendlyError(e);
      }
      expect(msg, contains('2MB'));
    });

    test('manifest + download bytes', () async {
      final api = ProductsApi(
        dio: photoDio((o) async {
          if (o.path.endsWith('/photo-manifest')) {
            return okReq(o, [
              {'id': 'p1', 'photoHash': 'h' * 64},
              {'id': 'p2', 'photoHash': ''},
            ]);
          }
          if (o.path.contains('/photos/')) {
            return okReq(o, [0xff, 0xd8, 0xff, 0xd9]);
          }
          return failReq(o, 404, {});
        }),
      );
      final man = await api.photoManifest('t');
      expect(man, {'p1': 'h' * 64, 'p2': ''});
      final bytes =
          await api.downloadPhoto(accessToken: 't', hash: 'h' * 64);
      expect(bytes, const [0xff, 0xd8, 0xff, 0xd9]);
    });
  });

  group('PhotoStore', () {
    test('savePicked → path relatif + file ada di temp', () async {
      final tmp = await Directory.systemTemp.createTemp('photo_store_test');
      // File sumber 1x1 PNG (cukup untuk uji salin file).
      final src = File('${tmp.path}/src.png');
      await src.writeAsBytes(const [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x62, 0x60, 0x00, 0x00, 0x00,
        0x02, 0x00, 0x01, 0xE5, 0x27, 0xDE, 0xFC, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82,
      ]);
      final store = PhotoStore(docsDirOverride: tmp);

      final relative = await store.savePicked(
        XFile(src.path),
        filename: 'uji.jpg',
      );

      expect(relative, startsWith('product_photos/'));
      expect(relative, endsWith('.jpg'));
      expect(await (await store.resolve(relative)).exists(), isTrue);
      expect(relative.contains('..'), isFalse);
    });
  });

  group('widget produk (provider mock)', () {
    // Catatan: seeding Drift + load() harus di dalam tester.runAsync —
    // await future isolate SQLite langsung di zona fake-async testWidgets
    // tidak pernah selesai (pola pumpAuthScreen di auth_online_test
    // menghindari await pra-pump karena alasan yang sama).
    Future<ProviderContainer> makeWidgetContainer(
      WidgetTester tester,
    ) async {
      final db = AppDb.openMemory();
      final container = ProviderContainer(
        overrides: [appDbProvider.overrideWithValue(db)],
      );
      addTearDown(db.close);
      addTearDown(container.dispose);
      await tester.runAsync(() async {
        await db.upsertProduct(
          productRow(id: 'p-gula', name: 'Gula Pasir 1kg', updatedAt: 10),
        );
        await db.upsertProduct(
          productRow(id: 'p-kopi', name: 'Kopi Tubruk', updatedAt: 9),
        );
        await container.read(productsProvider.notifier).load('store-1');
      });
      return container;
    }

    Future<void> pumpProducts(
      WidgetTester tester,
      Widget screen,
      ProviderContainer container,
    ) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: screen),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('daftar tampil dari provider mock', (tester) async {
      final container = await makeWidgetContainer(tester);
      await pumpProducts(tester, const ProductsListScreen(), container);

      expect(find.text('Gula Pasir 1kg'), findsOneWidget);
      expect(find.text('Kopi Tubruk'), findsOneWidget);
    });

    testWidgets('daftar muat otomatis dari sesi auth (tanpa load manual)', (
      tester,
    ) async {
      // Simulasi alur UI asli: provider fresh (belum load), layar dibuka
      // APA ADANYA. Auth terautentikasi → layar harus load sendiri dan
      // daftar tampil tanpa load() manual dari test.
      _FakeAuthNotifier.profile = const AuthProfile(
        id: 'user-1',
        storeId: 'store-1',
        name: 'Budi',
        email: 'budi@warung.id',
        storeName: 'Warung Barokah',
      );
      addTearDown(() => _FakeAuthNotifier.profile = null);
      late AppDb db;
      await tester.runAsync(() async {
        db = AppDb.openMemory();
        await db.upsertProduct(
          productRow(id: 'p-gula', name: 'Gula Pasir 1kg', updatedAt: 10),
        );
      });
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          appDbProvider.overrideWithValue(db),
          authProvider.overrideWith(_FakeAuthNotifier.new),
        ],
      );
      addTearDown(container.dispose);
      // Boot layar async (postFrame + Drift) + spinner animasi tak berujung:
      // pump manual, bukan pumpAndSettle.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProductsListScreen()),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Gula Pasir 1kg'), findsOneWidget);
    });

    testWidgets('form: nama kosong → error tampil', (tester) async {
      final container = await makeWidgetContainer(tester);
      await pumpProducts(
        tester,
        const ProductFormScreen(),
        container,
      );

      await tester.enterText(find.byKey(const Key('costField')), '1000');
      await tester.enterText(find.byKey(const Key('sellField')), '1500');
      await tester.tap(find.byKey(const Key('saveButton')));
      await tester.pumpAndSettle();

      expect(find.text('Nama produk wajib diisi'), findsOneWidget);
    });

    testWidgets('form: harga negatif → error tampil', (tester) async {
      final container = await makeWidgetContainer(tester);
      await pumpProducts(
        tester,
        const ProductFormScreen(),
        container,
      );

      await tester.enterText(find.byKey(const Key('nameField')), 'Gula');
      await tester.enterText(find.byKey(const Key('sellField')), '-5');
      await tester.tap(find.byKey(const Key('saveButton')));
      await tester.pumpAndSettle();

      expect(find.text('Harga jual harus angka 0..999999999'), findsOneWidget);
    });
  });

  group('router produk', () {
    const profile = AuthProfile(
      id: 'user-1',
      storeId: 'store-1',
      name: 'Budi',
      email: 'budi@warung.id',
      storeName: 'Warung Barokah',
    );

    test('authRedirect: PinLocked di /products → /pin-unlock', () {
      expect(
        authRedirect(const AuthPinLocked(profile), '/products'),
        '/pin-unlock',
      );
    });

    test('authRedirect: PinSetupRequired di /products → /pin-setup', () {
      expect(
        authRedirect(const AuthPinSetupRequired(profile), '/products'),
        '/pin-setup',
      );
    });

    test('authRedirect: Authenticated di /products → null', () {
      expect(
        authRedirect(const AuthAuthenticated(profile), '/products'),
        isNull,
      );
    });

    test('authRedirect: Unauthenticated di /products → /login', () {
      expect(
        authRedirect(const AuthUnauthenticated(), '/products'),
        '/login',
      );
    });

    test('appRoutePaths memuat route produk', () {
      expect(appRoutePaths, contains('/products'));
      expect(appRoutePaths, contains('/products/new'));
      expect(appRoutePaths, contains('/products/scan'));
      expect(appRoutePaths, contains('/products/:id'));
      expect(appRoutePaths, contains('/products/:id/edit'));
    });
  });

  group('firstBarcode', () {
    test('ambil barcode valid pertama, abaikan null/kosong', () {
      expect(firstBarcode([null, '', '  899123 ']), '899123');
    });

    test('kosong semua → null', () {
      expect(firstBarcode([]), isNull);
      expect(firstBarcode([null, '   ']), isNull);
    });
  });
}
