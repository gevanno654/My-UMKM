# Desain Laporan Pendapatan — 2026-11-23

## Intent & Why
Pemilik warung butuh tahu untung-rugi harian/mingguan/bulanan langsung di HP,
offline, tanpa ekspor. Angka harus bisa dipercaya: laba masa lalu tidak boleh
bergeser walau harga beli diubah belakangan.

## Goals
- Ringkasan periode: omzet, laba kotor, jumlah transaksi, rata-rata struk.
- Produk laris per periode (by qty).
- Rincian transaksi per periode (riwayat yang sudah ada dipakai ulang).
- Periode: harian (default hari ini), mingguan (Senin–Minggu), bulanan.
- Navigasi periode maju/mundur + tombol "Hari ini".
- Void dikecualikan dari semua angka (seolah transaksi tidak pernah ada).
- Tombol "Laporan" di Home (`/reports`).

## Non-goals
- Export PDF/Excel/share (nanti).
- Laporan kulakan/opname (hanya penjualan).

## Visualisasi (disepakati)
- Chart batang omzet + laba berdampingan per hari dalam periode berjalan
  (harian: 1 pasang; mingguan: 7 pasang Senin–Minggu; bulanan: 30/31
  pasang per tanggal). Warna berbeda + legenda.
- Tanpa dependensi chart baru bila bisa digambar sendiri dengan
  CustomPainter; bila terlalu rumit, `fl_chart` (ringan, umum dipakai).

## Anti-goals
- Menghitung laba dari harga beli katalog saat ini (angka masa lalu bergeser).

## Keputusan desain (disepakati)
1. **Laba dari snapshot harga beli saat jual (opsi B).** Tambah kolom
   `cost_price` di `sale_items`, diisi dari katalog saat checkout.
   Laba per item = (price − cost_price) × qty.
2. Skema tanpa join: semua angka laporan dibaca langsung dari
   `sales` + `sale_items` (offline, cepat, satu query per bagian).
3. Transaksi void tidak masuk angka maupun daftar laris.

## Approaches
- **A. Harga beli katalog saat ini (ditolak):** tanpa migrasi, tapi laba
  historis bergeser saat harga beli diubah. Menyesatkan; melawan anti-goal.
- **B. Snapshot cost_price per item (dipilih):** akurat permanen.
  Biaya: migrasi Drift v5→v6 + backend `sale_items.cost_price` + isi saat
  checkout + kirim/terima via API + tampilkan di riwayat.
- **C. Tabel laba terpisah per hari:** denormalisasi ekstra tanpa manfaat
  untuk skala warung; komputasi langsung cukup cepat.

## Diserahkan ke builder
- Detail query Drift (computed SQL vs agregasi Dart — data skala warung,
  agregasi Dart di provider boleh).
- Bentuk state `ReportsState` mengikuti pola notifier yang sudah ada.
- Urutan task dalam plan (migrasi dulu, lalu API, UI terakhir).
