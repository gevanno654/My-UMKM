import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstraksi kecil di atas storage aman agar bisa di-mock di test.
abstract class SecureStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
  Future<void> delete(String key);
  Future<void> deleteAll();
}

class FlutterSecureStorageAdapter implements SecureStorage {
  FlutterSecureStorageAdapter([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String? value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}

typedef SessionTokens = ({
  String? accessToken,
  String? refreshToken,
  String? pinHash,
  String? profileJson,
});

/// Menyimpan sesi auth di secure storage perangkat.
///
/// PIN tidak pernah disimpan plaintext: yang disimpan hanya hash
/// SHA-256 dari `salt + pin` dengan salt acak per-perangkat.
class SecureSession {
  SecureSession({SecureStorage? storage})
      : _storage = storage ?? FlutterSecureStorageAdapter();

  static const keyAccessToken = 'access_token';
  static const keyRefreshToken = 'refresh_token';
  static const keyPinHash = 'pin_hash';
  static const keyPinSalt = 'pin_salt';
  static const keyProfileJson = 'profile_json';

  final SecureStorage _storage;

  Future<SessionTokens> readTokens() async {
    final accessToken = await _storage.read(keyAccessToken);
    final refreshToken = await _storage.read(keyRefreshToken);
    final pinHash = await _storage.read(keyPinHash);
    final profileJson = await _storage.read(keyProfileJson);
    return (
      accessToken: accessToken,
      refreshToken: refreshToken,
      pinHash: pinHash,
      profileJson: profileJson,
    );
  }

  Future<void> saveTokens({
    String? accessToken,
    String? refreshToken,
    String? profileJson,
  }) async {
    if (accessToken != null) {
      await _storage.write(keyAccessToken, accessToken);
    }
    if (refreshToken != null) {
      await _storage.write(keyRefreshToken, refreshToken);
    }
    if (profileJson != null) {
      await _storage.write(keyProfileJson, profileJson);
    }
  }

  Future<void> savePinHash({required String pin}) async {
    var salt = await _storage.read(keyPinSalt);
    salt ??= _newSalt();
    await _storage.write(keyPinSalt, salt);
    await _storage.write(keyPinHash, _hashPin(pin, salt));
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(keyPinSalt);
    final stored = await _storage.read(keyPinHash);
    if (salt == null || stored == null) return false;
    return _hashPin(pin, salt) == stored;
  }

  Future<void> clear() => _storage.deleteAll();

  static String _newSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static String _hashPin(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();
}
