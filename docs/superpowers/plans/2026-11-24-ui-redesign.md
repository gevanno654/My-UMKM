# UI Redesign (arah A: netral + aksen biru logo) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ganti sistem tema + navigasi + seluruh tampilan POS Warung tanpa mengubah logika bisnis.

**Architecture:** Token tema terpusat (`app_theme.dart`: light/dark + `ThemeMode` provider); shell navigasi adaptif (`app_shell.dart`: drawer HP / rail tablet ≥840dp) yang membungkus route fitur; layar auth + keypad PIN custom; home ringkasan. Provider/API/DB/router tidak berubah kecuali menukar widget builder.

**Tech Stack:** Flutter 3.38, Material 3, Riverpod 3, GoRouter 17, flutter_test.

**Spec:** `docs/superpowers/specs/2026-11-24-ui-redesign-design.md`

## Global Constraints

- Flutter 3.38, Material 3, Riverpod 3, GoRouter 17 — tanpa dependensi baru.
- Semua `Key` widget yang dipakai test dipertahankan: syncAllButton, syncAllStatus, kasirButton, restockButton, opnameButton, productsButton, reportsButton, logoutButton, confirmLogoutButton, pinField, confirmPinField, pinSetupButton, pinUnlockButton, errorText, emailField, passwordField, loginButton, registerButton, storeField, ownerField, confirmField, kasirSearchField, payButton, paidField, confirmPayButton, historyButton, voidButton, confirmVoidButton, receiptBackButton, revenueValue, profitValue, profitChart, periodWeekButton, rangeLabel, prevPeriodButton, todayButton, periodDayButton, kulakanButton, restockSearchField, saveRestockButton, voidRestockButton, voidReasonField, adjustButton, physicalField, reasonField, saveAdjustButton, adjustErrorText, costField, sellField, saveButton, nameField.
- `flutter test --concurrency 1` + `flutter analyze` bersih tiap task.
- PIN tetap 6 digit; brute-force guard tidak berubah; tanpa keyboard bawaan di layar PIN.
- Uang INTEGER rupiah; format `formatRupiah` dipakai ulang, tidak ditulis ulang.

## Review Focus

- Tablet 10" landscape: rail + konten tidak overlap, max-width konten dihormati — resize window emulator dan pastikan tidak overflow.
- Rotasi HP saat keypad PIN terbuka: indikator 6 titik tidak hilang/reset.
- Toggle tema manual bertahan saat aplikasi direstart (persistensi sederhana).
- Logo tampil di splash + header sidebar tanpa jank (asset didaftarkan sekali).
- Tombol Kembali Android dari layar fitur kembali ke home, bukan keluar aplikasi.

---

### Task 1: Token tema + toggle light/dark

**Files:**
- Create: `pos_app/lib/core/theme/app_theme.dart`
- Create: `pos_app/lib/core/theme/theme_mode_provider.dart`
- Modify: `pos_app/lib/main.dart:55-63`
- Test: `pos_app/test/theme_test.dart`

**Interfaces:**
- Consumes: —
- Produces: `AppTheme.light() -> ThemeData`, `AppTheme.dark() -> ThemeData`, `themeModeProvider` (`NotifierProvider<ThemeModeNotifier, ThemeMode>` dengan `setMode(ThemeMode)` + persist), `AppColors.primaryBlue = Color(0xFF1E6FDB)` (nilai exact boleh disesuaikan ±10% dari sampling logo, dicatat di commit).

- [ ] **Step 1: Tulis test gagal** `theme_test.dart`: `AppTheme.light().colorScheme.primary == AppColors.primaryBlue`; `AppTheme.dark().brightness == Brightness.dark`; `setMode(ThemeMode.dark)` mengubah state + persist (baca ulang provider = dark).
- [ ] **Step 2: Jalankan, pastikan gagal** (`flutter test test/theme_test.dart`, file belum ada).
- [ ] **Step 3: Implementasikan** `app_theme.dart` (skema M3: light seed biru logo + surface hangat netral; dark arang netral; tipografi default M3) + `theme_mode_provider.dart` (persist via secure storage sederhana / shared_preferences bila sudah ada — cek dulu, tanpa dependensi baru bila bisa).
- [ ] **Step 4: Pasang di `main.dart`**: `theme:`, `darkTheme:`, `themeMode: ref.watch(themeModeProvider)`.
- [ ] **Step 5: `flutter test test/theme_test.dart` + `flutter analyze`** — hijau.
- [ ] **Step 6: Commit** `feat(ui): token tema light/dark + toggle persist`.

### Task 2: Aset logo + splash berlogo

**Files:**
- Create: `pos_app/assets/logo.png` (salin dari `logo.png` root repo)
- Modify: `pos_app/pubspec.yaml` (daftarkan `assets/logo.png`)
- Modify: `pos_app/lib/features/auth/splash_screen.dart`
- Test: `pos_app/test/splash_test.dart` (baru; test lama tidak ada untuk splash)

**Interfaces:**
- Consumes: `AppTheme` (Task 1, untuk background splash).
- Produces: Splash menampilkan `Image.asset('assets/logo.png')` + nama aplikasi, lalu boot sesi seperti sekarang.

- [ ] **Step 1: Tulis test gagal**: splash memuat asset logo + teks `POS Warung`.
- [ ] **Step 2: Jalankan, pastikan gagal.**
- [ ] **Step 3: Salin logo, daftarkan asset, ganti body splash** (spinner → logo tengah + nama; `_boot()` tidak berubah).
- [ ] **Step 4: Verifikasi hijau + analyze.**
- [ ] **Step 5: Commit** `feat(ui): splash berlogo`.

### Task 3: Keypad PIN custom + layar buat/buka PIN

**Files:**
- Create: `pos_app/lib/features/auth/pin_pad.dart`
- Modify: `pos_app/lib/features/auth/pin_setup_screen.dart`
- Modify: `pos_app/lib/features/auth/pin_unlock_screen.dart`
- Test: `pos_app/test/pin_pad_test.dart` (baru) + sesuaikan `pos_app/test/pin_offline_test.dart` (ganti `enterText(pinField)` → tap tombol keypad; `Key` lama dipertahankan di tombol keypad: `pinField` = indikator, `pinSetupButton`/`pinUnlockButton` = tombol konfirmasi)

**Interfaces:**
- Consumes: `completePinSetup`, `unlockSession`, `PinGuard` (tidak berubah).
- Produces: `PinPad({required ValueChanged<String> onChanged, int length = 6, Key? key})` — grid 3x4 (1-9, kosong, 0, hapus), tanpa `TextField`, tanpa keyboard sistem.

- [ ] **Step 1: Tulis test gagal** `pin_pad_test.dart`: tap 1-2-3 → `onChanged('123')`; tap hapus → mundur; 6 digit penuh → tombol konfirmasi aktif.
- [ ] **Step 2: Jalankan, pastikan gagal.**
- [ ] **Step 3: Implementasikan `PinPad`** (tombol angka besar, indikator titik 6, tombol hapus; `Key('pinKey-1')` dst untuk test).
- [ ] **Step 4: Migrasi kedua layar PIN** ke `PinPad` (validasi + error + guard tetap; `Key` lama dipertahankan).
- [ ] **Step 5: Sesuaikan `pin_offline_test.dart`**, full suite + analyze hijau.
- [ ] **Step 6: Commit** `feat(ui): keypad PIN custom`.

### Task 4: Layar login + registrasi baru

**Files:**
- Modify: `pos_app/lib/features/auth/login_screen.dart`
- Modify: `pos_app/lib/features/auth/register_screen.dart`
- Test: pakai `pos_app/test/auth_online_test.dart` yang ada (tanpa test baru; `Key` dipertahankan).

**Interfaces:**
- Consumes: `AppTheme`, `authProvider.login/register` (tidak berubah).
- Produces: Form kolom tunggal max-width 420dp rata tengah, logo kecil di atas, link login↔register.

- [ ] **Step 1: Catat baseline**: `flutter test test/auth_online_test.dart` hijau sebelum ubah.
- [ ] **Step 2: Tulis ulang tampilan kedua layar** (logo, field email/password/nama toko/pemilik, error, loading; `Key` sama persis).
- [ ] **Step 3: Full suite + analyze hijau.**
- [ ] **Step 4: Commit** `feat(ui): tampilan login dan registrasi`.

### Task 5: Shell adaptif (drawer HP / rail tablet) + home ringkasan

**Files:**
- Create: `pos_app/lib/core/nav/app_shell.dart`
- Modify: `pos_app/lib/features/auth/home_placeholder.dart` → ganti jadi `home_screen.dart` (ringkasan hari ini: omzet/transaksi + tombol cepat Kasir; pakai `reportsProvider` read-only yang sudah ada)
- Modify: `pos_app/lib/core/router.dart` (bungkus route fitur dalam `ShellRoute` → `AppShell`; route `/home` jadi `HomeScreen`)
- Test: sesuaikan `pos_app/test/sync_all_ui_test.dart`, `sales_ui_test.dart`, `reports_ui_test.dart` (navigasi via sidebar: `Key('nav-kasir')` dst; `Key` lama tetap ada di tujuan).

**Interfaces:**
- Consumes: `ThemeMode` toggle (Task 1), route paths (tidak berubah).
- Produces: `AppShell({required Widget child})` — `NavigationDrawer` bila lebar <840dp, `NavigationRail` permanen bila ≥840dp; item: Kasir(`/sales`), Kelola Produk(`/products`), Restock(`/restocks`), Opname(`/adjustments`), Laporan(`/reports`); bawah: toggle tema (`Key('themeToggleButton')`), Keluar (`logoutButton` tetap).

- [ ] **Step 1: Tulis test gagal**: lebar tablet → rail tampil + drawer tidak ada; tap `nav-kasir` → pindah `/sales`; toggle tema → mode berubah.
- [ ] **Step 2: Jalankan, pastikan gagal.**
- [ ] **Step 3: Implementasikan `AppShell`** (breakpoint 840dp via `LayoutBuilder`/`MediaQuery`).
- [ ] **Step 4: Tulis ulang home** jadi ringkasan (data read-only dari provider laporan; tombol cepat; `syncAllButton` + `syncAllStatus` tetap).
- [ ] **Step 5: Pasang `ShellRoute` di router**, sesuaikan test UI yang navigasi.
- [ ] **Step 6: Full suite + analyze hijau.**
- [ ] **Step 7: Commit** `feat(ui): shell adaptif + home ringkasan`.

### Task 6: Tampilan ulang layar fitur (kasir, produk, restock, opname, laporan, riwayat, struk)

**Files:**
- Modify: `sales_screens.dart`, `products_screens.dart`, `product_form_screen.dart`, `scan_screen.dart`, `restocks_screens.dart`, `adjustments_screens.dart`, `reports_screens.dart` (+ `profit_bar_chart.dart` bila perlu)
- Test: tanpa test baru; full suite yang ada (`Key` dipertahankan semua).

**Interfaces:**
- Consumes: `AppShell` (Task 5), `AppTheme` (Task 1).
- Produces: Setiap layar: AppBar judul + aksi seperlunya, konten max-width 720dp di tablet, kasir master-detail (katalog + panel keranjang) di tablet; angka uang tabular rata kanan; tanpa warna per fitur.

- [ ] **Step 1: Catat baseline**: full suite hijau sebelum ubah.
- [ ] **Step 2: Migrasi layar per layar** (satu layar satu sub-commit bila perlu; `Key` sama persis; logika provider tidak disentuh).
- [ ] **Step 3: Full suite + analyze hijau.**
- [ ] **Step 4: Commit** `feat(ui): tampilan ulang layar fitur`.
