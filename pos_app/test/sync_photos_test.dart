import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/db/app_db.dart';
import 'package:pos_app/features/auth/auth_provider.dart';
import 'package:pos_app/features/products/photo_store.dart';
import 'package:pos_app/features/products/products_api.dart';
import 'package:pos_app/features/products/products_provider.dart';

Response<dynamic> _ok(RequestOptions o, Object? data,
        [int statusCode = 200]) =>
    Response(requestOptions: o, statusCode: statusCode, data: data);

void _fail(RequestOptions o, int statusCode, Object? data) {
  throw DioException(
    requestOptions: o,
    response: Response(requestOptions: o, statusCode: statusCode, data: data),
    type: DioExceptionType.badResponse,
  );
}

/// Fake Dio untuk foto: manifest + upload 200/photoHash + download 4 bytes.
/// [failIds] memaksa 413 pada upload produk tertentu (uji parsial).
({Dio dio, List<String> uploaded, List<String> downloaded}) fakePhotoDio({
  required Map<String, String> manifest,
  Set<String> failIds = const {},
}) {
  final uploaded = <String>[];
  final downloaded = <String>[];
  final dio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:3000'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          if (options.path.endsWith('/photo-manifest')) {
            handler.resolve(
              _ok(options, [
                for (final e in manifest.entries)
                  {'id': e.key, 'photoHash': e.value},
              ]),
            );
            return;
          }
          if (options.path.endsWith('/photo') && options.method == 'POST') {
            final segs = options.path.split('/');
            final id = segs[segs.length - 2];
            if (failIds.contains(id)) {
              return _fail(options, 413, {'error': 'photo too large'});
            }
            uploaded.add(id);
            handler.resolve(
              _ok(options, {'photoHash': '9' * 64, 'photoSize': 4}),
            );
            return;
          }
          if (options.path.contains('/photos/')) {
            downloaded.add(options.path.split('/').last);
            handler.resolve(_ok(options, const [0xff, 0xd8, 0xff, 0xd9]));
            return;
          }
          return _fail(options, 404, {});
        } on DioException catch (e) {
          handler.reject(e);
        }
      },
    ),
  );
  return (dio: dio, uploaded: uploaded, downloaded: downloaded);
}

({ProductsNotifier notifier, AppDb db, PhotoStore store, Directory tmp,
    ProviderContainer container}) makeEnv(
  Dio dio,
) {
  final tmp = Directory.systemTemp.createTempSync('sync_photos_test');
  addTearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });
  final db = AppDb.openMemory();
  final store = PhotoStore(docsDirOverride: tmp);
  final container = ProviderContainer(
    overrides: [
      appDbProvider.overrideWithValue(db),
      productsApiProvider.overrideWithValue(ProductsApi(dio: dio)),
    ],
  );
  addTearDown(db.close);
  addTearDown(container.dispose);
  return (
    notifier: container.read(productsProvider.notifier),
    db: db,
    store: store,
    tmp: tmp,
    container: container,
  );
}

Future<void> seedProduct(
  AppDb db, {
  required String id,
  int updatedAt = 1000,
  String photoPath = '',
  String photoHash = '',
  int photoSize = 0,
}) =>
    db.upsertProduct(
      ProductsCompanion.insert(
        id: id,
        storeId: 'store-1',
        name: 'P-$id',
        barcode: const Value.absent(),
        costPrice: 1000,
        sellPrice: 2000,
        photoPath: Value(photoPath),
        photoHash: Value(photoHash),
        photoSize: Value(photoSize),
        createdAt: 1,
        updatedAt: updatedAt,
      ),
    );

void main() {
  test('syncPhotos upload hanya yang berubah + unduh yang kurang', () async {
    // p1: lokal Hc9 (file ada), server kosong → upload 1x.
    // p2: lokal == server (hash sama) → no-op.
    // p3: server hash H3, lokal tidak punya → download 1x + file ada.
    final fake = fakePhotoDio(manifest: {
      'p1': '',
      'p2': 'h' * 64,
      'p3': '3' * 64,
    });
    final env = makeEnv(fake.dio);
    await env.notifier.load('store-1');
    final f1 = File('${env.tmp.path}/f1.jpg');
    await f1.writeAsBytes(const [1, 2, 3, 4]);
    final h1 = await env.store.sha256Of(f1);
    final rel1 = 'product_photos/f1.jpg';
    await (await env.store.resolve(rel1)).parent.create(recursive: true);
    await f1.copy((await env.store.resolve(rel1)).path);
    await seedProduct(env.db,
        id: 'p1', photoPath: rel1, photoHash: h1, photoSize: 4);
    await seedProduct(env.db,
        id: 'p2', photoPath: 'product_photos/p2.jpg', photoHash: 'h' * 64);
    await seedProduct(env.db, id: 'p3');

    final errors = <String>[];
    await env.notifier.syncPhotos(
      'token',
      photoStore: env.store,
      onFileError: errors.add,
    );

    expect(fake.uploaded, ['p1']);
    expect(errors, isEmpty);
    final p1 = (await env.db.getProduct('p1'))!;
    expect(p1.photoHash, '9' * 64);
    // Hash baru ditandai dirty agar ikut push katalog berikutnya.
    expect(p1.dirty, 1);
    // p2: hash sama tapi file lokal tidak pernah dibuat → unduh ulang;
    // p3: hash server baru → unduh.
    expect(fake.downloaded, containsAll(['h' * 64, '3' * 64]));
    final p3 = (await env.db.getProduct('p3'))!;
    expect(p3.photoHash, '3' * 64);
    expect(
      await (await env.store.resolve(p3.photoPath)).exists(),
      isTrue,
    );
  });

  test('satu file 413 → lanjut file lain + error parsial', () async {
    final fake = fakePhotoDio(
      manifest: {'p1': '', 'p2': ''},
      failIds: {'p1'},
    );
    final env = makeEnv(fake.dio);
    await env.notifier.load('store-1');
    for (final id in ['p1', 'p2']) {
      final rel = 'product_photos/$id.jpg';
      final f = await env.store.resolve(rel);
      await f.parent.create(recursive: true);
      await f.writeAsBytes([1, 2, 3, id.codeUnitAt(1)]);
      final hash = await env.store.sha256Of(f);
      await seedProduct(env.db,
          id: id, photoPath: rel, photoHash: hash, photoSize: 4);
    }

    final errors = <String>[];
    await env.notifier.syncPhotos(
      'token',
      photoStore: env.store,
      onFileError: errors.add,
    );

    expect(fake.uploaded, ['p2']);
    expect(errors, hasLength(1));
    expect((await env.db.getProduct('p2'))!.photoHash, '9' * 64);
  });

  test('purge delete: panggil DELETE photo sekali, abaikan 404', () async {
    var deletePhotoCalls = 0;
    final dio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:3000'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            if (options.method == 'DELETE' && options.path.endsWith('/photo')) {
              deletePhotoCalls++;
              return _fail(options, 404, {'error': 'not found'});
            }
            if (options.method == 'DELETE') {
              handler.resolve(_ok(options, {'deleted': true}));
              return;
            }
            if (options.method == 'GET') {
              handler.resolve(_ok(options, []));
              return;
            }
            return _fail(options, 404, {});
          } on DioException catch (e) {
            handler.reject(e);
          }
        },
      ),
    );
    final env = makeEnv(dio);
    await env.notifier.load('store-1');
    await seedProduct(env.db, id: 'p1');
    await env.db.softDeleteProduct('p1', 2000);

    await env.notifier.syncNow(accessToken: 't');

    // pushCatalog delete → DELETE produk + DELETE foto.
    expect(deletePhotoCalls, 1);
    expect(env.notifier.state.syncStatus, SyncStatus.idle);
  });

  test('manifest offline → syncPhotos return diam-diam', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:3000'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
            ),
          );
        },
      ),
    );
    final env = makeEnv(dio);
    await env.notifier.load('store-1');
    await seedProduct(env.db, id: 'p1');

    final errors = <String>[];
    await env.notifier.syncPhotos(
      'token',
      photoStore: env.store,
      onFileError: errors.add,
    );

    expect(errors, isEmpty);
  });

  test('file lokal hilang → skip tanpa throw', () async {    final fake = fakePhotoDio(manifest: {'p1': ''});
    final env = makeEnv(fake.dio);
    await env.notifier.load('store-1');
    await seedProduct(env.db,
        id: 'p1',
        photoPath: 'product_photos/hilang.jpg',
        photoHash: 'x' * 64,
        photoSize: 4);

    final errors = <String>[];
    await env.notifier.syncPhotos(
      'token',
      photoStore: env.store,
      onFileError: errors.add,
    );

    expect(fake.uploaded, isEmpty);
    expect(errors, isEmpty);
  });
}
