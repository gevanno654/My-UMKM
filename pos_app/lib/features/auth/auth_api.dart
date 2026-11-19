import 'package:dio/dio.dart';

import 'auth_state.dart';

/// Client HTTP untuk endpoint auth backend.
///
/// `baseUrl` diisi dari `--dart-define API_URL`, default alamat
/// loopback emulator Android (`http://10.0.2.2:3000`).
class AuthApi {
  AuthApi({Dio? dio, String? baseUrl})
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
        if (code == 'invalid refresh token') {
          return 'Sesi kedaluwarsa. Silakan login ulang.';
        }
        return 'Email atau password salah';
      case 409:
        return 'Email sudah terdaftar';
      default:
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError) {
          return 'Tidak dapat terhubung ke server. Periksa koneksi.';
        }
        return 'Terjadi kesalahan. Coba lagi.';
    }
  }

  Future<AuthResult> register({
    required String storeName,
    required String ownerName,
    required String email,
    required String password,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/register',
      data: {
        'storeName': storeName,
        'ownerName': ownerName,
        'email': email,
        'password': password,
      },
    );
    return _toResult(res.data!);
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/login',
      data: {'email': email, 'password': password},
    );
    return _toResult(res.data!);
  }

  Future<AuthProfile> fetchMe(String accessToken) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/v1/me',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = res.data!;
    return AuthProfile(
      id: (data['user'] as Map)['id'] as String,
      storeId: (data['user'] as Map)['storeId'] as String,
      name: (data['user'] as Map)['name'] as String,
      email: (data['user'] as Map)['email'] as String,
      storeName: (data['store'] as Map)['name'] as String,
    );
  }

  /// Memutar refresh token; mengembalikan pasangan token baru.
  Future<({String accessToken, String refreshToken})> refresh(
    String refreshToken,
  ) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    final data = res.data!;
    return (
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
  }

  AuthResult _toResult(Map<String, dynamic> data) => AuthResult(
        profile: AuthProfile.fromJson(data),
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
}
