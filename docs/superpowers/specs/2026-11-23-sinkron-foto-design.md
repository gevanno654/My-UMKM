# Desain Sinkron Foto Produk — 2026-11-23

## Intent & Why
Foto produk kini hanya hidup di HP (`product_photos/*.jpg`, DB hanya simpan
path relatif). Sinkron hanya menukar `photoPath` string — HP baru hasil pull
mendapat path tanpa file → thumbnail pecah, dokumentasi produk hilang.
Tujuan: file foto ikut ke cloud **di dalam satu tombol "Sinkron Semua"**
yang sudah ada, upload **hanya saat berubah** (hemat kuota), tanpa menu /
istilah baru untuk pengguna.

## Goals
- Satu tombol Sinkron: setelah dokumen selesai (fase lama), fase foto
  berjalan otomatis: upload yang berubah + unduh yang kurang.
- Deteksi-berubah murah: manifest ringan `photo_hash` (SHA-256) + `photo_size`
  per produk; bandingkan lokal vs server, transfer hanya yang beda.
- HP baru / HP ganti: sinkron pertama mengunduh semua foto → dokumentasi pulih.
- Foto = dokumentasi/thumbnail (daftar 48px, detail 120px). Scan kasir tetap
  by barcode (`mobile_scanner`), bukan pengenalan visual.
- Simpan apa adanya dari HP (sudah `maxWidth: 1024 + quality 80` saat pick,
  tipikal 150–400KB). Server tidak kompres ulang.
- Batas pengaman backend: tolak upload > 2MB (413).

## Non-goals
- Pengenalan produk dari foto di kasir (klasifikasi visual/AI) — non-goal v1.
- Kompres ulang / thumbnail ganda di server.
- Object storage eksternal (S3/MinIO) — disk server cukup untuk skala warung.
- Enkripsi file foto di server (TLS + auth Bearer saja, sama seperti dokumen).

## Anti-goals
- Tombol / menu "backup foto" terpisah — membingungkan pengguna.
- Upload ulang semua foto tiap sinkron — boros kuota.
- Foto crash-kan sinkron: satu file gagal → catat, lanjutkan file lain,
  status akhir error parsial (pola sama seperti dokumen).

## Constraints
- Offline-first: tanpa internet semua tetap jalan; fase foto skip diam-diam
  saat offline (bukan error).
- Isolasi `store_id`: file di disk server per store
  (`<DATA_DIR>/<storeId>/<photoHash>.jpg`), download lintas store ditolak.
- Auth Bearer yang sama; multipart `photo` + field `productId`.
- Stok tetap otoritatif lokal — fase foto tidak menyentuh stok/dirty.

## Approaches
- **A. File di server + manifest hash (dipilih).** Endpoint upload/download
  file + kolom `photo_hash`/`photo_size`. Transfer hanya delta. Tanpa infra
  baru, cocok skala warung (puluhan–ratusan foto). Kelemahan: perlu purge
  file saat produk purge fisik (lihat Tugas).
- **B. Foto base64 di Postgres.** Tanpa endpoint file; DB membengkak
  (~700KB teks/foto), pull katalog lambat. Ditolak.
- **C. Object storage eksternal.** Benar untuk skala besar, tapi tambah
  infra + biaya + konfigurasi per warung. Overkill v1. Ditolak.

## Desain (yang disepakati, tinggal dibangun)
- Skema: Drift `Products.photoHash/photoSize` (default `''`/0, migrasi v6→v7);
  Postgres `008_product_photos.sql` (`photo_hash text DEFAULT ''`,
  `photo_size int DEFAULT 0`).
- Hash: SHA-256 file dihitung di HP saat foto disimpan/diubah (`crypto`
  sudah ada di pubspec); disimpan ke kolom lokal; ikut terkirim sebagai
  field produk seperti biasa; server simpan ke kolom baru.
- Endpoint backend (auth sama): `POST /api/v1/products/:id/photo`
  (multipart, ≤2MB, simpan `<DATA_DIR>/<storeId>/<hash>.jpg`, update kolom),
  `GET /api/v1/products/photos/:hash` (cek milik store, `Content-Type:
  image/jpeg`), `GET /api/v1/products/photo-manifest` (`[{id, photoHash}]`).
- Fase foto di `SyncAllNotifier.syncAll()` setelah pull dokumen:
  unduh manifest → upload (hash lokal ≠ server / server kosong) →
  unduh (hash server ≠ lokal / file lokal hilang) → simpan via `PhotoStore`,
  update kolom lokal. Gagal per-file → `firstError`, lanjut.
- Purge: saat produk purge fisik lokal + delete server, hapus file server
  (endpoint `DELETE /api/v1/products/:id/photo` atau gabung delete produk).

## Builder check
- Belum dilakukan (desain kecil, satu subsistem). Jika reviewer meminta,
  jalankan `builder-check-prompt.md` sebelum plan.
