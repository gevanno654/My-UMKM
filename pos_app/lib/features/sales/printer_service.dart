import 'dart:convert';

import 'package:permission_handler/permission_handler.dart' as ph;
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

/// Hasil minta izin Bluetooth runtime.
enum PrinterPermission { granted, denied, permanentlyDenied }

/// Dibutuhkan saat izin belum granted TAPI user menolak permanen:
/// arahkan ke layar siapkan (ada tombol Buka Pengaturan).
class PrinterNeedsSetupException implements Exception {}

/// Kunci lama era dialog pilih (hanya MAC). Jangan dipakai untuk tulis baru;
/// dibaca sekali untuk migrasi ke [printerJsonKey], lalu boleh dihapus.
const printerMacKey = 'printer_mac';

/// Kunci lama nama era dua-kunci. Sama: hanya untuk migrasi satu arah.
const printerNameKey = 'printer_name';

/// Satu-satunya kunci tulis printer: JSON {"name","mac"} agar atomik.
const printerJsonKey = 'printer_json';

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

  @Deprecated('Pakai savePrinter; hanya-MAC tidak punya nama tampilan.')
  Future<String?> savedMac() async {
    final saved = await savedPrinter();
    return saved?.$2;
  }

  @Deprecated('Pakai savePrinter agar nama+MAC atomik.')
  Future<void> saveMac(String mac) => savePrinter(name: mac, mac: mac);

  /// Simpan nama+MAC atomik dalam satu kunci JSON.
  Future<void> savePrinter({required String name, required String mac}) =>
      _storage.write(printerJsonKey, jsonEncode({'name': name, 'mac': mac}));

  /// Printer tersimpan (nama, mac); null bila belum disiapkan.
  ///
  /// Migrasi satu arah: data lama (MAC saja atau dua kunci era awal)
  /// dibaca sekali lalu ditulis ulang sebagai JSON atomik.
  Future<(String, String)?> savedPrinter() async {
    final raw = await _storage.read(printerJsonKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final name = decoded['name'] as String?;
        final mac = decoded['mac'] as String?;
        if (name != null && name.isNotEmpty && mac != null && mac.isNotEmpty) {
          return (name, mac);
        }
      } on FormatException {
        // JSON rusak → jatuh ke migrasi/paksa siapkan ulang.
      }
    }
    final name = await _storage.read(printerNameKey);
    var mac = await _storage.read(printerMacKey);
    if ((mac == null || mac.isEmpty) && name != null && name.isNotEmpty) {
      mac = name;
    }
    if (mac == null || mac.isEmpty) return null;
    final resolved = (name != null && name.isNotEmpty) ? name : mac;
    await savePrinter(name: resolved, mac: mac);
    await _storage.delete(printerNameKey);
    await _storage.delete(printerMacKey);
    return (resolved, mac);
  }

  /// Daftar printer yang sudah di-pair di HP.
  Future<List<BluetoothInfo>> pairedPrinters() => _adapter.paired();

  /// Minta izin Bluetooth resmi via popup sistem.
  /// denied → boleh diminta lagi nanti; permanentlyDenied → Buka Pengaturan.
  Future<PrinterPermission> requestPermission() async {
    final s = await ph.Permission.bluetoothConnect.request();
    if (s.isGranted || s.isLimited) return PrinterPermission.granted;
    if (s.isPermanentlyDenied) return PrinterPermission.permanentlyDenied;
    return PrinterPermission.denied;
  }

  /// Buka halaman Pengaturan aplikasi (untuk izin yang ditolak permanen).
  Future<void> openSettings() => ph.openAppSettings();

  /// Cetak [bytes] ke printer [mac] (atau MAC tersimpan).
  ///
  /// Lempar [PrinterException] dengan pesan ramah untuk semua kegagalan.
  Future<void> printBytes(List<int> bytes, {String? mac}) async {
    String? target = mac;
    target ??= (await savedPrinter())?.$2;
    if (target == null || target.isEmpty) {
      throw PrinterException('Belum ada printer tersimpan. Pilih printer dulu.');
    }
    final granted = await _adapter.permissionGranted;
    if (!granted) {
      throw PrinterNeedsSetupException();
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
