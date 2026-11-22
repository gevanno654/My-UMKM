import 'package:dio/dio.dart';

import 'adjustments_provider.dart';

/// Client HTTP endpoint opname backend.
class AdjustmentsApi {
  AdjustmentsApi({Dio? dio, String? baseUrl})
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
        if (code == 'reason required') {
          return 'Alasan wajib diisi.';
        }
        if (code == 'no change') {
          return 'Stok sama, tidak ada perubahan.';
        }
        return 'Data tidak valid. Periksa kembali isian.';
      case 401:
        return 'Sesi kedaluwarsa. Silakan login ulang.';
      case 404:
        return 'Produk tidak ditemukan di server.';
      case 409:
        if (code == 'insufficient stock') {
          return 'Stok tidak cukup di server.';
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

  Future<List<AdjustmentModel>> list(String accessToken) async {
    final res = await _dio.get<List<dynamic>>(
      '/api/v1/adjustments',
      options: _auth(accessToken),
    );
    return res.data!.map((e) => _fromServer(e as Map<String, dynamic>)).toList();
  }

  Future<AdjustmentModel> create({
    required String accessToken,
    String? id,
    required String productId,
    required int physicalStock,
    required String reason,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/v1/adjustments',
      data: {
        'id': ?id,
        'productId': productId,
        'physicalStock': physicalStock,
        'reason': reason,
      },
      options: _auth(accessToken),
    );
    return _fromServer(res.data!);
  }

  Future<void> voidAdjustment({
    required String accessToken,
    required String id,
    required String reason,
  }) async {
    await _dio.post<void>(
      '/api/v1/adjustments/$id/void',
      data: {'reason': reason},
      options: _auth(accessToken),
    );
  }

  AdjustmentModel _fromServer(Map<String, dynamic> data) {
    return AdjustmentModel(
      id: data['id'] as String,
      storeId: '',
      productId: data['productId'] as String?,
      name: data['name'] as String? ?? '',
      stockBefore: (data['stockBefore'] as num).toInt(),
      stockAfter: (data['stockAfter'] as num).toInt(),
      diff: (data['diff'] as num).toInt(),
      reason: data['reason'] as String? ?? '',
      status: data['status'] as String? ?? 'ok',
      voidReason: data['voidReason'] as String?,
      createdAt: DateTime.parse(data['createdAt'] as String)
          .millisecondsSinceEpoch,
    );
  }
}
