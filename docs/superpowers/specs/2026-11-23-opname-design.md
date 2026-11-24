# Desain Stock Opname v1 (Penyesuaian Stok)

Tanggal: 2026-11-23. Status: menunggu persetujuan.

## Maksud

Menutup loop stok: kasir mengurangi, restock menambah, opname **mengoreksi**
agar angka sistem sama dengan fisik. Tanpa opname, selisih kecil (hilang,
rusak, salah catat, selip) menumpuk diam-diam dan laporan nanti salah.
Dipilih mode **per produk saat sempat** (bukan sesi keliling): di daftar
produk ada tombol "Sesuaikan stok" per baris → dialog → simpan.

## Tujuan / non-tujuan

- Tujuan: koreksi satu produk < 30 detik; 100% offline; selisih tercatat
  beraudit (produk, sebelum, sesudah, selisih ±, alasan bebas, waktu);
  boleh dua arah (tambah = selip/kelebihan catat, kurang = rusak/susut/
  salah catat). Alasan ketik bebas dulu (dropdown menyusul bila pola
  alasan sudah terlihat dari pemakaian).
- Non-tujuan v1: sesi opname keliling sekaligus, stok minimum warning,
  FIFO batch harga, persetujuan ganda, hapus/edit riwayat penyesuaian
  (koreksi = penyesuaian baru, batal = void beraudit).

## Alur layar

```
/home → [Produk] → /products (daftar)
  → tiap baris: [Sesuaikan] → dialog:
      Stok sistem: N (readonly)
      Hasil hitung fisik: [angka ≥ 0]
      Alasan: [teks bebas, wajib]
      [Simpan] → stok diset ke angka fisik
  → riwayat: filter per produk di detail produk
      (produk, sebelum → sesudah, selisih ±, alasan, waktu, status sync)
      + tombol Sinkron manual + [Batalkan] per baris (alasan wajib →
      stok kembali, ditolak bila stok kini kurang)
```

- Angka fisik ≥ 0; sama dengan stok sistem → tolak ("tidak ada perubahan").
- Alasan wajib non-blank (maks 200 karakter).
- Produk arsip/terhapus: tombol Sesuaikan disembunyikan (konsisten dengan
  restock/kasir yang menolak produk arsip).
- Hasil fisik 0 = boleh (barang habis/rusak semua) — bukan hapus produk.

## Data

Drift lokal (sumber utama), tabel baru:
- `adjustments`: id UUID lokal, storeId, productId (nullable agar riwayat
  tahan bila produk kelak dihapus), nama snapshot, stockBefore,
  stockAfter, diff (= after − before, boleh negatif), reason teks,
  status (ok/voided), voidReason, createdAt millis, voidedAt, dirty.
- Simpan = 1 transaksi DB: insert adjustment + `UPDATE products SET stock
  = <angka fisik>` + produk jadi dirty. Bukan `+= diff` relatif — diset
  absolut ke hasil hitung, karena itulah makna opname.
- Void = 1 transaksi DB: status → voided + alasan wajib, stok produk
  dikembalikan (`stock − diff`, karena simpan tadi `= before + diff`).
  Ditolak 409 bila hasil kembali < 0 (stok sudah terlanjur berubah,
  mis. terjual setelah opname) — stok tidak berubah, tampilkan pesan.
  Pola sama dengan void restock/kasir.

Backend Postgres: tabel `adjustments` (mirip restocks: id = UUID client,
store_id FK, product_id nullable, name, stock_before/after/diff, reason,
status, void_reason, created_at/voided_at; tanpa nomor struk). Endpoint
`GET/POST /api/v1/adjustments` + `POST /api/v1/adjustments/:id/void`.
- `POST` idempoten pre-mutasi seperti restock/sales: id sudah ada → 201
  berisi dokumen lama tanpa mutasi ulang (aman retry HP).
- Server terapkan `stock = stock_after` dari client? TIDAK — server
  hitung ulang: kunci produk `FOR UPDATE`, `before = stock kini`,
  `after = before + diff` dari client, tolak 409 bila `after < 0`.
  Diff relatif (bukan absolut) agar dua HP opname bersamaan tidak saling
  timpa — konsisten dengan pelajaran bug stok-dobel kemarin. `before/after`
  di respons dihitung dari nilai server saat itu.
- `POST /:id/void`: validasi reason, status → voided + stok `−= diff`
  dalam transaksi; tolak 409 bila hasil < 0; sudah voided → 200
  idempoten. Pola sama dengan void restock/sales.
- Validasi: productId milik toko sendiri + belum dihapus (404 bila tidak);
  diff ≠ 0 (400); reason non-blank (400); `after` hasil < 0 → 409.

Sinkron manual push-then-pull seperti restock/kasir: produk terkait
di-PUT dulu (tanpa stok — PUT abaikan stok), baru adjustment di-POST
sekali. Pull GET merge: adjustment server yang belum ada → insert lokal
+ terapkan diff ke stok produk lokal? Pilihan: YA terapkan (seperti
restock: stok server = kebenaran setelah sync). Konflik langka di v1
(1 HP per toko); LWW per dokumen id.

## Pendekatan yang dipertimbangkan

1. **Dokumen penyesuaian absolut-lokal + relatif-server + void (dipilih)**:
   HP set absolut ke angka fisik (makna opname), server terapkan sebagai
   diff relatif (anti timpa). Void kembalikan stok (`− diff`), tolak bila
   hasil < 0. Stok berubah hanya via dokumen beraudit.
2. Koreksi via edit stok di form produk: ditolak — mengulang bug
   stok-dobel (angka absolut menimpa tanpa audit).
3. Sesi opname keliling sekaligus: ditolak untuk v1 — draft setengah jalan,
   layar tambahan jarang dipakai; warung kecil cocok per-produk. Bisa jadi
   v2 bila dibutuhkan (riwayat per-dokumen sudah siap menampung `sessionId`).

## Keputusan yang perlu Anda setujui

1. Server terapkan diff relatif (bukan absolut client) — OK?
2. Void beraudit (alasan wajib, stok kembali, tolak bila hasil < 0) — OK?
3. Alasan ketik bebas maks 200 karakter — OK?

## Terbuka untuk builder

- Nama file/tabel persis mengikuti pola restocks (`Restocks` →
  `Adjustments`, `adjustments_provider.dart`, dsb).
- Format tampilan selisih (±N dengan warna hijau/merah).
- Penempatan tombol Sesuaikan (per baris vs di detail produk) — putusan
  builder saat implementasi, uji HP menentukan.
