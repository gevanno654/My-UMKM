import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../core/session/secure_session.dart';

/// Error cetak dengan pesan ramah untuk snackbar.
class PrinterException implements Exception {
  PrinterException(this.message);

  final String message;

  @override
  String toString() => 'PrinterException: $message';
}

/// Kunci MAC printer tersimpan (per-HP, tidak ikut sinkron).
const printerMacKey = 'printer_mac';

/// Adapter tipis di atas print_bluetooth_thermal agar bisa di-fake di test.
class PrinterAdapter {
  Future<bool> get bluetoothEnabled => PrintBluetoothThermal.bluetoothEnabled;

  Future<List<BluetoothInfo>> paired() => PrintBluetoothThermal.pairedBluetooths;

  Future<bool> connect(String mac) =>
      PrintBluetoothThermal.connect(macPrinterAddress: mac);

  Future<bool> writeBytes(List<int> bytes) => PrintBluetoothThermal.writeBytes(bytes);

  Future<bool> get disconnect => PrintBluetoothThermal.disconnect;
}

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
    final on = await _adapter.bluetoothEnabled;
    if (!on) throw PrinterException('Nyalakan Bluetooth dulu.');
    final ok = await _adapter.connect(target);
    if (!ok) throw PrinterException('Printer tidak terjangkau. Cek printer nyala.');
    try {
      final wrote = await _adapter.writeBytes(bytes);
      if (!wrote) throw PrinterException('Gagal mencetak. Coba lagi.');
    } finally {
      await _adapter.disconnect;
    }
  }
}
