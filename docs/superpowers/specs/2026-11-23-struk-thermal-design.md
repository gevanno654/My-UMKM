# Desain Struk Thermal 58mm (Iware C58XS)

Tanggal: 2026-11-23. Status: diusulkan — minta persetujuan.

## Maksud

Cetak struk belanja ke printer thermal Bluetooth 58mm langsung dari layar
Struk, full offline. Target uji: Iware C58XS (ESC/POS, 384 dots/line,
kertas 57,5mm, Bluetooth + USB). Kertas 58mm saja (32 kolom) untuk saat ini.

## Tujuan / non-tujuan

- Tujuan: dari layar Struk, 2 ketukan (Cetak → printer tersimpan) keluar
  kertas; isi = nama warung, nomor struk, tanggal, item×qty + subtotal,
  total, bayar, kembali, metode, "Terima kasih".
- Non-tujuan: kertas 80mm, logo/gambar, QR/barcode, cetak ulang dari
  riwayat (hanya transaksi terakhir di layar Struk), multi-printer,
  cash drawer.

## Format struk (32 kolom, teks ESC/POS)

```
        NAMA WARUNG
   No: TE231120260001
   23 Nov 2026 14:05
--------------------------------
Indomie Goreng x2
  2 x 3500              7000
Teh Botol x1
  1 x 5000              5000
--------------------------------
TOTAL                  12000
TUNAI                  15000
KEMBALI                 3000
--------------------------------
      Terima kasih
   sampai jumpa kembali
```

- Header rata tengah, item rata kiri, angka rata kanan.
- Nama item > 32 char dipotong dengan elipsis (satu baris per item +
  satu baris harga agar muat 58mm).
- Rupiah tanpa desimal (`formatRupiah` yang sudah ada).
- Nama warung dari profil toko (`resolveStore`), bukan dari `SaleModel`
  (model hanya bawa `storeId`).

## Alur layar

```
Struk (ReceiptScreen)
  [Cetak] [Transaksi Baru]
   │ Cetak
   ▼
Dialog printer: daftar tersimpan / [Cari printer]
   │ pilih → simpan MAC (SharedPreferences) → cetak
   ▼
Sukses: snackbar "Struk tercetak".
Gagal: snackbar alasan ("Printer tidak terjangkau", "Bluetooth mati"),
       struk layar tetap ada — kasir TIDAK diblokir.
```

- Tombol Cetak hanya aktif jika ada transaksi di layar.
- Pemindaian Bluetooth hanya saat user buka dialog (hemat baterai).

## Teknis

- Paket: `print_bluetooth_thermal` (Android, tanpa izin lokasi) +
  `esc_pos_utils_plus` untuk bangun byte ESC/POS (Generator 58mm).
- Byte struk dibangun dari `SaleModel` murni (fungsi `buildReceiptBytes`)
  agar bisa unit-test tanpa printer.
- Izin Android di manifest: `BLUETOOTH_CONNECT` + `BLUETOOTH_SCAN`
  (Android 12+); tanpa printer tersambung semua fitur lama tetap jalan.
- MAC printer tersimpan per-HP (bukan per-toko, bukan ikut sinkron).

## Test & verifikasi

- Unit: builder byte — 32 kolom tidak meluber, total/bayar/kembali benar,
  nama panjang terpotong, rupiah format benar.
- Widget: tombol Cetak muncul saat ada transaksi; gagal cetak tampil
  snackbar, tidak crash.
- Manual di HP + Iware C58XS: pairing → cetak 1 item, banyak item,
  nama panjang, printer mati (pesan ramah).
- Regression: `flutter test`, `flutter analyze` hijau tiap commit.
