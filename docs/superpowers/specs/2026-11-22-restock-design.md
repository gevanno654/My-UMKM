# Desain Restock v1 (Penerimaan Kulakan)

Tanggal: 2026-11-22. Status: disetujui — lanjut ke rencana kerja.

Amendemen 2026-11-22 (hasil uji HP): opsi "ikut ubah harga jual" dihapus
sementara dari draft restock — field harga beli/jual sempat tidak ter-commit
bila user tidak menekan enter (`onSubmitted`). v1: restock murni tambah stok
+ update harga beli katalog (harga beli commit live via `onChanged`); harga
jual diubah via Kelola Produk. Batch harga beli per penerimaan (FIFO)
direncanakan sebagai milestone v2, bukan v1.

## Maksud

Mencatat kulakan sebagai **dokumen penerimaan multi-produk**: satu aksi
restock = banyak produk + qty tambah + harga beli saat itu. Stok hanya bisa
bertambah lewat fitur ini — form Kelola Produk tidak lagi bisa sunting stok.

## Tujuan / non-tujuan

- Tujuan: catat satu nota kulakan < 60 detik; 100% offline; stok tidak
  pernah minus; harga beli katalog ikut terkini. Harga jual katalog TIDAK
  diubah lewat restock v1 (ubah via Kelola Produk).
- Non-tujuan v1: supplier/grosir master, no. nota, hutang, retur ke
  supplier, koreksi stok manual, stok opname, peringatan stok minimum,
  batch harga beli per penerimaan (FIFO — milestone v2).

## Alur layar

```
/home → [Restock] → /restocks (riwayat penerimaan)
  → [+ Kulakan] → /restocks/new:
     cari nama / scan barcode → tambah ke daftar
     tiap baris: qty tambah, harga beli baru (live, tanpa tekan enter)
     ringkasan: total item + total modal → Simpan
  → riwayat: tanggal, jumlah item, total modal, status (ok/void)
     → detail → [Batalkan] + alasan wajib → stok kembali
```

- Produk arsip/terhapus: tidak bisa dipilih di restock baru; bila produk
  masuk draft lalu diarsip/dihapus sebelum simpan → simpan diblokir.
- Qty wajib ≥ 1; harga beli ikut batas lama (0..999999999).
- Harga jual katalog **tidak berubah** lewat restock v1 (ubah via Kelola
  Produk).
- Produk yang sama ditambahkan 2x dalam satu draft → gabung 1 baris
  (qty dijumlah, harga beli terakhir menang).
- Salah input → Batalkan (alasan wajib). Stok dikurangi kembali atomik;
  **ditolak** bila stok kini kurang dari qty restock itu (sudah terlanjur
  terjual) — stok tidak berubah, tampilkan pesan.
- Form produk: field Stok **dihapus total** (tambah maupun ubah).
  Produk baru selalu dibuat dengan stok 0, lalu ditambah lewat Restock.
  Mode ubah menampilkan stok sebagai teks readonly ("Stok: N — ubah via Restock").
- Draft restock hanya di memori (tidak persist seperti keranjang kasir);
  restart HP sebelum simpan → draft hilang.

## Data

Drift lokal (sumber utama), tabel baru:
- `restocks`: id UUID lokal, storeId, totalModal (Σ qty×harga beli),
  status (ok/voided), alasan void, createdAt millis, voidedAt, dirty.
- `restock_items`: id, restockId, productId (nullable agar riwayat tahan
  bila produk kelak dihapus), nama snapshot, qty, harga beli snapshot,
  subtotal. Kolom harga jual baru tetap ada (null di v1) untuk kompatibilitas
  v2.
- Simpan restock = 1 transaksi DB: insert restock + items, stok produk
  `+= qty`, harga beli katalog diperbarui, produk jadi dirty.

Backend Postgres: tabel `restocks` + `restock_items` (mirip sales),
endpoint `GET/POST /api/v1/restocks` + `POST /api/v1/restocks/:id/void`.
Server saat menerima: insert + stok `+= qty` + update harga, dalam
1 transaksi DB (baris produk `FOR UPDATE`). Void server: status →
voided + stok `-= qty`, ditolak 409 bila stok kini kurang.
Sinkron manual push-then-pull seperti kasir (produk terkait di-push dulu,
baru restock — reuse pola sinkron kasir).

## Keputusan final (disetujui 2026-11-22)

1. Tanpa nama supplier, tanpa no. nota — fokus produk saja.
2. Harga beli sering berubah → selalu update katalog (live, tanpa tekan
   enter). Harga jual TIDAK diubah lewat restock v1 — ubah via Kelola Produk.
   Batch harga beli per penerimaan (FIFO) = milestone v2.
3. Salah input boleh dibatalkan (alasan wajib, stok kembali atomik).
4. Stok produk baru = 0 (tambah lewat Restock).
5. Void restock ditolak bila stok sudah terlanjur terjual.
