# Fondasi + Autentikasi POS Warung Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Membangun fondasi monorepo (Flutter app + backend REST + Postgres) dan fitur autentikasi dua lapis (online JWT + offline PIN) yang siap diuji.

**Architecture:** Flutter offline-first (Drift/SQLite lokal, token di secure storage) ↔ HTTPS REST (Express) ↔ PostgreSQL dengan isolasi `store_id`. Auth online sekali, lalu PIN lokal untuk buka offline.

**Tech Stack:** Flutter 3.38+ / Dart 3.10, Riverpod, GoRouter, Drift + sqlite3_flutter_libs, Dio; Backend Node 20+ TypeScript Express + pg + bcryptjs + jsonwebtoken + zod; Postgres 18; vitest + supertest; flutter_test.

**Spec:** `docs/superpowers/specs/2026-11-19-pos-warung-design.md`

## Global Constraints

- Android only v1, Flutter.
- Offline-first: semua fitur utama tanpa internet setelah login pertama.
- Local DB: SQLite (Drift).
- Cloud: REST API + PostgreSQL milik penjual, isolasi via `store_id`.
- 1 user per toko (1 HP = 1 akun pemilik, PIN milik pemilik).
- Lisensi v1: fondasi saja (kolom siap, tanpa enforcement expired).
- Restore aman: auto-backup lokal + konfirmasi (berlaku di plan backup nanti, bukan plan ini).
- Harga snapshot per transaksi, stok tidak boleh minus (berlaku di plan kasir nanti).
- Anti-goal: tidak ada koneksi langsung HP → PostgreSQL.

## Review Focus

- Email duplikat saat registrasi harus ditolak 409 dengan pesan jelas, bukan 500.
- Password lemah (<8 char) ditolak di client dan server.
- Token access kadaluarsa saat offline: app tetap buka via PIN, tidak logout paksa.
- PIN brute-force: setelah 5x salah, kunci 60 detik.
- Refresh token yang sudah dipakai/dicuri tidak bisa dipakai ulang (reuse detection → revoke semua).

---

## File Structure

Baru (relatif ke `D:\Github\pos-warung\`):

- `pos_app/` — proyek Flutter (`lib/main.dart`, `lib/core/`, `lib/features/auth/`)
- `pos_app/lib/core/router.dart` — GoRouter: splash/login/register/pin/home
- `pos_app/lib/core/db/app_db.dart` — Drift DB lokal (tabel auth cache)
- `pos_app/lib/features/auth/auth_api.dart` — Dio client ke backend
- `pos_app/lib/features/auth/auth_state.dart` + `auth_provider.dart` — Riverpod AuthNotifier
- `pos_app/lib/features/auth/*.dart` — screens: splash, login, register, pin_setup, pin_unlock, home_placeholder
- `backend/` — Express TS (`src/index.ts`, `src/db.ts`, `src/auth/*.ts`, `migrations/001_init.sql`)
- `backend/.env.example` — DATABASE_URL, JWT_ACCESS_SECRET, JWT_REFRESH_SECRET
- `docs/API_AUTH.md` — kontrak endpoint auth (ditulis di Task 2)

## Task 1: Scaffold monorepo + toolchain

**Files:**
- Create: `pos_app/` (hasil `flutter create`), `backend/package.json`, `backend/tsconfig.json`, `backend/.env.example`
- Test: `backend/__tests__/health.test.ts`, toolchain check script

**Interfaces:**
- Consumes: tidak ada
- Produces: `GET /health → { ok: true }`; Flutter `flutter analyze` lolos; `DATABASE_URL` terdokumentasi

- [ ] **Step 1: Verifikasi toolchain** — jalankan `flutter --version` (ditemukan: Flutter 3.38.6 di `C:\Users\Gevanno\dev\flutter`, Dart 3.10.7), `node --version` (v24.17.0), dan Postgres (service `postgresql-x64-18` Running). Tambahkan Flutter ke PATH bila belum ada. Toolchain dinyatakan OK bila ketiga versi tercatat.
- [ ] **Step 2: Scaffold Flutter** — Run: `flutter create --org com.warungpos --project-name pos_app pos_app`. Expected: direktori `pos_app/` ada, `flutter analyze` PASS.
- [ ] **Step 3: Scaffold backend** — `npm init -y` di `backend/`, install `express pg bcryptjs jsonwebtoken zod dotenv`, dev: `typescript tsx vitest supertest @types/*`. Tulis `GET /health`.
- [ ] **Step 4: Tulis `.env.example`** dengan `DATABASE_URL=postgres://pos:pos@localhost:5432/pos_dev`, `JWT_ACCESS_SECRET=change-me-32char`, `JWT_REFRESH_SECRET=change-me-32char`, `ACCESS_TTL=15m`, `REFRESH_TTL_DAYS=30`.
- [ ] **Step 5: Commit** — Run: `git add pos_app backend docs; git commit -m "chore: scaffold pos_app and backend"`

## Task 2: Backend auth (register/login/refresh/me)

**Files:**
- Create: `backend/migrations/001_init.sql`, `backend/src/db.ts`, `backend/src/auth/password.ts`, `backend/src/auth/tokens.ts`, `backend/src/auth/routes.ts`, `backend/src/index.ts`
- Modify: `backend/package.json` (scripts `dev`, `test`, `migrate`)
- Test: `backend/__tests__/auth.test.ts`

**Interfaces:**
- Consumes: Postgres 18, `DATABASE_URL`
- Produces:
  - `POST /api/v1/auth/register {storeName, ownerName, email, password} → 201 {user{id,storeId,name,email}, store{id,name}, accessToken, refreshToken}`
  - `POST /api/v1/auth/login {email,password} → 200 {…sama…}`
  - `POST /api/v1/auth/refresh {refreshToken} → 200 {accessToken, refreshToken}`
  - `GET /api/v1/me (Bearer) → 200 {user, store}`
  - Error: `400 validation`, `401 wrong credentials`, `409 email taken`

- [ ] **Step 1: Tulis failing test** `backend/__tests__/auth.test.ts`: register 201 + mengembalikan `storeId`; register email sama → 409; login salah password → 401; refresh memutar token (token lama → 401); `GET /me` tanpa token → 401.
- [ ] **Step 2: Run test, pastikan FAIL** — Run: `npm test --prefix backend`. Expected: FAIL (routes belum ada).
- [ ] **Step 3: Implement migrasi `001_init.sql`** — tabel `stores(id uuid pk default gen_random_uuid(), name text not null, created_at timestamptz default now())`, `users(id uuid pk, store_id uuid refs stores, name text, email citext unique, password_hash text, license_status text default 'trial', license_expires_at timestamptz null, created_at …)`, `refresh_tokens(id uuid pk, user_id refs users, token_hash text, expires_at timestamptz, revoked_at null, created_at …)`.
- [ ] **Step 4: Implement `password.ts` (bcryptjs hash/compare, min 8 char), `tokens.ts` (sign access 15m + refresh 30d, sha256 hash refresh sebelum simpan), `routes.ts` + `index.ts`** dengan validasi zod. Refresh reuse → revoke semua token user itu + 401.
- [ ] **Step 5: Run test, pastikan PASS** — Run: `npm test --prefix backend`. Expected: PASS. Tulis `docs/API_AUTH.md` dari Interfaces di atas.
- [ ] **Step 6: Commit** — `git add backend docs/API_AUTH.md; git commit -m "feat: backend auth register login refresh me"`

## Task 3: Flutter fondasi (router + DB lokal + secure session)

**Files:**
- Create: `pos_app/lib/core/router.dart`, `pos_app/lib/core/db/app_db.dart`, `pos_app/lib/core/session/secure_session.dart`, `pos_app/pubspec.yaml` (tambah dep)
- Test: `pos_app/test/foundation_test.dart`

**Interfaces:**
- Consumes: tidak ada (fondasi)
- Produces:
  - `AppDb` Drift dengan `local_stores(serverId TEXT PK, name TEXT)`, `local_users(serverId TEXT PK, storeId TEXT, name TEXT, email TEXT)`
  - `SecureSession.readTokens() → ({accessToken?, refreshToken?, pinHash?, profileJson?})`, `saveTokens()`, `savePinHash(pin: String)`, `clear()`
  - Routes: `/splash, /login, /register, /pin-setup, /pin-unlock, /home`

- [ ] **Step 1: Tulis failing test** `test/foundation_test.dart`: `AppDb` bisa insert+read store/user; `SecureSession` mock bisa save/read; router memetakan 6 route di atas.
- [ ] **Step 2: Run, pastikan FAIL** — Run: `flutter test pos_app/test/foundation_test.dart`. Expected: FAIL.
- [ ] **Step 3: Tambah dependensi** `flutter_riverpod, go_router, drift, sqlite3_flutter_libs, dio, flutter_secure_storage, connectivity_plus` lalu `flutter pub get`.
- [ ] **Step 4: Implement `app_db.dart`, `secure_session.dart`, `router.dart`** (PIN hash: SHA-256 + salt per-device dari secure storage; jangan simpan PIN plaintext).
- [ ] **Step 5: Run, pastikan PASS** — Run: `flutter test pos_app/test/foundation_test.dart && flutter analyze`. Expected: PASS.
- [ ] **Step 6: Commit** — `git add pos_app; git commit -m "feat: flutter foundation router db session"`

## Task 4: Flutter auth online (register/login + token)

**Files:**
- Create: `pos_app/lib/features/auth/auth_api.dart`, `auth_provider.dart`, `auth_state.dart`, `login_screen.dart`, `register_screen.dart`, `splash_screen.dart`, `home_placeholder.dart`
- Test: `pos_app/test/auth_online_test.dart` (mock Dio)

**Interfaces:**
- Consumes: `SecureSession`, `AppDb`, kontrak `docs/API_AUTH.md`
- Produces:
  - `AuthApi.register(storeName, ownerName, email, password) → AuthResult`, `login(email,password)`, `fetchMe()`, `refresh()`
  - `AuthNotifier : StateNotifier<AuthState>` dengan `AuthState = initial | unauthenticated | pinSetupRequired(profile) | authenticated(profile)`
  - Syarat lolos: register/login sukses → token tersimpan + cache profile ke Drift + state `pinSetupRequired` (jika PIN belum ada) atau `authenticated`

- [ ] **Step 1: Tulis failing widget/api test** — mock Dio: login 200 → `saveTokens` dipanggil + state `pinSetupRequired`; login 401 → pesan error tampil; register 409 → pesan "email sudah terdaftar".
- [ ] **Step 2: Run, pastikan FAIL** — Run: `flutter test pos_app/test/auth_online_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement `auth_api.dart` (baseUrl dari `--dart-define API_URL`, default `http://10.0.2.2:3000`), `auth_provider.dart`, 4 screen + validasi (email format, password ≥8, konfirmasi sama)**.
- [ ] **Step 4: Run manual + test** — Run: `flutter test pos_app/test/auth_online_test.dart`. Lalu dengan backend menyala (`npm run dev --prefix backend`): register akun baru dari emulator → 201 terlihat di DB. Expected: PASS + 1 akun di `users`.
- [ ] **Step 5: Commit** — `git add pos_app; git commit -m "feat: flutter online auth register login"`

## Task 5: Flutter PIN offline (set/unlock + gate)

**Files:**
- Create: `pos_app/lib/features/auth/pin_setup_screen.dart`, `pin_unlock_screen.dart`, `pin_guard.dart`
- Modify: `pos_app/lib/core/router.dart`, `auth_provider.dart`
- Test: `pos_app/test/pin_offline_test.dart`

**Interfaces:**
- Consumes: `SecureSession`, `AuthNotifier` dari Task 4
- Produces:
  - `PinGuard.canUnlockOffline() → bool` (true jika `pinHash + profileJson + accessToken` ada)
  - `verifyPin(pin) → bool` dengan lockout: 5x salah → kunci 60 detik
  - Alur: `pinSetupRequired → set PIN 6-digit 2x → authenticated`; buka app ada sesi → `/pin-unlock`; tanpa internet + sesi ada → PIN tetap bisa buka

- [ ] **Step 1: Tulis failing test** — set PIN `123456` 2x sama → tersimpan hash (bukan plaintext); unlock benar → `authenticated`; 5x salah → `lockedUntil` ~60s; `canUnlockOffline()` false saat storage kosong.
- [ ] **Step 2: Run, pastikan FAIL** — Run: `flutter test pos_app/test/pin_offline_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement PIN (input 6-digit, hash SHA-256+salt, counter salah + `lockedUntil` di secure storage), `PinGuard` di router (redirect ke `/pin-unlock` bila sesi ada tapi belum unlock)**.
- [ ] **Step 4: Run semua test Flutter, pastikan PASS** — Run: `flutter test pos_app && flutter analyze`. Expected: PASS. Uji manual: matikan internet emulator → tutup-buka app → PIN bisa buka + `/home` tampil.
- [ ] **Step 5: Commit** — `git add pos_app; git commit -m "feat: flutter offline pin unlock"`
