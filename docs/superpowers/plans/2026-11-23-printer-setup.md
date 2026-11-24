# Penyiapan Printer Sekali Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pilih printer cukup sekali di layar khusus; layar Struk tinggal tombol Cetak.

**Architecture:** Layar siapkan (`/settings/printer`, entri dari home) minta izin resmi via `permission_handler`, tampilkan daftar paired tersaring (`isLikelyPrinter`), simpan nama+MAC; `ReceiptScreen` cetak langsung tanpa dialog.

**Tech Stack:** `permission_handler` (baru), `print_bluetooth_thermal` (tetap untuk connect/cetak), `flutter_secure_storage` (kunci `printer_name` baru).

**Spec:** `docs/superpowers/specs/2026-11-23-printer-setup-design.md`

## Global Constraints

- Kata saring: printer|thermal|xprinter|iware|rpp|pos|58mm|80mm|btprinter (case-insensitive); "RPP02N" harus lolos.
- Default TIDAK auto-print tetap berlaku; Cetak tanpa printer tersiapkan → snackbar + jalan pintas ke layar siapkan.
- Izin ditolak → tombol "Buka Pengaturan" (openAppSettings), bukan dialog pilih.
- `flutter test --concurrency 1` + `flutter analyze` bersih tiap commit.

## Review Focus

- Daftar kosong setelah saring padahal ada printer bernama aneh → grup "Perangkat lain" tetap tampil semua, tidak ada yang hilang.
- Izin "tanya setiap saat" yang dibatalkan 2x (permanen) → langsung arahkan Buka Pengaturan, bukan request loop.
- Nama tersimpan vs MAC tidak sinkron (MAC diganti, nama lama) → simpan selalu berpasangan atomik.
- Printer dimatikan setelah disiapkan → Cetak beri pesan "tidak terjangkau", status layar siapkan tidak bohong (cek ulang saat dibuka).
- Ganti printer saat antre cetak → busy-lock lama tetap berlaku, tidak interleave.

---

### Task 1: Saring nama printer + simpan nama

**Files:**
- Modify: `pos_app/lib/features/sales/receipt_bytes.dart` (tambah `isLikelyPrinter`, `partitionPrinters`)
- Modify: `pos_app/lib/features/sales/printer_service.dart` (kunci `printer_name`, `savePrinter(name, mac)`, `savedName()`; `saveMac` tetap untuk kompat)
- Test: `pos_app/test/printer_setup_test.dart`

**Interfaces:**
- Consumes: `SecureStorage` (ada), `BluetoothInfo` (paket printer).
- Produces: `bool isLikelyPrinter(String name)`, `({List<BluetoothInfo> printers, List<BluetoothInfo> others}) partitionPrinters(List<BluetoothInfo> devices)`, `Future<void> savePrinter({required String name, required String mac})`, `Future<(String? name, String? mac)?> savedPrinter()` — dipakai Task 2 & 3.

- [ ] **Step 1: Write the failing test**

```dart
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
  await svc.savePrinter(name: 'RPP02N', mac: 'AA:BB:CC:DD:EE:FF');
  expect(await svc.savedPrinter(), ('RPP02N', 'AA:BB:CC:DD:EE:FF'));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/printer_setup_test.dart` (dari `pos_app/`)
Expected: FAIL — fungsi belum ada.

- [ ] **Step 3: Implement `isLikelyPrinter` + `partitionPrinters` in `receipt_bytes.dart`, `savePrinter`/`savedPrinter` + `printerNameKey` in `printer_service.dart`**

Saring via RegExp case-insensitive dari kata kunci spec. `savedPrinter` baca dua kunci, null bila salah satu kosong.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/printer_setup_test.dart`
Expected: PASS. Lalu `flutter analyze` bersih.

- [ ] **Step 5: Commit**

```bash
git add pos_app/lib/features/sales/receipt_bytes.dart pos_app/lib/features/sales/printer_service.dart pos_app/test/printer_setup_test.dart
git commit -m "feat: saring nama printer + simpan nama dan MAC"
```

### Task 2: Layar siapkan printer + izin resmi

**Files:**
- Create: `pos_app/lib/features/sales/printer_setup_screen.dart`
- Modify: `pos_app/lib/core/router.dart` (route `/settings/printer`, tambah ke `appRoutePaths`)
- Modify: `pos_app/lib/features/auth/home_placeholder.dart` (tombol "Printer Struk" + status nama tersimpan)
- Test: `pos_app/test/printer_setup_ui_test.dart`

**Interfaces:**
- Consumes: `isLikelyPrinter`, `partitionPrinters` (Task 1); `PrinterService.savedPrinter/savePrinter/pairedPrinters` (+ `requestPermission()` baru di service via `permission_handler` — tambah di task ini).
- Produces: route `/settings/printer`; tombol home key `printerSetupButton` + label status key `printerSetupStatus`.

- [ ] **Step 1: Write the failing widget test**

```dart
testWidgets('layar siapkan tampil status + daftar tersaring', (t) async {
  await t.pumpWidget(harness(printer: 'RPP02N'));
  expect(find.textContaining('RPP02N'), findsWidgets);
});

testWidgets('tanpa printer tersimpan tampil tombol Siapkan', (t) async {
  await t.pumpWidget(harness(printer: null));
  expect(find.text('Siapkan Printer'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/printer_setup_ui_test.dart`
Expected: FAIL — layar belum ada.

- [ ] **Step 3: Implement `PrinterSetupScreen` + `requestPermission()` in `PrinterService` + route + tombol home**

Tambah `permission_handler` ke pubspec. `requestPermission()`: `Permission.bluetoothConnect.request()` → granted/denied/permanentlyDenied. Layar: status card, tombol Siapkan/Ganti (izin → daftar tersaring + grup lain ciut → ketuk simpan → pop), ditolak permanen → tombol "Buka Pengaturan" (`openAppSettings`). Tambah izin `BLUETOOTH_SCAN` kembali dengan flag `neverForLocation`? TIDAK — app hanya baca bonded, SCAN tak dibutuhkan; biarkan dihapus (fix pass lalu). Home: tombol outline "Printer Struk" + status di bawahnya.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/printer_setup_ui_test.dart`, lalu full `flutter test --concurrency 1` + `flutter analyze`.
Expected: hijau, bersih.

- [ ] **Step 5: Commit**

```bash
git add pos_app/lib/features/sales/printer_setup_screen.dart pos_app/lib/features/sales/printer_service.dart pos_app/lib/core/router.dart pos_app/lib/features/auth/home_placeholder.dart pos_app/test/printer_setup_ui_test.dart pos_app/pubspec.yaml pos_app/pubspec.lock
git commit -m "feat: layar siapkan printer sekali + izin resmi"
```

### Task 3: Struk cetak langsung tanpa dialog

**Files:**
- Modify: `pos_app/lib/features/sales/sales_screens.dart` (`_ReceiptScreenState._print`, hapus `_PrinterDialog` bila tak terpakai)
- Test: ubah/tambah di `pos_app/test/receipt_print_test.dart`

**Interfaces:**
- Consumes: `savedPrinter()` (Task 1); route `/settings/printer` (Task 2).

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('tanpa printer tersiapkan → snackbar + tombol ke siapkan', (t) async {
  await t.pumpWidget(harnessNoPrinter());
  await t.tap(find.text('Cetak Struk'));
  await t.pumpAndSettle2s();
  expect(find.byType(SnackBar), findsOneWidget);
  expect(find.text('Siapkan Printer'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/receipt_print_test.dart`
Expected: FAIL — alur lama buka dialog, bukan snackbar+jalan pintas.

- [ ] **Step 3: Implement cetak langsung di `_print`**

`savedPrinter()` → null → snackbar "Belum ada printer. Siapkan dulu." + action ke `/settings/printer`; ada → `printBytes` langsung. Hapus `_PrinterDialog` + `_PrinterDevice`. `PrinterNeedsSetupException` dari service (izin tak granted saat cetak) → arahkan ke layar siapkan juga.

- [ ] **Step 4: Run test to verify it passes**

Run: full `flutter test --concurrency 1`, lalu `flutter analyze`.
Expected: semua hijau, bersih.

- [ ] **Step 5: Commit**

```bash
git add pos_app/lib/features/sales/sales_screens.dart pos_app/test/receipt_print_test.dart
git commit -m "feat: cetak langsung tanpa dialog pilih printer"
```
