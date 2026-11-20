# Desain Kasir v1 (Transaksi Penjualan)

Tanggal: 2026-11-22. Status: disetujui — lanjut ke rencana kerja.

## Maksud

Kasir untuk pemilik warung (1 user): catat transaksi cepat via cari nama
atau scan barcode, bayar tunai/QRIS/transfer, struk di layar, stok
berkurang otomatis. Barang tanpa barcode dijual via pencarian nama
(foto tampil sebagai pembantu visual).

## Tujuan / non-tujuan

- Tujuan: transaksi < 30 detik untuk 1–5 item; 100% offline; stok tidak
  pernah minus; harga tercatat snapshot (edit harga produk tidak mengubah
  riwayat).
- Non-tujuan v1: scan foto otomatis (plan khusus ML), cetak struk
  Bluetooth (arsitektur disiapkan: data struk terstruktur), hutang/piutang,
  diskon/promo, retur, multi-kasir.

## Alur layar

```
Kasir (keranjang) ──scan──▶ ScanScreen (reuse, target 'kasir')
   │ cari nama (dropdown + foto thumb) / ubah qty / hapus item
   ▼
Bayar: total, metode [Tunai|QRIS|Transfer], nominal (tunai) → kembalian
   ▼
Struk layar: nomor, tanggal, item×qty, total, bayar, kembali, metode
[tombol: Transaksi Baru]
```

- Produk arsip / terhapus: tidak muncul di pencarian kasir.
- Stok 0 / kurang dari qty: item ditolak dengan pesan (bukan diam-diam nol).
- Produk dihapus dari katalog setelah pernah terjual: riwayat tetap tampil
  (snapshot nama+harga di baris transaksi).
- Nomor struk: `<INISIAL><DDMMYYYY><NNNN>` — contoh toko "Toko Evan" →
  `TE211120260001` (transaksi 21-11-2026 urutan ke-1 hari itu).
  - Inisial: huruf pertama tiap kata nama toko (A-Z, maks 3 kata pertama);
    nama satu kata → 3 huruf pertama. Contoh: "Toko Evan" → `TE`,
    "Warung Barokah Jaya" → `WBJ`, "Sembako" → `SEM`.
  - `NNNN`: urutan transaksi toko itu pada tanggal tersebut (reset harian,
    zero-padded minimal 4 digit). Unik per (toko, nomor) — server + lokal
    enforcing unique index. v1 satu HP per toko sehingga nomor urut lokal
    cukup; bila sync menolak duplikat → tampilkan error, kasir buat ulang.
- Metode bayar: Tunai (nominal wajib ≥ total → kembalian otomatis) |
  QRIS / Transfer (**hanya dicatat**, tanpa verifikasi otomatis maupun
  kolom referensi di v1).
- Keranjang **persist** (tahan pindah layar + restart HP): tabel `cart_lines`
  lokal. Saat bayar, validasi ulang tiap baris terhadap katalog terkini
  (produk terarsip/terhapus → baris ditandai bermasalah, kasir hapus manual
  sebelum bisa bayar; harga ikut harga terkini saat bayar).
- Transaksi yang sudah dibayar bersifat final: **tidak bisa diedit/dihapus**,
  tapi bisa **void beraudit**: status → `voided` + alasan wajib + waktu void,
  stok dikembalikan (+qty) dalam transaksi DB yang sama. Koreksi =
  void lalu buat transaksi baru. Nomor struk void tidak dipakai ulang.

## Data

Drift lokal (sumber utama), tabel baru:
- `sales`: id UUID lokal, storeId, nomor (`<INISIAL><DDMMYYYY><NNNN>`),
  total, bayar, kembali, metode, status (ok/voided), alasan void, createdAt
  millis, dirty.
- `sale_items`: id, saleId, productId (nullable bila produk dihapus),
  nama snapshot, harga snapshot, qty, subtotal, dirty.
- Stok produk berkurang dalam transaksi DB yang sama dengan insert sale.

Backend Postgres: tabel `sales` + `sale_items` (FK store, id = UUID client),
endpoint `GET/POST /api/v1/sales` (+ items nested), isolasi `store_id` JWT.
Sinkron manual mengikuti pola produk (push-then-pull, LWW, delete menang —
kasir v1 tanpa hapus/edit transaksi).

State: `SalesNotifier` (keranjang persist di `cart_lines` + validasi ulang
saat bayar; void → `status=voided` + alasan + kembalikan stok atomik).
`POST` sinkron memakai harga snapshot dari HP.

## Keputusan final (disetujui 2026-11-22)

1. Nomor struk custom inisial toko: `<INISIAL><DDMMYYYY><NNNN>`.
2. QRIS/transfer hanya dicatat.
3. Keranjang persist (tahan pindah layar + restart), validasi ulang saat bayar.
4. Riwayat final tapi bisa void beraudit (alasan wajib + stok kembali).

## Pendekatan yang dipertimbangkan

1. **Keranjang di memori + tabel sales/sale_items** (dipilih): sederhana,
   transaksi atomik lokal, sinkron reuse pola produk.
2. Keranjang persist di Drift: tahan pindah layar, tapi kompleksitas
   draft/cleanup tidak sebanding untuk v1.
3. Transaksi langsung ke backend (tanpa tabel lokal): melanggar
   offline-first.

## Keputusan yang perlu Anda setujui

1. Nomor struk `YYYYMMDD-nnn` (reset harian per toko)?
2. QRIS/transfer hanya dicatat (tanpa verifikasi otomatis) — OK?
3. Keranjang hilang saat keluar layar kasir — OK untuk v1?
4. Edit/hapus transaksi lampau: tidak bisa di v1 (riwayat final)?

## Terbuka untuk builder

- Format tanggal/nomor struk final, denominasi cepat tunai (Uang pas / 50rb / 100rb).
- Struktur data struk disiapkan agar printer Bluetooth tinggal plug-in.
