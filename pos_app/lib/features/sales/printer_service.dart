import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../core/session/secure_session.dart';

/// Error cetak dengan pesan ramah untuk snackbar.
class PrinterException implements Exception {
  PrinterException(this.message);

  final String message;

  @override
  String toString() => 'PrinterException: $message';
}

/// Timeout tiap panggil native: plugin menggantung (tanpa result) bila
/// izin BLUETOOTH_CONNECT ditolak — tanpa ini UI diam selamanya.
const _nativeTimeout = Duration(seconds: 15);

/// Kunci MAC printer tersimpan (per-HP, tidak ikut sinkron).
const printerMacKey = 'printer_mac';

/// Adapter tipis di atas print_bluetooth_thermal agar bisa di-fake di test.
class PrinterAdapter {
  Future<bool> get permissionGranted =>
      PrintBluetoothThermal.isPermissionBluetoothGranted
          .timeout(_nativeTimeout, onTimeout: () => false);

  Future<bool> get bluetoothEnabled => PrintBluetoothThermal.bluetoothEnabled
      .timeout(_nativeTimeout, onTimeout: () => throw PrinterException(_timeoutMsg));

  Future<List<BluetoothInfo>> paired() => PrintBluetoothThermal.pairedBluetooths
      .timeout(_nativeTimeout, onTimeout: () => throw PrinterException(_timeoutMsg));

  Future<bool> connect(String mac) =>
      PrintBluetoothThermal.connect(macPrinterAddress: mac)
          .timeout(_nativeTimeout, onTimeout: () => false);

  Future<bool> writeBytes(List<int> bytes) => PrintBluetoothThermal.writeBytes(bytes)
      .timeout(_nativeTimeout, onTimeout: () => false);

  Future<bool> get disconnect => PrintBluetoothThermal.disconnect
      .timeout(_nativeTimeout, onTimeout: () => false);
}

const _timeoutMsg = 'Printer tidak merespons. Cek printer nyala + izin Bluetooth.';

/// Service printer thermal: simpan MAC + cetak byte ESC/POS.
class PrinterService {
  PrinterService({SecureStorage? storage, PrinterAdapter? adapter})
    : _storage = storage ?? FlutterSecureStorageAdapter(),
      _adapter = adapter ?? PrinterAdapter();

  final SecureStorage _storage;
  final PrinterAdapter _adapter;

  Future<String?> savedMac() => _storage.read(printerMacKey);

  Future<void> saveMac(String mac) => _storage.write(printerMacKey, mac);

  /// Daftar printer yang sudah di-pair di HP.
  Future<List<BluetoothInfo>> pairedPrinters() => _adapter.paired();

  /// Cetak [bytes] ke printer [mac] (atau MAC tersimpan).
  ///
  /// Lempar [PrinterException] dengan pesan ramah untuk semua kegagalan.
  Future<void> printBytes(List<int> bytes, {String? mac}) async {
    final target = mac ?? await savedMac();
    if (target == null || target.isEmpty) {
      throw PrinterException('Belum ada printer tersimpan. Pilih printer dulu.');
    }
    final granted = await _adapter.permissionGranted;
    if (!granted) {
      throw PrinterException(
        'Izin Bluetooth belum diberikan. Aktifkan "Perangkat di sekitar" untuk aplikasi ini di Pengaturan HP.',
      );
    }
    final on = await _adapter.bluetoothEnabled;
    if (!on) throw PrinterException('Nyalakan Bluetooth dulu.');
    final ok = await _adapter.connect(target);
    if (!ok) throw PrinterException('Printer tidak terjangkau. Cek printer nyala.');
    try {
      final wrote = await _adapter.writeBytes(bytes);
      if (!wrote) throw PrinterException('Gagal mencetak. Coba lagi.');
    } finally {
      try {
        await _adapter.disconnect;
      } catch (_) {
        // Abaikan: error disconnect tak boleh menutupi hasil cetak.
      }
    }
  }
}
