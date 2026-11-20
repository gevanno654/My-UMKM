# Desain Fitur Produk Lengkap (CRUD + Barcode + Foto) — 2026-11-20

## Intent & Why
Satu paket "kelola produk lengkap" sebagai fondasi kasir, restock/opname, dan laporan.
Pemilik warung bisa daftar produk (nama, harga beli/jual, stok awal, kategori),
lengkap dengan barcode (ketik manual/scan kamera) dan foto (kamera/galeri, simpan di HP).
Semua jalan offline penuh; backend hanya salinan per toko + sinkron saat online.

## Goals
- CRUD produk offline-first di SQLite HP (Drift): nama, barcode (opsional, unik per toko),
  hargaBeli, hargaJual, stok, kategori (teks bebas v1), foto (path file lokal).
- Daftar + cari produk (nama/barcode), detail, tambah/ubah/arsip-hapus.
- Scan barcode pakai kamera (`mobile_scanner`): dari layar daftar (cari) dan form (isi).
- Foto via `image_picker` (kamera/galeri), file di direktori app, path di DB.
- Sinkron manual + otomatis-saat-online ke backend (JWT + `store_id`), last-write-wins
  per baris via `updatedAt`; hapus = soft delete (`deletedAt`) agar tersinkron.
- Stok tidak boleh minus (aturan berlaku juga di kasir nanti).

## Non-goals
- Varian produk, multi-satuan, diskon per produk, import Excel/CSV.
- Kategori sebagai tabel relasi (v1: teks bebas; normalisasi nanti bila perlu).
- Sync realtime multi-HP / conflict merge otomatis (last-write-wins saja, seperti backup di spec).
- Upload foto ke cloud (v1: foto lokal saja; ikut backup nanti di plan backup).

## Anti-goals
- Daftar produk mati saat offline (melanggar offline-first).
- Koneksi langsung HP → PostgreSQL.

## Constraints
- Android only v1, Flutter 3.38 / Dart 3.10, Riverpod 3 `Notifier`, GoRouter, Drift 2.31.
- `sqlite3_flutter_libs: 0.5.42` (jangan naik ke eol sebelum upgrade sqlite3 v3+hooks).
- Izin kamera di manifest (scan + foto). Foto butuh izin baca media sesuai API level.
- Backend: Express + Postgres 18, isolasi `store_id` dari JWT (jangan percaya `store_id` body).

## Approaches
- **A. Produk lokal + sinkron (dipilih):** SQLite HP sumber utama; sinkron saat online,
  last-write-wins per baris. Offline penuh, tanpa loading macet. Biaya: `updatedAt`+`deletedAt`.
- **B. Selalu lewat API (ditolak):** daftar mati saat offline — melanggar spec.
- **C. Bertahap (ditolak):** Anda minta lengkap sekaligus.

## Keputusan desain (disepakati + usulan saya)
1. Arsitektur data: tabel Drift `products` (lokal) ↔ tabel Postgres `products` (per `store_id`).
   Skema lokal: `id TEXT PK (UUID v4 lokal), serverId TEXT NULL, storeId TEXT, name TEXT,
   barcode TEXT NULL, costPrice INTEGER, sellPrice INTEGER, stock INTEGER DEFAULT 0,
   category TEXT DEFAULT '', photoPath TEXT DEFAULT '', isArchived INTEGER DEFAULT 0,
   createdAt INTEGER, updatedAt INTEGER, deletedAt INTEGER NULL, dirty INTEGER DEFAULT 1`.
   Unik: `(storeId, barcode)` bila barcode non-null (barcode '' dinormalisasi ke NULL).
   Uang = INTEGER rupiah (tanpa desimal).
2. Backend: `GET /api/v1/products` (list aktif milik store), `POST` (buat),
   `PUT /:id` (ubah, 404 bila beda store), `DELETE /:id` (soft delete `deleted_at`).
   Validasi zod: name ≥1, costPrice/sellPrice ≥0, stock ≥0, barcode opsional.
   Auth: middleware Bearer access JWT → `storeId`.
3. ID authority: **UUID lokal sebagai PK server juga** (tanpa kolom `serverId` terpisah).
   HP generate UUID v4 saat buat; server simpan apa adanya. `PUT/DELETE /:id` = UUID itu.
   Alasan: tanpa backfill mapping, cocok untuk offline-create; tabrakan UUID praktis mustahil.
3. Sinkron: push baris `dirty=1` saat online (manual tombol + otomatis saat app online),
   pull daftar server → upsert lokal (menang bila `updatedAt` lebih baru); hapus lokal
   bila server `deletedAt` lebih baru. Urutan: push dulu lalu pull (sederhana, v1).
4. Hapus vs arsip (keputusan Anda 2026-11-20): **keduanya ada.**
   - Arsip: `isArchived=1`, disembunyikan dari daftar default (filter "Arsip" untuk lihat +
     tombol "Kembalikan"). Aturan kasir: produk arsip **tidak bisa dijual**
     (disembunyikan dari pencarian kasir + ditolak bila barcode-nya di-scan).
   - Hapus permanen: dua langkah (konfirmasi) → soft delete `deletedAt` + tersinkron;
     file foto dipertahankan sampai purge (lihat #5). Baris `deletedAt` disembunyikan
     dari semua daftar; pembersihan fisik di plan backup.
5. Foto: `image_picker` **kamera atau galeri** (pilih via dialog) → salin ke
   `<app-docs>/product_photos/<uuid>.jpg` (kompres maxWidth 1024, quality 80) →
   `photoPath` **relatif** (resolve via `getApplicationDocumentsDirectory()`).
   File foto dihapus fisik hanya saat purge (bersamaan baris `deletedAt`), BUKAN saat
   soft delete — agar sinkron antar-HP di masa depan tidak rusak.
6. Barcode: **wajib via kamera** (`mobile_scanner` layar penuh `ScanScreen`, bukan popup —
   alasan lifecycle kamera), dipakai dari daftar (cari) dan form (isi field).
7. UI/routes baru: `/products` (daftar+cari+filter arsip+tombol sinkron manual),
   `/products/new`, `/products/:id` (detail+edit+arsip/hapus), scan route penuh
   `/products/scan?target=`. Home placeholder diganti tombol masuk Produk
   (kasir asli plan berikutnya).
8. State: `ProductsNotifier : Notifier<ProductsState>` (list, query, loading, error,
   syncStatus) + `ProductFormState` lokal di screen. Error selalu tampil (pelajaran kasus
   daftar: tanpa `catch` umum tidak boleh macet loading).
9. Sinkron (keputusan Anda 2026-11-20): **manual via tombol "Sinkron" saja, tanpa auto-sync.**
   Alur: push baris `dirty=1` lalu pull daftar server → upsert lokal menang bila
   `updatedAt` lebih baru; hapus lokal bila server `deletedAt` lebih baru.
   LWW memakai millis perangkat (jam HP dipercaya v1; otoritas server ditunda ke plan sinkron).
   Race edit-lokal vs delete-server: **delete menang selalu** (aman, data terhapus eksplisit).
   Scope: full pull tanpa pagination (`?since=` ditunda ke plan sinkron akhir bila SKU besar).

## Diserahkan ke builder (rencana implementasi)
- Migrasi Drift v1→v2 + codegen `--force-jit`; migrasi Postgres `002_products.sql`.
- Endpoint + test vitest (isolasi store, validasi, soft delete).
- `ProductsApi` (Dio + JWT access), repo sinkron, izin kamera, `ScanScreen`, form+foto.
- Test: `flutter test` (CRUD lokal, unik barcode, cari, sinkron last-write-wins mock,
  soft delete tersembunyi) + `flutter analyze`; uji manual di HP: offline CRUD, scan,
  foto, online sinkron 2 arah.
