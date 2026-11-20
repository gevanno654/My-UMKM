# My-UMKM — Aplikasi Kasir & Kelola Produk untuk UMKM

Aplikasi **Android offline-first** untuk usaha kecil/warung: kelola produk
(CRUD + barcode + foto) dengan sinkron manual ke cloud, di atas fondasi
autentikasi akun + PIN offline.

> Status: v1 — autentikasi + kelola produk selesai dan teruji di HP.
> Berikutnya: kasir (transaksi penjualan), laporan, backup cloud.

## Arsitektur

- **HP (Flutter 3.38, Riverpod 3, Drift/SQLite):** sumber utama data.
  Semua fitur utama jalan offline setelah login pertama.
- **Cloud (Express + PostgreSQL 18):** salinan per `store_id` (isolasi via
  JWT, tanpa koneksi langsung HP → database).
- **Sinkron manual:** tombol Sinkron → push baris kotor lalu pull dari
  server (last-write-wins per baris via millis perangkat, delete selalu
  menang). Tanpa auto-sync.

## Yang sudah jadi

### 1. Autentikasi (akun + PIN offline)
- Register/login (email + password), token access + refresh (rotasi).
- PIN 6-digit **per akun** (`pin_hash_<userId>`): logout tidak menghapus
  PIN — login ulang akun sama langsung masuk tanpa buat PIN baru.
- Akun berbeda di HP yang sama wajib buat PIN sendiri (tidak saling memakai).
- Sesi selalu dimulai terkunci → buka via PIN **murni offline**.
- Brute-force guard: 5x salah → kunci 60 detik.
- Tombol Keluar + konfirmasi → sesi dihapus → otomatis kembali ke login.

### 2. Kelola produk (offline-first)
- CRUD lokal (nama, barcode, harga beli/jual, stok, kategori) + validasi
  Indonesia; stok tidak boleh minus.
- Barcode via **kamera** (`mobile_scanner` layar penuh, torch + flip kamera)
  atau ketik manual; duplikat per toko ditolak dengan pesan jelas.
- Foto via **kamera/galeri** (`image_picker`, maxWidth 1024, quality 80),
  tersimpan di HP (`product_photos/`); file hilang → placeholder, tidak crash.
  > v1: foto hanya di HP, belum ikut ke cloud (menyusul di fitur backup).
- Arsip (disembunyikan dari daftar aktif) + hapus (soft delete tersinkron,
  file foto dipertahankan).
- Daftar: search nama/barcode, filter Aktif/Arsip, thumbnail + harga + stok
  + badge arsip; hapus via swipe/menu + konfirmasi 2 langkah.
- Sinkron manual 2 arah; token kedaluwarsa → pesan login ulang.

## Struktur repo

```
backend/                 # Express + TS + zod + pg (port 3000)
  migrations/            # 001_init.sql (auth) + 002_products.sql
  src/auth/ src/products/
pos_app/                 # Flutter (Android only v1)
  lib/features/auth/    # login/register/PIN/logout/home
  lib/features/products/# model/api/provider/screens/form/scan/photo
docs/
  API_AUTH.md API_PRODUCTS.md
  superpowers/specs/    # spesifikasi desain
```

## Menjalankan

```bash
# Backend (butuh PostgreSQL 18, DB pos_dev / user pos)
cd backend && npm install && npm run migrate && npm run dev

# Aplikasi (butuh Flutter 3.38)
cd pos_app && flutter pub get
flutter run --dart-define API_URL=http://<IP-PC>:3000
```

## Pengujian

- Backend: `cd backend && npm test` (vitest, 15 test) + `npm run typecheck`.
- Aplikasi: `cd pos_app && flutter test` (71 test) + `flutter analyze`.
- Uji HP: APK debug diinstal via `adb`, skenario offline/online di Infinix.

## Batasan v1 (disengaja)

- Android saja; 1 user per toko; uang INTEGER rupiah.
- Foto produk belum tersinkron ke cloud.
- Tanpa koneksi langsung HP → PostgreSQL.
