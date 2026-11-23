import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/session/secure_session.dart';
import 'package:pos_app/features/sales/printer_service.dart';
import 'package:pos_app/features/sales/receipt_bytes.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

class FakeSecureStorage implements SecureStorage {
  final map = <String, String>{};

  @override
  Future<void> delete(String key) async {
    map.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    map.clear();
  }

  @override
  Future<String?> read(String key) async => map[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      map.remove(key);
    } else {
      map[key] = value;
    }
  }
}

BluetoothInfo bt(String name) => BluetoothInfo(name: name, macAdress: 'AA');

void main() {
  test('RPP02N dan nama khas lolos, TWS ke grup lain', () {
    expect(isLikelyPrinter('RPP02N'), isTrue);
    expect(isLikelyPrinter('XPrinter XP-N160I'), isTrue);
    expect(isLikelyPrinter('TWS Pro'), isFalse);
    final parts = partitionPrinters([bt('RPP02N'), bt('TWS Pro')]);
    expect(parts.printers.map((b) => b.name), ['RPP02N']);
    expect(parts.others.map((b) => b.name), ['TWS Pro']);
  });

  test('nama+MAC tersimpan berpasangan', () async {
    final svc = PrinterService(storage: FakeSecureStorage());
    expect(await svc.savedPrinter(), isNull);
    await svc.savePrinter(name: 'RPP02N', mac: 'AA:BB:CC:DD:EE:FF');
    expect(await svc.savedPrinter(), ('RPP02N', 'AA:BB:CC:DD:EE:FF'));
  });

  test('simpanan atomik satu kunci + migrasi dari kunci lama', () async {
    final storage = FakeSecureStorage();
    final svc = PrinterService(storage: storage);
    await svc.savePrinter(name: 'RPP02N', mac: 'AA:BB:CC:DD:EE:FF');
    // Kunci lama tidak dipakai lagi: satu kunci JSON saja.
    expect(storage.map.containsKey(printerNameKey), isFalse);
    expect(storage.map.containsKey(printerMacKey), isFalse);
    expect(await svc.savedPrinter(), ('RPP02N', 'AA:BB:CC:DD:EE:FF'));
    // Data lama (hanya MAC era dialog pilih) termigrasi sekali baca.
    final legacy = FakeSecureStorage()
      ..map[printerMacKey] = '11:22:33:44:55:66';
    final legacySvc = PrinterService(storage: legacy);
    expect(await legacySvc.savedPrinter(), ('11:22:33:44:55:66', '11:22:33:44:55:66'));
    expect(legacy.map.containsKey(printerJsonKey), isTrue);
  });
}
