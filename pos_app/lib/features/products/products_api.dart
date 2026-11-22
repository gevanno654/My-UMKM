import 'package:dio/dio.dart';

import '../../core/db/app_db.dart';
import 'product_model.dart';

/// Client HTTP endpoint produk backend.
///
/// `baseUrl` diisi dari `--dart-define API_URL`, default alamat
/// loopback emulator Android (`http://10.0.2.2:3000`).
class ProductsApi {
  ProductsApi({Dio? dio, String? baseUrl})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ??
                    const String.fromEnvironment(
                      'API_URL',
                      defaultValue: 'http://10.0.2.2:3000',
                    ),
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                headers: {'Content-Type': 'application/json'},
              ),
            );

  final Dio _dio;

  static String friendlyError(DioException e) {
    final data = e.response?.data;
    final code = data is Map ? data['error']?.toString() : null;
    switch (e.response?.statusCode) {
      case 400:
        return 'Data tidak valid. Periksa kembali isian.';
      case 401:
        return 'Sesi kedaluwarsa. Silakan login ulang.';
      case 404:
        return 'Produk tidak ditemukan di server.';
      case 409:
        if (code == 'barcode taken') return 'Barcode sudah dipakai';
        return 'Data bentrok dengan server.';
      default:
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError) {
          return 'Tidak dapat terhubung ke server. Periksa koneksi.';
        }
        return 'Terjadi kesalahan. Coba lagi.';
    }
  }

  Options _auth(String accessToken) => Options(
        headers: {'Authorization': 'Bearer $accessToken'},
      );

  Future<List<ProductModel>> list(String accessToken, String storeId) async {
    final res = await _dio.get<List<dynamic>>(
      '/api/v1/products',
      options: _auth(accessToken),
    );
    return res.data!
        .map((e) => _fromServer(e as Map<String, dynamic>, storeId))
        .toList();
  }

  Future<ProductModel> create(String accessToken, ProductModel p) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/v1/products',
      data: _toServer(p),
      options: _auth(accessToken),
    );
    return _fromServer(res.data!, p.storeId);
  }

  Future<ProductModel> update(String accessToken, ProductModel p) async {
    final res = await _dio.put<Map<String, dynamic>>(
      '/api/v1/products/${p.id}',
      data: _toServer(p),
      options: _auth(accessToken),
    );
    return _fromServer(res.data!, p.storeId);
  }

  Future<void> remove(String accessToken, String id) async {
    await _dio.delete<void>(
      '/api/v1/products/$id',
      options: _auth(accessToken),
    );
  }

  /// Body produk ke server: hanya field katalog + harga.
  /// STOK TIDAK PERNAH DIKIRIM (selalu 0): server satu-satunya sumber
  /// hitung stok (hanya berubah via dokumen restock/sale/adjustment),
  /// sehingga push katalog tidak bisa mengacaukan stok cloud. Stok 0 =
  /// baseline produk baru, bukan angka yang menimpa.
  Map<String, dynamic> _toServer(ProductModel p) => {
        'id': p.id,
        'name': p.name,
        'barcode': ProductModel.normalizeBarcode(p.barcode),
        'costPrice': p.costPrice,
        'sellPrice': p.sellPrice,
        'stock': 0,
        'category': p.category,
      };

  ProductModel _fromServer(Map<String, dynamic> data, String storeId) {
    DateTime parseStamp(dynamic v, {bool allowNull = false}) {
      if (v == null && allowNull) {
        return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      }
      return DateTime.parse(v as String);
    }

    final updated = parseStamp(data['updatedAt']);
    final deletedRaw = data['deletedAt'];
    final deleted = deletedRaw == null
        ? null
        : parseStamp(deletedRaw, allowNull: true).millisecondsSinceEpoch == 0
            ? null
            : parseStamp(deletedRaw).millisecondsSinceEpoch;
    return ProductModel(
      id: data['id'] as String,
      storeId: storeId,
      name: data['name'] as String,
      barcode: data['barcode'] as String?,
      costPrice: (data['costPrice'] as num).toInt(),
      sellPrice: (data['sellPrice'] as num).toInt(),
      stock: (data['stock'] as num?)?.toInt() ?? 0,
      category: data['category'] as String? ?? '',
      photoPath: data['photoPath'] as String? ?? '',
      createdAt: updated.millisecondsSinceEpoch,
      updatedAt: updated.millisecondsSinceEpoch,
      deletedAt: deleted,
    );
  }
}

/// Konversi baris Drift → domain (dipakai provider + test sinkron).
extension ProductRowX on Product {
  ProductModel toModel() => ProductModel(
        id: id,
        storeId: storeId,
        name: name,
        barcode: barcode,
        costPrice: costPrice,
        sellPrice: sellPrice,
        stock: stock,
        category: category,
        photoPath: photoPath,
        isArchived: isArchived,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      );
}
