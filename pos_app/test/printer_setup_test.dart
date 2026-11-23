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
}
