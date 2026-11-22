# API Kasir (Sales)

Basis: sama seperti produk — `Authorization: Bearer <accessToken>`,
isolasi per `store_id` dari JWT. Uang INTEGER rupiah.

## POST /api/v1/sales

Membuat transaksi + mengurangi stok atomik (transaksi DB, baris produk
dikunci `FOR UPDATE`).

Request:

```json
{
  "id": "uuid-opsional-dari-HP",
  "number": "TE211120260001",
  "items": [{ "productId": "uuid", "qty": 2 }],
  "paid": 10000,
  "method": "tunai"
}
```

- `method`: `tunai` | `qris` | `transfer`.
- `items[].productId` wajib merujuk produk toko sendiri yang belum dihapus.
- Item tanpa `productId` (koreksi manual v1 — jarang dipakai): wajib sertakan
  `name` + `price`.
- Harga diambil dari `sell_price` server saat transaksi (snapshot tersimpan
  di `sale_items`), bukan dari client.
- `tunai`: `paid >= total`, respons berisi `change = paid - total`.
- `qris`/`transfer`: hanya dicatat.

Respons 201:

```json
{
  "id": "uuid",
  "number": "TE211120260001",
  "total": 7000,
  "paid": 10000,
  "change": 3000,
  "method": "tunai",
  "status": "ok",
  "voidReason": null,
  "createdAt": "2026-11-22T...",
  "items": [
    { "id": "uuid", "productId": "uuid", "name": "Indomie", "price": 3500, "qty": 2, "subtotal": 7000 }
  ]
}
```

Error:

| Kode | Arti |
| ---- | ---- |
| 400 `validation` | body tidak valid (qty ≤ 0, items kosong, dsb) |
| 400 `paid less than total` | tunai kurang bayar |
| 401 `missing token` | tanpa/expired token |
| 404 `product not found` | productId milik toko lain / tidak ada / terhapus |
| 409 `insufficient stock` | stok kurang (tidak ada yang berubah) |
| 409 `number taken` | nomor struk sudah dipakai di toko ini |

Idempotent: `POST` dengan `id` yang sudah ada → 201 berisi dokumen lama
tanpa mutasi stok ulang (aman untuk retry HP).

## POST /api/v1/sales/:id/void

Batalkan transaksi beraudit: `status` → `voided` + alasan wajib, stok
dikembalikan (`+qty`, tidak pernah 409).

Request: `{ "reason": "salah input" }`.

| Kode | Arti |
| ---- | ---- |
| 400 `reason required` | alasan kosong |
| 404 `not found` | sale tidak ada / beda toko (termasuk belum pernah tersinkron) |
| 401 `missing token` | tanpa/expired token |

Sudah voided → 200 idempoten tanpa mutasi ulang.

## GET /api/v1/sales

Daftar transaksi toko sendiri + items nested, terbaru dulu. Format item
sama seperti respons POST.
