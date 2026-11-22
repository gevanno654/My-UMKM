# Sinkron Global Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Satu tombol "Sinkron Semua" di Home menggantikan 4 tombol sync per halaman, dengan fase push-semua-dulu-baru-pull-semua sehingga stok lokal tidak pernah tertimpa angka server yang basi.

**Architecture:** Buka `_push`/`_pull` tiap notifier (products, sales, restocks, adjustments) jadi method publik tanpa mengubah isi logika; orkestrator baru `sync_all_provider` menjalankan push berurutan (produk → kasir → kulakan → opname) lalu pull berurutan; tombol sync lama dihapus dari 4 layar; tombol + status global di Home.

**Tech Stack:** Flutter 3.38.6, Riverpod NotifierProvider, Dio, Drift, go_router. Backend tidak berubah.

**Spec:** `docs/superpowers/specs/2026-11-22-sync-global-design.md` (disetujui user 2026-11-22: Cara 2, tombol di Home saja, tombol lama dihapus)

## Global Constraints

- Offline-first: tanpa internet semua transaksi tetap tersimpan lokal, pesan error Indonesia spesifik.
- Sinkron manual: tidak ada auto-sync; hanya tombol yang ditekan user.
- Produk di-push DULU sebelum dokumen (kasir/kulakan/opname) yang merujuknya.
- PUT /products mengabaikan stok (stok hanya via dokumen relatif); jangan ubah kontrak ini.
- Pesan error Indonesia yang sudah ada dipertahankan kata per kata bila tidak disebut di plan.
- `flutter test --concurrency 1` hijau + `flutter analyze` bersih sebelum tiap commit.

## Review Focus

- Sync global saat offline total: status offline + pesan Indonesia, tidak ada data berubah -> test di Task 3.
-Sync global dengan dokumen void yang belum pernah terkirim (404 di-push void = sukses) -> test di Task 2.
- Pull produk menimpa stok lokal hasil restock yang belum ter-push: tidak boleh terjadi karena pull produk jalan setelah push semua dokumen -> test regresi di Task 2.
- Tombol per halaman yang dihapus tidak meninggalkan import mati (analyze bersih) -> verifikasi tiap task hapus tombol.
- Riwayat/draft lokal tidak hilang setelah sync global -> tercakup test pull existing + regresi Task 5.

---

### Task 1: Buka push/pull publik di 4 notifier

**Files:**
- Modify: `pos_app/lib/features/products/products_provider.dart`
- Modify: `pos_app/lib/features/sales/sales_provider.dart`
- Modify: `pos_app/lib/features/restocks/restocks_provider.dart`
- Modify: `pos_app/lib/features/adjustments/adjustments_provider.dart`
- Test: tidak ada test baru (test existing harus tetap hijau)

**Interfaces:**
- Consumes: tidak ada (refactor murni).
- Produces (dipakai Task 2, nama harus persis):
  - `Future<void> ProductsNotifier.pushCatalog(String accessToken, void Function(String) onRowError)`
  - `Future<void> ProductsNotifier.pullCatalog(String accessToken)`
  - `Future<void> SalesNotifier.pushSales(String accessToken, void Function(String) onRowError)`
  - `Future<void> SalesNotifier.pullSales(String accessToken)`
  - `Future<void> RestocksNotifier.pushRestocks(String accessToken, void Function(String) onRowError)`
  - `Future<void> RestocksNotifier.pullRestocks(String accessToken)`
  - `Future<void> AdjustmentsNotifier.pushAdjustments(String accessToken, void Function(String) onRowError)`
  - `Future<void> AdjustmentsNotifier.pullAdjustments(String accessToken)`

- [ ] **Step 1: Rename tanpa ubah isi di 4 file**
  - `ProductsNotifier._push` -> `pushCatalog`, `ProductsNotifier._pull` -> `pullCatalog`
  - `SalesNotifier._push` -> `pushSales`, `SalesNotifier._pull` -> `pullSales`
  - `RestocksNotifier._push` -> `pushRestocks`, `RestocksNotifier._pull` -> `pullRestocks`
  - `AdjustmentsNotifier._push` -> `pushAdjustments`, `AdjustmentsNotifier._pull` -> `pullAdjustments`
  - Perbarui semua pemanggil internal (`syncNow` masing-masing tetap memakai nama baru)
  - Jadikan publik (tanpa underscore), tanpa mengubah satu baris logika pun
- [ ] **Step 2: Verifikasi tidak ada yang rusak**

Run: `C:\Users\Gevanno\dev\flutter\bin\flutter.bat test --concurrency 1` (dari `pos_app/`)
Expected: `All tests passed!` (153 test)

- [ ] **Step 3: Commit**

```bash
git add pos_app/lib/features/products/products_provider.dart pos_app/lib/features/sales/sales_provider.dart pos_app/lib/features/restocks/restocks_provider.dart pos_app/lib/features/adjustments/adjustments_provider.dart
git commit -m "refactor: buka push/pull sinkron tiap notifier jadi publik"
```

---

### Task 2: Orkestrator sync global + test regresi

**Files:**
- Create: `pos_app/lib/core/sync/sync_all_provider.dart`
- Test: `pos_app/test/sync_all_test.dart`

**Interfaces:**
- Consumes: 8 method publik dari Task 1; `secureSessionProvider` untuk token (pola `resolveStore` di `sales_screens.dart`); `ref.read(<provider>.notifier)`.
- Produces (dipakai Task 3):
  - `final syncAllProvider = NotifierProvider<SyncAllNotifier, SyncAllState>(SyncAllNotifier.new)`
  - `class SyncAllState { const SyncAllState({this.status = SyncStatus.idle, this.lastError}); final SyncStatus status; final String? lastError; }` (`SyncStatus` enum baru di file ini: `idle, syncing, offline, error`)
  - `Future<void> SyncAllNotifier.syncAll()` — tanpa parameter; ambil token sendiri dari `secureSessionProvider`, ambil storeId dari `authProvider` (pola `ProductsListScreen._boot`: `AuthAuthenticated/AuthPinSetupRequired/AuthPinLocked` -> `profile.storeId`, selain itu error `'Sesi toko tidak ditemukan. Login ulang.'`).
  - Urutan di dalam `syncAll()`: `load(storeId)` tiap notifier bila perlu (ikuti pola `_boot` tiap layar: products.load, sales.load, restocks.load, adjustments.load) → `pushCatalog` → `pushSales` → `pushRestocks` → `pushAdjustments` → `pullCatalog` → `pullSales` → `pullRestocks` → `pullAdjustments` → `_refresh` tiap notifier (products tidak punya `_refresh` publik: panggil `load(storeId)` ulang; sales/restocks/adjustments: panggil `load(storeId)` ulang — verifikasi saat implementasi metode refresh mana yang publik, bila hanya `load` yang publik maka pakai `load`).
  - Error: `firstError` pertama dari callback `onRowError` dikumpulkan; `DioException` koneksi (connectionTimeout/receiveTimeout/connectionError) → status `offline` + pesan `friendlyError` dari api masing-masing (`ProductsApi.friendlyError`); `DioException` lain → rethrow? TIDAK — tangkap, status `error`, pesan friendly; `catch (_)` → status `error`, pesan `'Sinkron gagal. Coba lagi.'`.
  - Status sukses: `firstError == null ? idle : error` + `lastError = firstError`.

- [ ] **Step 1: Tulis test regresi yang gagal dulu di `pos_app/test/sync_all_test.dart`**
  - Ikuti pola `makeAdjustments` di `test/adjustments_test.dart` (fake Dio + `ProviderContainer` overrides + `AppDb.openMemory`), diperluas: seed produk p1 stok 0 + restock 1 baris qty 5 (pakai `RestocksNotifier.saveRestock` via draft, pola `test/restocks_test.dart`) sehingga stok lokal 5 dan produk dirty + restock dirty.
  - Fake server: `PUT /products` balas 200 tanpa bump versi (stok server tetap 0, `updatedAt` lama); `GET /products` balas stok 0; `POST /restocks` catat `restockPosts++`; endpoint lain balas `[]`.
  - Test: `await syncAllNotifier.syncAll()` → expect `restockPosts == 1` dan stok lokal p1 tetap `5` (bug lama: pull produk sebelum push restock akan menimpa jadi 0).
  - Test offline: handler melempar `DioException(connectionError)` → expect status `offline`.
- [ ] **Step 2: Jalankan test baru, pastikan GAGAL (provider belum ada)**

Run: `C:\Users\Gevanno\dev\flutter\bin\flutter.bat test test/sync_all_test.dart`
Expected: FAIL (file provider belum ada / method belum ada)

- [ ] **Step 3: Implementasi `sync_all_provider.dart` sesuai Interfaces di atas**
- [ ] **Step 4: Jalankan test baru + seluruh suite**

Run: `C:\Users\Gevanno\dev\flutter\bin\flutter.bat test --concurrency 1` (dari `pos_app/`)
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add pos_app/lib/core/sync/sync_all_provider.dart pos_app/test/sync_all_test.dart
git commit -m "feat: orkestrator sinkron global push-dulu-baru-pull"
```

---

### Task 3: Tombol Sinkron Semua di Home + hapus 4 tombol lama

**Files:**
- Modify: `pos_app/lib/features/auth/home_placeholder.dart`
- Modify: `pos_app/lib/features/products/products_screens.dart` (hapus tombol sync + `_sync`)
- Modify: `pos_app/lib/features/sales/sales_screens.dart` (hapus tombol sync + `_sync` di HistoryScreen; layar kasir/pay/receipt tidak punya tombol sync — verifikasi)
- Modify: `pos_app/lib/features/restocks/restocks_screens.dart` (hapus tombol sync + `_sync` di list + detail bila ada)
- Modify: `pos_app/lib/features/adjustments/adjustments_screens.dart` (hapus tombol sync + `_sync`)
- Test: `pos_app/test/sync_all_ui_test.dart`

**Interfaces:**
- Consumes: `syncAllProvider`, `SyncAllState` dari Task 2.
- Produces: tidak ada (UI akhir).

- [ ] **Step 1: Tulis widget test yang gagal dulu**
  - `pos_app/test/sync_all_ui_test.dart`, pola `test/adjustments_ui_test.dart` (`_FakeAuthNotifier`, `pumpAt('/home')` — verifikasi route home = `/home` di `router.dart`): di Home ada tombol key `syncAllButton`; tekan → status sinkron tampil (key `syncAllStatus`); tombol sync lama (`syncButton`) tidak ada di `/products`, `/sales/history`, `/restocks`, `/adjustments`.
- [ ] **Step 2: Jalankan, pastikan GAGAL**
- [ ] **Step 3: Implementasi UI**
  - Home: tambah `ElevatedButton(key: syncAllButton, 'Sinkron Semua')` + teks status (key `syncAllStatus`: `'Sinkron...'`, `'Gagal: <pesan>'`, `'Offline'` sesuai state) + error text bila `lastError != null`. `onPressed`: panggil `ref.read(syncAllProvider.notifier).syncAll()`.
  - Hapus tombol sync per halaman: di tiap layar hapus `IconButton(key: syncButton)` + method `_sync` + import yang jadi tak terpakai (`secureSessionProvider` bila tak dipakai lagi di file itu).
  - Method `syncNow` per notifier TETAP ADA (dipakai orkestrator? tidak — orkestrator pakai push/pull publik; `syncNow` per notifier tetap dipertahankan untuk kompatibilitas test existing, JANGAN dihapus).
- [ ] **Step 4: Verifikasi**

Run: `C:\Users\Gevanno\dev\flutter\bin\flutter.bat test --concurrency 1` lalu `flutter analyze`
Expected: `All tests passed!`, `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add pos_app/lib/features/auth/home_placeholder.dart pos_app/lib/features/products/products_screens.dart pos_app/lib/features/sales/sales_screens.dart pos_app/lib/features/restocks/restocks_screens.dart pos_app/lib/features/adjustments/adjustments_screens.dart pos_app/test/sync_all_ui_test.dart
git commit -m "feat: tombol Sinkron Semua di Home, hapus sync per halaman"
```

---

### Task 4: Uji HP + merge

**Files:** tidak ada (verifikasi + git).

- [ ] **Step 1: Migrate + typecheck backend (tidak berubah, pastikan hijau)**

Run (dari `backend/`): `npm run migrate` lalu `npm run typecheck`
Expected: `migration ok` semua + typecheck tanpa error

- [ ] **Step 2: Build APK debug dengan IP laptop aktif**

Run: `ipconfig` (catat IPv4 192.168.x.x), lalu dari `pos_app/`: `flutter build apk --debug --dart-define API_URL=http://<IP>:3000`
Expected: `Built build\app\outputs\flutter-apk\app-debug.apk`

- [ ] **Step 3: Install + uji di HP (skenario bug pelapor)**
  - Restock 1x qty 5 → Sinkron Semua di Home → stok tepat 5 (bukan 10)
  - Kasir jual 5 → Sinkron Semua → stok 0
  - Sinkron Semua lagi → stok tetap 0 (tidak nambah sendiri)
  - Opname + sinkron urutan bebas → stok tetap hasil opname
- [ ] **Step 4: Merge ke master**

```bash
git checkout master
git merge --no-ff feat/opname-v1
git branch -d feat/opname-v1
```

- [ ] **Step 5: Verifikasi akhir master hijau**

Run: `flutter test --concurrency 1` + `flutter analyze` + `npm run typecheck`
Expected: semua hijau
