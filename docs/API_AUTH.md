# Kontrak API Auth — POS Warung v1

Base URL: `http://localhost:3000` (dev), emulator Android: `http://10.0.2.2:3000`.
Semua response JSON. Isolasi data: setiap token membawa `storeId`.

## POST /api/v1/auth/register

Body: `{ storeName, ownerName, email, password }` (password ≥ 8 char).

- `201`: `{ user: { id, storeId, name, email }, store: { id, name }, accessToken, refreshToken }`
- `400`: `{ error: "validation", details }` — field kosong, email invalid, password < 8
- `409`: `{ error: "email taken" }`

## POST /api/v1/auth/login

Body: `{ email, password }`.

- `200`: sama seperti register
- `400`: validasi gagal
- `401`: `{ error: "wrong credentials" }`

## POST /api/v1/auth/refresh

Body: `{ refreshToken }`. Refresh diputar (rotation): token lama langsung revoked.

- `200`: `{ accessToken, refreshToken }` (refresh baru)
- `401`: `{ error: "invalid refresh token" }` — termasuk reuse: memakai token lama yang sudah diputar akan me-revoke SEMUA refresh token user tersebut (reuse detection).

## GET /api/v1/me

Header: `Authorization: Bearer <accessToken>`.

- `200`: `{ user: { id, storeId, name, email }, store }`
- `401`: `{ error: "missing token" | "invalid token" }`

## Token

- Access JWT: `exp` 15 menit (`ACCESS_TTL`), payload `{ userId, storeId }`.
- Refresh JWT: `exp` 30 hari (`REFRESH_TTL_DAYS`), payload `{ userId, jti }`, hash SHA-256 disimpan di `refresh_tokens`.
- Secret dev lihat `backend/.env.example`. JANGAN deploy dengan secret placeholder (server menolak start bila `JWT_*_SECRET` masih placeholder di `NODE_ENV=production`).
