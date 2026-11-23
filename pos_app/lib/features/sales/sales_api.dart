import 'package:dio/dio.dart';

import 'sale_model.dart';

/// Client HTTP endpoint kasir backend.
class SalesApi {
  SalesApi({Dio? dio, String? baseUrl})
    : _dio = dio ?? Dio(BaseOptions(
          baseUrl: baseUrl ?? const String.fromEnvironment(
            'API_URL',
            defaultValue: 'http://10.0.2.2:3000',
          ),
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {'Content-Type': 'application/json'},
        ));

  final Dio _dio;

  static String friendlyError(DioException e) {
    final data = e.response?.data;
    final code = data is Map ? data['error']?.toString() : null;
    switch (e.response?.statusCode) {
      case 400:
        if (code == 'paid less than total') {
          return 'Nominal bayar kurang dari total.';
        }
        if (code == 'reason required') {
          return 'Alasan void wajib diisi.';
        }
        return 'Data tidak valid. Periksa kembali isian.';
      case 401:
        return 'Sesi kedaluwarsa. Silakan login ulang.';
      case 404:
        return 'Produk tidak ditemukan di server.';
      case 409:
        if (code == 'insufficient stock') return 'Stok tidak cukup di server.';
        if (code == 'number taken') {
          return 'Nomor struk sudah dipakai. Buat transaksi baru.';
        }
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

  Options _auth(String accessToken) =>
      Options(headers: {'Authorization': 'Bearer $accessToken'});

  Future<List<SaleModel>> list(String accessToken) async {
    final res = await _dio.get<List<dynamic>>(
      '/api/v1/sales',
      options: _auth(accessToken),
    );
    return res.data!.map((e) => _fromServer(e as Map<String, dynamic>)).toList();
  }

  Future<SaleModel> create({
    required String accessToken,
    String? id,
    required String number,
    required List<SaleItemModel> items,
    required int paid,
    required PayMethod method,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/v1/sales',
      data: {
        'id': ?id,
        'number': number,
        'items': items
            .map((i) => {
              if (i.productId != null) 'productId': i.productId,
              if (i.productId == null) ...{
                'name': i.name,
                'price': i.price,
              },
              if (i.productId != null) 'costPrice': i.costPrice,
              'qty': i.qty,
            })
            .toList(),
        'paid': paid,
        'method': method.name,
      },
      options: _auth(accessToken),
    );
    return _fromServer(res.data!);
  }

  Future<void> voidSale({
    required String accessToken,
    required String id,
    required String reason,
  }) async {
    await _dio.post<void>(
      '/api/v1/sales/$id/void',
      data: {'reason': reason},
      options: _auth(accessToken),
    );
  }

  SaleModel _fromServer(Map<String, dynamic> data) {
    DateTime parseStamp(dynamic v) => DateTime.parse(v as String);
    final created = parseStamp(data['createdAt']);
    final items = (data['items'] as List)
        .map(
          (e) => SaleItemModel(
            id: (e as Map)['id'] as String,
            productId: e['productId'] as String?,
            name: e['name'] as String,
            price: (e['price'] as num).toInt(),
            costPrice: (e['costPrice'] as num?)?.toInt() ?? 0,
            qty: (e['qty'] as num).toInt(),
          ),
        )
        .toList();
    return SaleModel(
      id: data['id'] as String,
      storeId: '',
      number: data['number'] as String,
      total: (data['total'] as num).toInt(),
      paid: (data['paid'] as num).toInt(),
      change: (data['change'] as num).toInt(),
      method: PayMethod.values.byName(data['method'] as String),
      status: data['status'] as String? ?? 'ok',
      voidReason: data['voidReason'] as String?,
      createdAt: created.millisecondsSinceEpoch,
      items: items,
    );
  }
}
