# Redesign UI POS Warung — Design Doc (arah A)

**Tanggal:** 2026-11-24. **Status:** disetujui (arah A), siap jadi acuan plan.

## Intent & Why

Aplikasi warung dipakai pemilik sendirian di HP (kadang tablet), sering
dengan satu tangan sambil melayani pembeli. Tampilan sekarang fungsional
tapi generik: tema seed-teal bawaan, tombol-tombol polos, navigasi
campuran (bottom bar entah, tombol kembali per layar). Redesign ini
mengganti **sistem tema + navigasi + seluruh tampilan** tanpa mengubah
logika bisnis: auth, PIN, sinkron, kasir, stok tetap sama.

## Goals

- Identitas jelas: logo `logo.png` di splash + header navigasi.
- Light & dark adaptif (`ThemeMode.system` + toggle manual di sidebar).
- Navigasi satu pola: sidebar daftar menu (Kasir, Kelola Produk, Restock,
  Opname, Laporan, Sinkron, Keluar); HP = drawer, tablet ≥840dp = rail
  permanen.
- Keypad angka custom untuk buat PIN dan buka PIN (tanpa keyboard bawaan).
- Rapi di HP kecil (360dp) sampai tablet (10").
- Tidak terlihat seperti template AI.

## Non-goals / Anti-goals

- Tanpa perubahan API backend, skema DB, aturan sinkron, aturan stok/harga.
- Tanpa multi-user/peran, tanpa cetak laporan, tanpa backup baru.
- Anti-goal: gradien ungu-biru, kartu warna-warni per menu, ikon emoji,
  bayangan tebal, font dekoratif. Kegagalan = terlihat generik meski
  teknisnya benar.

## Constraints

- Flutter 3.38, Material 3, Riverpod 3, GoRouter 17 (tetap).
- Semua `Key` widget test yang ada dipertahankan (test tidak ditulis ulang).
- Dark mode harus lolos kontras teks minimal 4.5:1 untuk teks utama.
- PIN tetap 6 digit, brute-force guard tetap (5x salah → kunci 60 dtk).

## Approaches (dipilih: A)

- **A. Netral + aksen biru logo (dipilih).** Permukaan light hangat netral
  (`#FAF7F2`-ish), dark arang netral (`#16181D`-ish); biru logo
  (`#1E6FDB`-ish, diambil dari logo) hanya untuk aksi utama dan status
  aktif. Hierarki dari tipografi + jarak, bukan warna. Dark/light konsisten
  karena yang berubah hanya permukaan.
- **B. Material seed-blue penuh (ditolak).** Terlihat generik, semua aplikasi
  seed-blue sama.
- **C. Tema warung hangat kertas+tinta (ditolak).** Paling khas tapi dark
  mode-nya berisiko kotor dan butuh disiplin ekstra; effort tidak sebanding
  untuk tahap ini.

## Keputusan desain (final)

- Token warna: `surface`, `surfaceContainer`, `primary` (biru logo),
  `error` standar M3; tanpa warna khusus per fitur.
- Tipografi: satu family sistem, skala M3; angka uang tabular, rata kanan.
- Splash: logo tengah + nama aplikasi, lalu boot sesi (alur tetap).
- Auth: login/register form tunggal kolom, max-width 420dp, rata tengah di
  tablet.
- Keypad PIN: grid 3x4 tombol angka besar, titik indikator 6, hapus +
  (opsional) biometrik tidak ada — murni PIN.
- Home: ringkasan hari ini (omzet, transaksi, stok menipis) + tombol aksi
  cepat ke Kasir; bukan sekadar daftar tombol.
- Sidebar: header logo + nama toko, item menu dengan ikon M3 outlined,
  bagian bawah: toggle tema + tombol Keluar.
- Kasir dkk: AppBar judul + aksi seperlunya, konten max-width 720dp di
  tablet, keranjang kasir jadi panel samping di tablet (master-detail).

## Diserahkan ke builder

Urutan implementasi, nama file/token/class exact, dan test per tahap ada
di plan (menyusul). Builder bebas memilih nilai padding/radius selama
konsisten via token tema.
