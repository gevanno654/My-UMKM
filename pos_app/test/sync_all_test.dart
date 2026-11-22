import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/db/app_db.dart';
import 'package:pos_app/core/session/secure_session.dart';
import 'package:pos_app/core/sync/sync_all_provider.dart';
import 'package:pos_app/features/auth/auth_provider.dart';
import 'package:pos_app/features/auth/auth_state.dart';
import 'package:pos_app/features/products/products_api.dart';
import 'package:pos_app/features/products/products_provider.dart' as products;
import 'package:pos_app/features/restocks/restocks_api.dart';
import 'package:pos_app/features/restocks/restocks_provider.dart' as restocks;
import 'package:pos_app/features/sales/sales_api.dart';
import 'package:pos_app/features/sales/sales_provider.dart' as sales;
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
Future<({SyncAllNotifier notifier, AppDb db})> makeSyncAll({
  required Future<Response<dynamic>> Function(RequestOptions options)
  apiHandler,
  int initialStock = 0,
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
  // Restock lokal qty 5 -> stok jadi initialStock + 5, dokumen dirty.
  final restocksNotifier = container.read(restocks.restocksProvider.notifier);
  await restocksNotifier.load('store-1');
  final draftErr = await restocksNotifier.addToDraft('p1', qty: 5);
  assert(draftErr == null, draftErr);
  final saveErr = await restocksNotifier.saveRestock();
  assert(saveErr == null, saveErr);
  final notifier = container.read(syncAllProvider.notifier);
  return (notifier: notifier, db: db);
}

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
  });
}
