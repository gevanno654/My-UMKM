# Desain Restock v1 (Penerimaan Kulakan)

Tanggal: 2026-11-22. Status: disetujui — lanjut ke rencana kerja.

## Maksud

Mencatat kulakan sebagai **dokumen penerimaan multi-produk**: satu aksi
restock = banyak produk + qty tambah + harga beli saat itu. Stok hanya bisa
bertambah lewat fitur ini — form Kelola Produk tidak lagi bisa sunting stok.

## Tujuan / non-tujuan

- Tujuan: catat satu nota kulakan < 60 detik; 100% offline; stok tidak
  pernah minus; harga beli katalog ikut terkini; harga jual hanya berubah
  bila pengguna mencentang per baris.
- Non-tujuan v1: supplier/grosir master, no. nota, hutang, retur ke
  supplier, koreksi stok manual, stok opname, peringatan stok minimum.

## Alur layar

```
/home → [Restock] → /restocks (riwayat penerimaan)
  → [+ Kulakan] → /restocks/new:
     cari nama / scan barcode → tambah ke daftar
     tiap baris: qty tambah, harga beli baru,
                 [x] ikut ubah harga jual + field harga jual baru
     ringkasan: total item + total modal → Simpan
  → riwayat: tanggal, jumlah item, total modal, status (ok/void)
     → detail → [Batalkan] + alasan wajib → stok kembali
```

- Produk arsip/terhapus: tidak bisa dipilih di restock baru; bila produk
  masuk draft lalu diarsip/dihapus sebelum simpan → simpan diblokir.
- Qty wajib ≥ 1; harga beli/jual ikut batas lama (0..999999999).
- Harga jual katalog **tidak berubah** kecuali checkbox dicentang per baris.
- Harga jual baru boleh di bawah harga beli baru (dizinkan tanpa peringatan).
- Produk yang sama ditambahkan 2x dalam satu draft → gabung 1 baris
  (qty dijumlah, harga beli/jual terakhir menang).
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
  harga jual baru (null bila tidak diubah), subtotal.
- Simpan restock = 1 transaksi DB: insert restock + items, stok produk
  `+= qty`, harga beli diperbarui (dan jual bila dicentang), produk jadi dirty.

Backend Postgres: tabel `restocks` + `restock_items` (mirip sales),
endpoint `GET/POST /api/v1/restocks` + `POST /api/v1/restocks/:id/void`.
Server saat menerima: insert + stok `+= qty` + update harga, dalam
1 transaksi DB (baris produk `FOR UPDATE`). Void server: status →
voided + stok `-= qty`, ditolak 409 bila stok kini kurang.
Sinkron manual push-then-pull seperti kasir (produk terkait di-push dulu,
baru restock — reuse pola sinkron kasir).

## Keputusan final (disetujui 2026-11-22)

1. Tanpa nama supplier, tanpa no. nota — fokus produk saja.
2. Harga beli sering berubah → selalu update katalog; harga jual opsional
   per baris via checkbox.
3. Salah input boleh dibatalkan (alasan wajib, stok kembali atomik).
4. Stok produk baru = 0 (tambah lewat Restock).
5. Void restock ditolak bila stok sudah terlanjur terjual.
