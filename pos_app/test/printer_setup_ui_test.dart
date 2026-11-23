import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/session/secure_session.dart';
import 'package:pos_app/features/sales/printer_service.dart';
import 'package:pos_app/features/sales/printer_setup_screen.dart';

class FakeSetupStorage implements SecureStorage {
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

Future<void> pumpSetup(
  WidgetTester tester, {
  String? name,
  String? mac,
  PrinterService? service,
}) async {
  final storage = FakeSetupStorage();
  if (name != null && mac != null) {
    storage.map[printerNameKey] = name;
    storage.map[printerMacKey] = mac;
  }
  final svc = service ?? PrinterService(storage: storage);
  await tester.pumpWidget(MaterialApp(home: PrinterSetupScreen(service: svc)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('layar siapkan printer', () {
    testWidgets('tampil status + daftar tersaring', (tester) async {
      await pumpSetup(tester, name: 'RPP02N', mac: 'AA:BB:CC:DD:EE:FF');
      expect(find.textContaining('RPP02N'), findsWidgets);
    });

    testWidgets('tanpa printer tersimpan tampil tombol Siapkan', (tester) async {
      await pumpSetup(tester);
      expect(find.text('Siapkan Printer'), findsOneWidget);
    });
  });
}
