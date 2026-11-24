import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/db/app_db.dart';
import 'package:pos_app/core/session/secure_session.dart';
import 'package:pos_app/features/auth/auth_provider.dart';
import 'package:pos_app/features/auth/auth_state.dart';
import 'package:pos_app/features/sales/printer_service.dart';
import 'package:pos_app/features/sales/sales_provider.dart';
import 'package:pos_app/features/sales/sales_screens.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

/// Auth state palsu: langsung terautentikasi.
class _FakeAuthNotifier extends AuthNotifier {
  static AuthProfile? profile;

  @override
  AuthState build() {
    final p = profile;
    if (p == null) return const AuthUnauthenticated();
    return AuthAuthenticated(p);
  }
}

final _kProfile = AuthProfile(
  id: 'user-1',
  storeId: 'store-1',
  name: 'Budi',
  email: 'budi@warung.id',
  storeName: 'Toko Evan',
);

Future<ProviderContainer> makeReceipt(WidgetTester tester) async {
  late AppDb db;
  await tester.runAsync(() async {
    db = AppDb.openMemory();
    await db.upsertProduct(
      ProductsCompanion.insert(
        id: 'p1',
        storeId: 'store-1',
        name: 'Indomie',
        barcode: const Value.absent(),
        costPrice: 2500,
        sellPrice: 3500,
        stock: const Value(5),
        createdAt: 1,
        updatedAt: 1,
      ),
    );
    await db.checkoutSale(
      sale: SalesCompanion.insert(
        id: 'sale-1',
        storeId: 'store-1',
        number: 'TE231120260001',
        total: 7000,
        paid: 10000,
        change: const Value(3000),
        method: 'tunai',
        createdAt: 1763900000000,
      ),
      items: [
        SaleItemsCompanion.insert(
          id: 'item-1',
          saleId: 'sale-1',
          productId: const Value('p1'),
          name: 'Indomie',
          price: 3500,
          qty: 2,
          subtotal: 7000,
        ),
      ],
    );
  });
  addTearDown(db.close);
  _FakeAuthNotifier.profile = _kProfile;
  addTearDown(() => _FakeAuthNotifier.profile = null);
  final container = ProviderContainer(
    overrides: [
      appDbProvider.overrideWithValue(db),
      authProvider.overrideWith(_FakeAuthNotifier.new),
    ],
  );
  addTearDown(container.dispose);
  await tester.runAsync(() async {
    await container.read(salesProvider.notifier).load('store-1', storeName: 'Toko Evan');
  });
  return container;
}

class _FakeFailingStorage implements SecureStorage {
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

/// Adapter yang selalu gagal connect → alur error terkendali tanpa Bluetooth.
class _FakeFailingAdapter extends PrinterAdapter {
  @override
  Future<bool> get permissionGranted async => true;

  @override
  Future<bool> get bluetoothEnabled async => true;

  @override
  Future<bool> connect(String mac) async => false;
}

/// Adapter paired berisi RPP02N; connect ok agar alur pilih→simpan→cetak jalan.
class _FakePairedAdapter extends _FakeFailingAdapter {
  @override
  Future<List<BluetoothInfo>> paired() async => [
    BluetoothInfo(name: 'RPP02N', macAdress: 'DC:0D:51:4B:D5:BC'),
  ];

  @override
  Future<bool> connect(String mac) async => true;

  @override
  Future<bool> writeBytes(List<int> bytes) async => true;
}

Future<void> pumpReceipt(
  WidgetTester tester,
  ProviderContainer container, {
  PrinterService? printerService,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: ReceiptScreen(printerService: printerService)),
    ),
  );
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await tester.pump();
}

void main() {
  group('tombol cetak struk', () {
    testWidgets('tombol Cetak muncul saat ada transaksi', (tester) async {
      final container = await makeReceipt(tester);
      await pumpReceipt(tester, container);
      expect(find.text('TE231120260001'), findsOneWidget);
      expect(find.text('Cetak Struk'), findsOneWidget);
      expect(find.text('Transaksi Baru'), findsOneWidget);
      expect(find.byKey(const Key('receiptBackButton')), findsOneWidget);
    });

    testWidgets('ketuk Cetak tanpa printer tersimpan buka dialog pilih', (
      tester,
    ) async {
      final container = await makeReceipt(tester);
      final svc = PrinterService(
        storage: _FakeFailingStorage(),
        adapter: _FakePairedAdapter(),
      );
      await pumpReceipt(tester, container, printerService: svc);
      await tester.tap(find.text('Cetak Struk'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      // Dialog pilih muncul dengan daftar paired; tanpa itu = regresi.
      expect(find.text('Pilih Printer'), findsOneWidget);
      expect(find.text('RPP02N'), findsOneWidget);
    });

    testWidgets('pilih printer di dialog simpan MAC lalu cetak', (tester) async {
      final container = await makeReceipt(tester);
      final storage = _FakeFailingStorage();
      final svc = PrinterService(
        storage: storage,
        adapter: _FakePairedAdapter(),
      );
      await pumpReceipt(tester, container, printerService: svc);
      await tester.tap(find.text('Cetak Struk'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('RPP02N'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await tester.pump();
      // MAC tersimpan untuk cetak berikutnya; hasil cetak tergantung adapter.
      expect(await svc.savedMac(), 'DC:0D:51:4B:D5:BC');
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('gagal connect tampilkan snackbar, tidak crash', (tester) async {
      final container = await makeReceipt(tester);
      final storage = _FakeFailingStorage();
      final svc = PrinterService(storage: storage, adapter: _FakeFailingAdapter());
      await svc.saveMac('00:11:22:33:44:55');
      await pumpReceipt(tester, container, printerService: svc);
      await tester.tap(find.text('Cetak Struk'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
