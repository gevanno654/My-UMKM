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
  static const keyPinSalt = 'pin_salt';
  static const keyProfileJson = 'profile_json';
  static const keyPinFailCount = 'pin_fail_count';
  static const keyPinLockedUntil = 'pin_locked_until';
  static const keyThemeMode = 'theme_mode';

  /// Kunci PIN milik [userId]. PIN diikat ke akun agar 2 akun di HP
  /// yang sama tidak saling memakai PIN.
  static String pinHashKey(String userId) => 'pin_hash_$userId';

  final SecureStorage _storage;

  Future<SessionTokens> readTokens() async {
    final accessToken = await _storage.read(keyAccessToken);
    final refreshToken = await _storage.read(keyRefreshToken);
    final profileJson = await _storage.read(keyProfileJson);
    return (
      accessToken: accessToken,
      refreshToken: refreshToken,
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

  Future<void> savePinHash({
    required String pin,
    required String userId,
  }) async {
    var salt = await _storage.read(keyPinSalt);
    salt ??= _newSalt();
    await _storage.write(keyPinSalt, salt);
    await _storage.write(pinHashKey(userId), _hashPin(pin, salt));
  }

  /// Hash PIN milik [userId]; null bila akun ini belum punya PIN.
  Future<String?> readPinHash(String userId) =>
      _storage.read(pinHashKey(userId));

  Future<bool> verifyPin(String pin, {String? userId}) async {
    final salt = await _storage.read(keyPinSalt);
    final stored = userId == null
        ? null
        : await _storage.read(pinHashKey(userId));
    if (salt == null || stored == null) return false;
    return _hashPin(pin, salt) == stored;
  }

  Future<void> clear() => _storage.deleteAll();

  /// Hapus sesi login (token + profil + counter/lockout) TANPA menghapus
  /// PIN per user — dipakai logout agar login ulang tidak perlu buat PIN baru.
  /// PIN ikut hilang saat install ulang/hapus data (storage dihapus OS).
  Future<void> clearSession() async {
    await _storage.delete(keyAccessToken);
    await _storage.delete(keyRefreshToken);
    await _storage.delete(keyProfileJson);
    await _storage.delete(keyPinFailCount);
    await _storage.delete(keyPinLockedUntil);
  }

  /// Jumlah percobaan PIN salah beruntun (untuk lockout brute-force).
  Future<int> readPinFailCount() async {
    final raw = await _storage.read(keyPinFailCount);
    return int.tryParse(raw ?? '') ?? 0;
  }

  Future<void> writePinFailCount(int count) =>
      _storage.write(keyPinFailCount, count.toString());

  Future<void> resetPinFailCount() => _storage.delete(keyPinFailCount);

  /// Batas waktu kunci (epoch millis UTC); null bila tidak terkunci.
  Future<DateTime?> readPinLockedUntil() async {
    final raw = await _storage.read(keyPinLockedUntil);
    final millis = int.tryParse(raw ?? '');
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  Future<void> writePinLockedUntil(DateTime until) => _storage.write(
        keyPinLockedUntil,
        until.toUtc().millisecondsSinceEpoch.toString(),
      );

  Future<void> clearPinLockedUntil() => _storage.delete(keyPinLockedUntil);

  /// Mode tema manual; null = ikut sistem.
  Future<String?> readThemeMode() => _storage.read(keyThemeMode);

  Future<void> writeThemeMode(String? mode) =>
      _storage.write(keyThemeMode, mode);

  static String _newSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static String _hashPin(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();
}
