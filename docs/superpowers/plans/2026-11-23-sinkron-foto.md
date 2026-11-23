# Sinkron Foto Produk Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** File foto produk ikut ke cloud di dalam satu tombol "Sinkron Semua" yang sudah ada, transfer hanya saat hash berubah (dua arah), tanpa menu baru.

**Architecture:** Skema dulu (Postgres 008 + Drift v6→v7 kolom `photo_hash`/`photo_size`), lalu endpoint file di server (disk per-store + manifest), lalu client hitung SHA-256 + API multipart, terakhir fase foto otomatis di `SyncAllNotifier` setelah dokumen selesai.

**Tech Stack:** Express 5 + `multer` (multipart ≤2MB, memory storage) + `pg`, Flutter (Riverpod, Dio multipart, `crypto` SHA-256 sudah di pubspec), vitest + flutter_test.

**Spec:** `docs/superpowers/specs/2026-11-23-sinkron-foto-design.md`

## Global Constraints
- Offline-first: tanpa internet semua fitur utama jalan; fase foto skip diam-diam saat offline (bukan error).
- Isolasi `store_id`: file di `<DATA_DIR>/<storeId>/<hash>.jpg`; download lintas store ditolak 404.
- Stok HP otoritatif: fase foto tidak boleh mengubah stok atau dirty stok; hanya kolom foto + file.
- Satu tombol Sinkron: tidak ada route/tombol/menu "backup foto" baru.
- Simpan apa adanya dari HP (sudah `maxWidth: 1024 + quality 80` saat pick); server tidak kompres ulang; tolak > 2MB dengan 413.
- `flutter test --concurrency 1` hijau + `flutter analyze` bersih tiap commit; backend `npm run typecheck` + `npm test` hijau tiap commit.

## Review Focus
- HP baru pull katalog menimpa `photoPath` lokal dengan string kosong server → thumbnail pecah walau file terunduh (pull harus pertahankan path lokal, identitas = hash).
- Upload 2.1MB lolos → server bengkak; harus 413 + sinkron lanjut file lain dengan error parsial.
- Produk dihapus (soft delete) lalu purge: file yatim menumpuk di disk server selamanya.
- `photoHash` lokal dihitung dari file yang sudah dihapus/di-rename → crash sinkron, bukan skip.
- Manifest besar (ratusan produk) diunduh tiap sinkron tanpa pagination/cache → lambat di koneksi warung.

---

### Task 1: Backend file foto + manifest + migrasi 008

**Files:**
- Create: `backend/migrations/008_product_photos.sql`
- Modify: `backend/src/products/routes.ts`
- Modify: `backend/package.json` (tambah `multer` + `@types/multer` dev)
- Test: `backend/__tests__/product_photos.test.ts`

**Interfaces:**
- Consumes: tabel `products`, auth Bearer + `storeIdOf(req)` yang sudah ada.
- Produces:
  - `POST /api/v1/products/:id/photo` (multipart field `photo`, ≤2MB else 413, simpan `<DATA_DIR>/<storeId>/<sha256>.jpg`, update `photo_hash/photo_size`, return `toJson` + `photoHash/photoSize`)
  - `GET /api/v1/products/photo-manifest` → `[{id, photoHash}]` milik store
  - `GET /api/v1/products/photos/:hash` → `image/jpeg`, 404 bila hash bukan milik store
  - `DELETE /api/v1/products/:id/photo` → hapus file + kosongkan kolom (dipakai purge)
  - `toJson` selalu memuat `photoHash` (string) + `photoSize` (int)

- [ ] **Step 1: Write the failing test**

```ts
it("upload → manifest → download round-trip per store", async () => {
  const up = await request(app).post(`/api/v1/products/${productIdA}/photo`)
    .set("Authorization", `Bearer ${tokenA}`)
    .attach("photo", Buffer.from([0xff, 0xd8, 0xff, 0xd9]), "a.jpg");
  expect(up.status).toBe(200);
  expect(up.body.photoHash).toMatch(/^[0-9a-f]{64}$/);
  const man = await request(app).get("/api/v1/products/photo-manifest")
    .set("Authorization", `Bearer ${tokenA}`);
  expect(man.body).toContainEqual({ id: productIdA, photoHash: up.body.photoHash });
  const dl = await request(app).get(`/api/v1/products/photos/${up.body.photoHash}`)
    .set("Authorization", `Bearer ${tokenA}`);
  expect(dl.status).toBe(200);
  // isolasi: store B tidak bisa unduh hash store A
  const cross = await request(app).get(`/api/v1/products/photos/${up.body.photoHash}`)
    .set("Authorization", `Bearer ${tokenB}`);
  expect(cross.status).toBe(404);
});
it("upload > 2MB → 413", async () => {
  const big = Buffer.alloc(2 * 1024 * 1024 + 1, 1);
  const res = await request(app).post(`/api/v1/products/${productIdA}/photo`)
    .set("Authorization", `Bearer ${tokenA}`).attach("photo", big, "big.jpg");
  expect(res.status).toBe(413);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm test -- __tests__/product_photos.test.ts`
Expected: FAIL (file/route belum ada)

- [ ] **Step 3: Migrasi `008_product_photos.sql`**

```sql
ALTER TABLE products ADD COLUMN IF NOT EXISTS photo_hash text NOT NULL DEFAULT '';
ALTER TABLE products ADD COLUMN IF NOT EXISTS photo_size integer NOT NULL DEFAULT 0 CHECK (photo_size >= 0);
```

- [ ] **Step 4: Implementasi `routes.ts` + `multer`**

`npm i multer && npm i -D @types/multer`. `multer({ storage: memoryStorage, limits: { fileSize: 2*1024*1024 } })`, error `LIMIT_FILE_SIZE` → 413 `{error:"photo too large"}`. `DATA_DIR = process.env.PHOTO_DIR ?? '<repo>/backend/.data/photos'`, `mkdirSync(recursive)`. Semua query produk tambah `photo_hash, photo_size`; `toJson` tambah keduanya. Manifest + download + delete cek kepemilikan via `SELECT ... WHERE store_id`. Jangan ubah logika stok.

- [ ] **Step 5: Run tests to verify they pass**

Run: `npm run migrate && npm run typecheck && npm test`
Expected: PASS (47 lama + baru)

- [ ] **Step 6: Commit**

```bash
git add backend/migrations/008_product_photos.sql backend/src/products/routes.ts backend/package.json backend/package-lock.json backend/__tests__/product_photos.test.ts
git commit -m "feat: endpoint file foto produk + manifest hash"
```

### Task 2: Skema lokal + hash SHA-256 saat foto disimpan

**Files:**
- Modify: `pos_app/lib/core/db/app_db.dart` (kolom + migrasi v6→v7)
- Modify: `pos_app/lib/core/db/app_db.g.dart` (manual, pola `costPrice` Task laporan: deklarasi kolom, `$columns`, validate, map, dataclass, toColumns, fromJson/toJson, copyWith, companion)
- Modify: `pos_app/lib/features/products/product_model.dart` (`photoHash=''`, `photoSize=0`)
- Modify: `pos_app/lib/features/products/photo_store.dart` (tambah `sha256Of`)
- Modify: `pos_app/lib/features/products/products_api.dart` (`_toServer` + `_fromServer` + `ProductRowX`)
- Modify: `pos_app/lib/features/products/products_provider.dart` (`newProduct` + pull pertahankan path)
- Test: `pos_app/test/products_test.dart` (tambah grup `PhotoHash`)

**Interfaces:**
- Consumes: `PhotoStore.savePicked` yang sudah ada.
- Produces:
  - `Products.photoHash: TextColumn` (default `''`), `Products.photoSize: IntColumn` (default `0`)
  - `ProductModel.photoHash: String = ''`, `ProductModel.photoSize: int = 0`
  - `Future<String> sha256Of(File file)` di `photo_store.dart` (pakai `package:crypto/crypto.dart` yang sudah ada)
  - `_toServer` kirim `photoHash/photoSize`; `_fromServer` parse keduanya (default `''`/0); `ProductRowX.toModel` map keduanya

- [ ] **Step 1: Write the failing test**

```dart
test('savePicked + sha256Of stabil; model bawa hash', () async {
  final relative = await store.savePicked(XFile(src.path), filename: 'uji.jpg');
  final file = await store.resolve(relative);
  final h1 = await sha256Of(file);
  final h2 = await sha256Of(file);
  expect(h1, matches(RegExp(r'^[0-9a-f]{64}$')));
  expect(h1, h2);
  final m = env.notifier.newProduct(name: 'Kopi', photoPath: relative, photoHash: h1, photoSize: await file.length());
  expect(m.photoHash, h1);
});
test('pull pertahankan photoPath lokal (identitas = hash)', () async {
  // server balas photoPath '' + photoHash 'abc' → lokal photoPath tetap, hash ikut server.
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/products_test.dart --plain-name "sha256Of stabil"`
Expected: FAIL (`sha256Of` / kolom belum ada)

- [ ] **Step 3: Implementasi kolom + migrasi + model + `sha256Of`**

`app_db.dart`: tambah `TextColumn get photoHash => text().withDefault(const Constant(''))();` + `IntColumn get photoSize => integer().withDefault(const Constant(0))();`, `schemaVersion => 7`, `if (from <= 6) { await m.addColumn(products, products.photoHash); await m.addColumn(products, products.photoSize); }`. `app_db.g.dart`: edit manual 9 titik pola `costPrice`. `product_model.dart`: tambah field + konversi `row.photoHash/row.photoSize` di `fromRow`/`toCompanion`/`toModel`.

- [ ] **Step 4: `_toServer`/`_fromServer` + pull pertahankan path**

`_toServer` tambah `'photoHash': p.photoHash, 'photoSize': p.photoSize`. `_fromServer` parse keduanya. `pullCatalog`: ganti `photoPath: Value(s.photoPath)` → `photoPath: Value(localModel.photoPath)` di kedua cabang insert (baru + LWW), tambah `photoHash: Value(s.photoHash), photoSize: Value(s.photoSize)`.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/products_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add pos_app/lib/core/db/app_db.dart pos_app/lib/core/db/app_db.g.dart pos_app/lib/features/products/product_model.dart pos_app/lib/features/products/photo_store.dart pos_app/lib/features/products/products_api.dart pos_app/lib/features/products/products_provider.dart pos_app/test/products_test.dart
git commit -m "feat: kolom photo hash lokal + pertahankan path saat pull"
```

### Task 3: Client API foto (upload/download/manifest)

**Files:**
- Modify: `pos_app/lib/features/products/products_api.dart` (tambah 3 method + 413)
- Test: `pos_app/test/products_test.dart` (grup `PhotoApi` dengan `fakeDio`)

**Interfaces:**
- Consumes: `ProductsApi._dio/_auth` + `ProductModel.photoHash` dari Task 2.
- Produces:
  - `Future<({String photoHash, int photoSize})> uploadPhoto({required String accessToken, required String productId, required File file})` (multipart field `photo`, filename basename)
  - `Future<List<int>> downloadPhoto({required String accessToken, required String hash})` (`ResponseType.bytes`)
  - `Future<Map<String, String>> photoManifest({required String accessToken})` (`[{id, photoHash}]` → map)
  - `friendlyError`: 413 → `'Foto terlalu besar (maks 2MB).'`

- [ ] **Step 1: Write the failing test**

```dart
test('upload mengirim multipart field photo; 413 ramah', () async {
  String? uploadField; List<int>? sent;
  final api = ProductsApi(dio: fakeDio((o) async {
    if (o.path.endsWith('/photo') && o.method == 'POST') {
      final form = o.data as FormData;
      uploadField = form.files.singleOrNull?.key;
      sent = form.files.singleOrNull?.value as List<int>?;
      return ok(o, {'photoHash': 'h' * 64, 'photoSize': 4});
    }
    return fail(o, 413, {'error': 'photo too large'});
  }));
  final r = await api.uploadPhoto(accessToken: 't', productId: 'p1', file: srcFile);
  expect(uploadField, 'photo');
  expect(r.photoHash, hasLength(64));
  expect(ProductsApi.friendlyError(err413), contains('2MB'));
});
test('manifest + download bytes', () async { ... });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/products_test.dart --plain-name "multipart field photo"`
Expected: FAIL (method belum ada)

- [ ] **Step 3: Implementasi 3 method di `products_api.dart`**

`uploadPhoto`: `FormData.fromMap({'photo': await MultipartFile.fromFile(file.path, filename: basename)})`, POST `/api/v1/products/$productId/photo`, parse `photoHash/photoSize`. `downloadPhoto`: GET `/api/v1/products/photos/$hash` bytes. `photoManifest`: GET `/api/v1/products/photo-manifest` → map. `friendlyError`: tambah `case 413`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/products_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add pos_app/lib/features/products/products_api.dart pos_app/test/products_test.dart
git commit -m "feat: client upload-download-manifest foto"
```

### Task 4: Fase foto otomatis di Sinkron Semua + purge

**Files:**
- Modify: `pos_app/lib/features/products/products_provider.dart` (tambah `syncPhotos`)
- Modify: `pos_app/lib/core/sync/sync_all_provider.dart` (panggil fase foto)
- Modify: `pos_app/lib/features/products/product_form_screen.dart` (hitung hash saat pick)
- Test: `pos_app/test/sync_photos_test.dart` (baru)

**Interfaces:**
- Consumes: `ProductsApi.uploadPhoto/downloadPhoto/photoManifest` (Task 3), `PhotoStore.resolve/savePicked/sha256Of` (Task 2), `AppDb` produk lokal.
- Produces:
  - `Future<void> syncPhotos(String accessToken, {PhotoStore? photoStore, void Function(String)? onFileError})` di `ProductsNotifier`: manifest → upload (file lokal ada + hash ≠ server) → unduh (hash server non-kosong + (hash ≠ lokal || file lokal hilang)) → simpan via `PhotoStore` ke `product_photos/<hash>.jpg`, update `photoHash/photoSize/photoPath` lokal. Per-file gagal → `onFileError`, lanjut. Offline (`connectionError/timeout`) → return diam-diam.
  - `SyncAllNotifier.syncAll()`: panggil `products.syncPhotos` setelah pull dokumen, sebelum `load` ulang; error parsial → `firstError`.
  - `product_form_screen.dart`: setelah `savePicked`, hitung `sha256Of` + `length`, teruskan ke save agar kolom langsung terisi (bukan nunggu sinkron).

- [ ] **Step 1: Write the failing test**

```dart
test('syncPhotos upload hanya yang berubah + unduh yang kurang', () async {
  // lokal: p1 hash H1 (server kosong → upload 1x), p2 hash sama server (no-op),
  // server: p3 hash H3 tak ada lokal → download 1x + file ada di PhotoStore.
  // Dio palsu hitung uploadCount/downloadCount; file hilang → skip tanpa throw.
});
test('satu file 413 → lanjut file lain + error parsial', () async { ... });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/sync_photos_test.dart`
Expected: FAIL (`syncPhotos` belum ada)

- [ ] **Step 3: Implementasi `syncPhotos` + wiring `syncAll` + form hash**

Urutan di `syncAll`: `pushCatalog → push dokumen kronologis → pull katalog/dokumen → syncPhotos → load ulang`. `syncPhotos` baca semua produk lokal non-delete; file hilang + kedua hash kosong → skip. Simpan unduhan dengan nama `<hash>.jpg` (bukan uuid acak) agar idempoten. Purge: `deleteProduct` (soft) tidak hapus file; saat push delete 404/200 sukses → panggil `DELETE .../photo` (abaikan 404) — gabung di `pushCatalog` cabang delete.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test --concurrency 1` → PASS; `flutter analyze` → bersih; `npm test` di backend → PASS

- [ ] **Step 5: Commit**

```bash
git add pos_app/lib/features/products/products_provider.dart pos_app/lib/core/sync/sync_all_provider.dart pos_app/lib/features/products/product_form_screen.dart pos_app/test/sync_photos_test.dart
git commit -m "feat: fase foto otomatis di sinkron semua"
```
