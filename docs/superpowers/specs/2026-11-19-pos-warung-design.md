# Desain Aplikasi POS Warung Offline-First — 2026-11-19

## Intent & Why
Membangun aplikasi POS Android Flutter untuk dijual ke banyak warung kecil. Harus berjalan penuh secara offline (kasir, produk, stok, laporan) dengan SQLite lokal, plus backup/restore manual ke cloud milik penjual. Tujuan komersial → butuh isolasi data per toko, auth terpusat, dan fondasi lisensi.

## Goals
- Kasir offline: keranjang, qty, tunai/kembalian, simpan transaksi lokal.
- Kelola produk: CRUD, harga beli/jual, stok, kategori, foto.
- Restock: tambah stok + catat riwayat.
- Stock opname: hitung fisik vs sistem, selisih tercatat.
- Laporan pendapatan: harian/mingguan/bulanan, omzet, laba kotor, produk laris.
- Scan barcode produk (pakai kamera) untuk cari/tambah ke keranjang.
- Scan foto produk: ambil foto via kamera/galeri, simpan lokal sebagai foto produk.
- Auth: registrasi + login akun terdaftar; sekali login online, selanjutnya bisa buka offline (PIN).
- Backup/restore manual ke cloud per toko.

## Non-goals (v1)
- Sync realtime multi-HP, conflict merge otomatis.
- Payment gateway, QRIS otomatis, printer Bluetooth (nanti).
- Web dashboard pemilik (nanti).
- Klasifikasi AI otomatis dari foto (foto = dokumentasi dulu).

## Anti-goals
- Koneksi langsung HP → PostgreSQL/MySQL (kredensial bocor, port terbuka).
- Fitur yang mati total saat offline.

## Constraints
- Android only v1, Flutter.
- Offline-first: semua fitur utama tanpa internet setelah login pertama.
- Local DB: SQLite (rekomendasi: Drift).
- Cloud: REST API + PostgreSQL milik penjual, isolasi via `store_id`.
- Start dari nol di `D:\OpenCode\cli` (belum ada proyek Flutter).

## Approaches (dipilih A)
- **A. Backend API + PostgreSQL (dipilih):** App ↔ HTTPS REST ↔ API ↔ Postgres. Backup = push snapshot/delta dengan JWT + `store_id`. Aman dijual, bisa lisensi, bisa multi-HP 1 toko nanti. Biaya: perlu hosting backend.
- **B. File backup ke Google Drive user (ditolak):** export `.sqlite`/`.json` terenkripsi ke Drive user. Tanpa server tapi tanpa kontrol pusat/lisensi, tidak cocok untuk dijual.
- **C. Koneksi langsung DB (ditolak):** alasan keamanan di atas.

## Keputusan desain (disepakati)
1. Arsitektur: Flutter (Riverpod + GoRouter + Drift/SQLite) + backend REST kecil (Node/Express atau Dart Frog) + PostgreSQL. Scope: fullstack sekaligus — dua codebase + deploy, Flutter dengan kontrak API nyata.
2. Data model lokal inti: `stores, users, products(barcode unique/store), stock_moves, transactions, transaction_items, backups_log`.
3. Auth dua lapis:
   - Online: email+password ke backend → JWT access + refresh, `store_id` dibuat saat registrasi toko.
   - Offline: PIN 6-digit + cache hash kredensial; wajib 1x online dulu.
   - v1: 1 user per toko (1 HP = 1 akun pemilik, PIN milik pemilik). Multi-kasir/role ditunda.
   - Lisensi v1: fondasi saja (kolom siap, tanpa enforcement expired).
4. Backup v1: tombol manual "Backup sekarang" (push full snapshot SQLite→JSON + foto opsional), "Restore" (pull). Konflik: last-write-wins per database; sebelum restore, app otomatis backup lokal dulu + minta konfirmasi.
5. Barcode: `mobile_scanner`; foto: `image_picker`, simpan file lokal + path di DB.
6. Kasir v1 minimal: keranjang + qty + tunai/kembalian. Tanpa diskon, void/retur, bon/hutang.
7. Stok & laba: harga beli/jual di-snapshot ke `transaction_items` saat jual; penjualan ditolak jika stok kurang (tidak boleh minus).
8. Laporan v1: tampil di layar saja (harian/mingguan/bulanan, omzet, laba kotor, produk laris by qty). Tanpa export PDF/Excel.
9. Urutan bangun: (1) fondasi + auth, (2) produk, (3) kasir, (4) restock/opname, (5) laporan, (6) backup cloud.

## Diserahkan ke builder
- Pilihan exact ORM (Drift vs sqflite), state mgmt final, backend framework final, skema JWT/refresh detail, format snapshot backup, strategi upload foto.
