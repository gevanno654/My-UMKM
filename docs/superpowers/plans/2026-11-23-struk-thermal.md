# Struk Thermal 58mm Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cetak struk 58mm via Bluetooth dari layar Struk, opt-in (default tidak cetak).

**Architecture:** Builder byte ESC/POS murni dari `SaleModel` (unit-testable tanpa printer) + service tipis di atas `print_bluetooth_thermal` + MAC tersimpan di secure storage + tombol Cetak di `ReceiptScreen`.

**Tech Stack:** `print_bluetooth_thermal: ^1.2.1`, `esc_pos_utils_plus` (Generator mm58), `flutter_secure_storage` (sudah ada).

**Spec:** `docs/superpowers/specs/2026-11-23-struk-thermal-design.md`

## Global Constraints

- Kertas 58mm saja, 32 kolom — satu baris nama item + satu baris harga agar muat.
- Default TIDAK cetak: tombol "Cetak Struk" opt-in di layar Struk, tidak ada auto-print setelah bayar.
- Gagal cetak = snackbar ramah, kasir tidak diblokir, struk layar tetap ada.
- Full offline: tidak ada panggil API backend.
- `flutter test --concurrency 1` + `flutter analyze` bersih tiap commit.

## Review Focus

- Nama item > 32 char terpotong rapi tanpa meluber ke baris harga.
- Printer mati/tidak terjangkau saat cetak → snackbar ramah, app tidak crash.
- Bluetooth HP mati → pesan "Nyalakan Bluetooth", bukan error generik.
- MAC tersimpan menunjuk printer lain → gagal connect memberi pesan jelas, user bisa pilih ulang.
- Rupiah format konsisten dengan layar (`formatRupiah`), tanpa desimal aneh di kertas.

---

### Task 1: Builder byte struk 58mm

**Files:**
- Create: `pos_app/lib/features/sales/receipt_bytes.dart`
- Test: `pos_app/test/receipt_bytes_test.dart`

**Interfaces:**
- Consumes: `SaleModel` (+ `PayMethod`) dari `sale_model.dart`; `formatRupiah` yang sudah ada; `resolveStore` untuk nama warung (dilewatkan sebagai parameter `storeName`, bukan di-resolve di dalam).
- Produces: `Future<List<int>> buildReceiptBytes({required SaleModel sale, required String storeName})` — dipakai Task 3.

- [ ] **Step 1: Write the failing test**

```dart
test('struk memuat nomor, total, bayar, kembali', () async {
  final bytes = await buildReceiptBytes(sale: sampleSale, storeName: 'Warung Barokah');
  final text = latin1.decode(bytes, allowInvalid: true);
  expect(text, contains('Warung Barokah'));
  expect(text, contains(sampleSale.number));
  expect(text, contains(formatRupiah(sampleSale.total)));
});

test('nama item panjang dipotong, tidak meluber 32 kolom', () async {
  final bytes = await buildReceiptBytes(sale: longNameSale, storeName: 'W');
  final text = latin1.decode(bytes, allowInvalid: true);
  for (final line in text.split('\n')) {
    expect(line.runes.length, lessThanOrEqualTo(32));
  }
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/receipt_bytes_test.dart` (dari `pos_app/`)
Expected: FAIL — `receipt_bytes.dart` belum ada.

- [ ] **Step 3: Implement `buildReceiptBytes({required SaleModel sale, required String storeName})` in `pos_app/lib/features/sales/receipt_bytes.dart`**

Gunakan `esc_pos_utils_plus` Generator `PaperSize.mm58` + `CapabilityProfile.load()`. Layout sesuai spec: header tengah, item 2 baris (nama / `qty x harga ... subtotal`), TOTAL/BAYAR/KEMBALI rata kanan, footer terima kasih, `feed(2)`. Tambah dependensi `esc_pos_utils_plus` + `print_bluetooth_thermal` ke `pubspec.yaml` dulu (versi `^1.2.1` untuk printer).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/receipt_bytes_test.dart`
Expected: PASS. Lalu `flutter analyze` bersih.

- [ ] **Step 5: Commit**

```bash
git add pos_app/pubspec.yaml pos_app/lib/features/sales/receipt_bytes.dart pos_app/test/receipt_bytes_test.dart
git commit -m "feat: builder byte struk thermal 58mm"
```

### Task 2: Service printer + simpan MAC

**Files:**
- Create: `pos_app/lib/features/sales/printer_service.dart`
- Modify: `pos_app/android/app/src/main/AndroidManifest.xml` (izin `BLUETOOTH_CONNECT`, `BLUETOOTH_SCAN`)
- Test: `pos_app/test/printer_service_test.dart`

**Interfaces:**
- Consumes: `SecureStorage` dari `core/session/secure_session.dart` (kunci `printer_mac`, pola injeksi seperti `FlutterSecureStorageAdapter`).
- Produces: `PrinterService` dengan `Future<List<BluetoothInfo>> pairedPrinters()`, `Future<void> saveMac(String mac)`, `Future<String?> savedMac()`, `Future<void> printBytes(List<int> bytes, {String? mac})` — dipakai Task 3. Error dilempar sebagai `PrinterException(message)` agar UI tampilkan snackbar ramah.

- [ ] **Step 1: Write the failing test**

```dart
test('MAC tersimpan bisa dibaca kembali', () async {
  final svc = PrinterService(storage: FakeSecureStorage());
  await svc.saveMac('66:02:BD:06:18:7B');
  expect(await svc.savedMac(), '66:02:BD:06:18:7B');
});

test('print tanpa printer tersambung lempar PrinterException', () async {
  expect(() => svc.printBytes([1, 2, 3]), throwsA(isA<PrinterException>()));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/printer_service_test.dart`
Expected: FAIL — `printer_service.dart` belum ada.

- [ ] **Step 3: Implement `PrinterService` in `pos_app/lib/features/sales/printer_service.dart`**

Bungkus `PrintBluetoothThermal`: cek `bluetoothEnabled` dulu (mati → `PrinterException('Nyalakan Bluetooth dulu')`), `connect(macPrinterAddress:)`, `writeBytes`, `disconnect` di `finally`. Izin runtime Bluetooth diminta via paket (tanpa izin lokasi). Tambah 2 izin ke manifest Android.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/printer_service_test.dart`, lalu `flutter analyze`.
Expected: PASS, bersih. (Fake untuk `PrintBluetoothThermal` via wrapper yang bisa dioverride, atau test hanya untuk save/load MAC + mapping error.)

- [ ] **Step 5: Commit**

```bash
git add pos_app/lib/features/sales/printer_service.dart pos_app/test/printer_service_test.dart pos_app/android/app/src/main/AndroidManifest.xml
git commit -m "feat: service printer bluetooth + simpan MAC"
```

### Task 3: Tombol Cetak di layar Struk (opt-in)

**Files:**
- Modify: `pos_app/lib/features/sales/sales_screens.dart` (`ReceiptScreen`, baris ~405-431)
- Test: `pos_app/test/receipt_print_test.dart` (widget test)

**Interfaces:**
- Consumes: `buildReceiptBytes` (Task 1), `PrinterService` (Task 2), `resolveStore` untuk nama warung.
- Produces: tombol "Cetak Struk" di layar Struk; dialog pilih printer (tersimpan + daftar paired + simpan pilihan).

- [ ] **Step 1: Write the failing widget test**

```dart
testWidgets('tombol Cetak muncul saat ada transaksi', (t) async {
  await t.pumpWidget(harnessWithSale(sampleSale));
  expect(find.text('Cetak Struk'), findsOneWidget);
});

testWidgets('gagal cetak tampilkan snackbar, tidak crash', (t) async {
  await t.pumpWidget(harnessWithFailingPrinter());
  await t.tap(find.text('Cetak Struk'));
  await t.pumpAndSettle();
  expect(find.byType(SnackBar), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/receipt_print_test.dart`
Expected: FAIL — tombol belum ada.

- [ ] **Step 3: Implement tombol + dialog di `ReceiptScreen`**

Tambah tombol outline "Cetak Struk" di atas "Transaksi Baru" (default tidak auto-print — tidak ada pemanggilan cetak di alur bayar). Ketuk → bangun byte via `buildReceiptBytes` → dialog: printer tersimpan (jika ada) + daftar `pairedPrinters` + simpan pilihan → `printBytes` → snackbar sukses/gagal. Gagal = snackbar saja, tetap di layar Struk.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --concurrency 1` (full suite), lalu `flutter analyze`.
Expected: semua hijau, bersih.

- [ ] **Step 5: Commit**

```bash
git add pos_app/lib/features/sales/sales_screens.dart pos_app/test/receipt_print_test.dart
git commit -m "feat: tombol cetak struk opt-in di layar Struk"
```
