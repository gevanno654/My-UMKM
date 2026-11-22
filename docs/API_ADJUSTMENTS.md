# API Opname (Penyesuaian Stok)

Basis: sama seperti produk/kasir/restock —
`Authorization: Bearer <accessToken>`, isolasi per `store_id` dari JWT.
Stok INTEGER satuan.

## POST /api/v1/adjustments

Mencatat penyesuaian opname: set stok produk ke hasil hitung fisik dalam
1 transaksi DB (baris produk dikunci `FOR UPDATE`).

Request:

```json
{
  "id": "uuid-opsional-dari-HP",
  "productId": "uuid",
  "physicalStock": 14,
  "reason": "selip di gudang"
}
```

- `physicalStock` ≥ 0; harus beda dari stok kini (diff 0 → 400).
- `reason` wajib non-blank, maks 200 karakter.
- `productId` wajib merujuk produk toko sendiri yang belum dihapus.
- Server terapkan sebagai **diff relatif**: `after = stok_kini + diff`
  (bukan absolut dari client) agar dua HP opname bersamaan tidak saling
  timpa. `stockBefore/stockAfter` di respons dihitung dari nilai server.

Respons 201:

```json
{
  "id": "uuid",
  "productId": "uuid",
  "name": "Indomie Goreng",
  "stockBefore": 10,
  "stockAfter": 14,
  "diff": 4,
  "reason": "selip di gudang",
  "status": "ok",
  "voidReason": null,
  "createdAt": "...",
  "updatedAt": "...",
  "voidedAt": null
}
```

| Kode | Arti |
| ---- | ---- |
| 400 `validation` | body tidak valid (termasuk diff 0) |
| 401 `missing token` | tanpa/expired token |
| 404 `product not found` | productId milik toko lain / tidak ada / terhapus |

Idempotent: `POST` dengan `id` yang sudah ada → 201 berisi dokumen lama
tanpa mutasi stok ulang (aman untuk retry HP).

## POST /api/v1/adjustments/:id/void

Batalkan penyesuaian beraudit: `status` → `voided` + alasan wajib, stok
dikembalikan (`stock − diff`, tidak pernah minus).

Request: `{ "reason": "salah hitung" }`.

| Kode | Arti |
| ---- | ---- |
| 400 `reason required` | alasan kosong |
| 404 `not found` | adjustment tidak ada / beda toko |
| 409 `insufficient stock` | stok kini kurang untuk dikembalikan (tidak ada yang berubah) |
| 401 `missing token` | tanpa/expired token |

Sudah voided → 200 idempoten tanpa mutasi ulang. Produk sudah dihapus →
tetap void (status berubah), stok tak kembali.

## GET /api/v1/adjustments

List penyesuaian milik store (flat, tanpa items nested), `created_at`
terbaru dulu. 401 tanpa token.
