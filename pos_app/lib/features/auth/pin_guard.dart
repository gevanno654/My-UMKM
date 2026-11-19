import '../../core/session/secure_session.dart';

/// Gerbang PIN offline: menentukan apakah app bisa dibuka dengan PIN
/// dan menegakkan lockout brute-force (5x salah → kunci 60 detik).
///
/// Semua pemeriksaan murni lokal (secure storage); tidak menyentuh jaringan.
class PinGuard {
  PinGuard({required SecureSession session}) : _session = session;

  final SecureSession _session;

  static const maxAttempts = 5;
  static const lockout = Duration(seconds: 60);

  /// true bila `pinHash + profileJson + accessToken` ketiganya ada.
  Future<bool> canUnlockOffline() async {
    final tokens = await _session.readTokens();
    return tokens.pinHash != null &&
        tokens.profileJson != null &&
        tokens.accessToken != null;
  }

  /// Verifikasi PIN: true bila cocok dan tidak sedang terkunci.
  ///
  /// PIN salah menaikkan counter; mencapai [maxAttempts] → kunci [lockout].
  /// PIN benar me-reset counter + kunci.
  Future<bool> verifyPin(String pin) async {
    if (await isLocked()) return false;
    final ok = await _session.verifyPin(pin);
    if (ok) {
      await _session.resetPinFailCount();
      await _session.clearPinLockedUntil();
      return true;
    }
    final fails = await _session.readPinFailCount() + 1;
    await _session.writePinFailCount(fails);
    if (fails >= maxAttempts) {
      await _session.writePinLockedUntil(DateTime.now().add(lockout));
    }
    return false;
  }

  /// true bila masih dalam masa kunci.
  Future<bool> isLocked() async {
    final until = await lockedUntil();
    return until != null && until.isAfter(DateTime.now());
  }

  /// Batas waktu kunci saat ini; null bila tidak terkunci / sudah lewat.
  Future<DateTime?> lockedUntil() => _session.readPinLockedUntil();

  /// Counter salah beruntun saat ini (berguna untuk pesan "sisa percobaan").
  Future<int> failCount() => _session.readPinFailCount();

  /// Sisa percobaan sebelum terkunci (0 bila sudah terkunci).
  Future<int> remainingAttempts() async {
    if (await isLocked()) return 0;
    final remaining = maxAttempts - await failCount();
    return remaining.clamp(0, maxAttempts).toInt();
  }
}
