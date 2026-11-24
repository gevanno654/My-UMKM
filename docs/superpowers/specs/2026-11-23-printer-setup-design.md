# Desain Siapkan Printer Sekali — 2026-11-23

Status: diusulkan — minta persetujuan.

## Maksud

Pengguna pilih printer cukup sekali di layar khusus; layar Struk/Kasir
tinggal tombol Cetak tanpa dialog pilih. Menyelesaikan: (1) izin
"Perangkat di sekitar" tak memunculkan popup sistem saat ditolak,
(2) daftar berisi semua perangkat Bluetooth sehingga membingungkan
(di HP pelapor printer tampil sebagai "RPP02N").

## Tujuan / non-tujuan

- Tujuan: alur siapkan sekali (minta izin resmi → daftar tersaring →
  simpan nama+MAC), cetak harian 1 ketukan, ganti printer tersedia.
- Non-tujuan: auto-print setelah bayar (tetap opt-in), multi-printer,
  edit nama manual, pindai ulang otomatis di latar.

## Alur layar

```
Pengaturan → [Printer Struk]           (menu baru)
  status: "Belum disiapkan" / "RPP02N ✓"
  [Siapkan / Ganti Printer]
   │ 1. cek permissionGranted → belum: minta izin RESMI via sistem
   │    (paket permission_handler, izin bluetoothConnect) → popup Android
   │    ditolak: pesan "Aktifkan Perangkat di sekitar di Pengaturan" + tombol
   │    "Buka Pengaturan" (openAppSettings)
   │ 2. daftar paired, SARING nama khas printer:
   │    printer|thermal|xprinter|iware|rpp|pos|58mm|80mm|btprinter
   │    tak cocok → grup "Perangkat lain" (ciut, tetap bisa dipilih)
   │ 3. ketuk → simpan nama+MAC (secure storage) → kembali, status terupdate
Struk: [Cetak Struk] → langsung cetak ke MAC tersimpan (tanpa dialog).
  belum disiapkan → snackbar "Siapkan printer dulu" + tombol ke layar siapkan.
```

## Teknis

- Paket baru: `permission_handler` (request `bluetoothConnect` runtime;
  menggantikan cek pasif `isPermissionBluetoothGranted`).
- Storage: tambah kunci `printer_name` di samping `printer_mac`
  (`PrinterService.savePrinter(name, mac)`, `savedName()`).
- Saring: fungsi murni `isLikelyPrinter(name)` + `partitionPrinters(list)`
  di `receipt_bytes.dart` (unit-testable), daftar kata: di atas.
- `PrinterService.printBytes`: sebelum connect, jika izin belum granted
  → lempar `PrinterNeedsSetupException` (UI arahkan ke layar siapkan)
  vs `PrinterException` (snackbar biasa).
- Menu Pengaturan: route baru `/settings/printer`, entri di layar
  Pengaturan yang ada.

## Test & verifikasi

- Unit: saring ("RPP02N" lolos, "TWS Pro" ke grup lain), pasang 32 kolom tetap.
- Widget: Cetak tanpa printer tersiapkan → snackbar + tombol ke siapkan;
  layar siapkan tampil nama+status tersimpan.
- Manual HP + RPP02N: tolak izin → pesan + Buka Pengaturan; terima → daftar
  tersaring tampil RPP02N di atas; cetak; ganti printer.
- Regression: `flutter test --concurrency 1`, `flutter analyze` hijau.
