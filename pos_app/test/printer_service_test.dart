import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/session/secure_session.dart';
import 'package:pos_app/features/sales/printer_service.dart';

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

void main() {
  test('MAC tersimpan bisa dibaca kembali', () async {
    final svc = PrinterService(storage: FakeSecureStorage());
    expect(await svc.savedMac(), isNull);
    await svc.saveMac('66:02:BD:06:18:7B');
    expect(await svc.savedMac(), '66:02:BD:06:18:7B');
  });

  test('print tanpa adapter lempar PrinterException', () async {
    final svc = PrinterService(storage: FakeSecureStorage());
    expect(() => svc.printBytes([1, 2, 3]), throwsA(isA<PrinterException>()));
  });

  test('izin ditolak lempar pesan pengaturan', () async {
    final svc = PrinterService(
      storage: FakeSecureStorage()..map[printerMacKey] = '00:11:22:33:44:55',
      adapter: _DeniedAdapter(),
    );
    expect(
      () => svc.printBytes([1, 2, 3]),
      throwsA(
        isA<PrinterException>().having((e) => e.message, 'message', contains('Pengaturan')),
      ),
    );
  });
}

class _DeniedAdapter extends PrinterAdapter {
  @override
  Future<bool> get permissionGranted async => false;
}
