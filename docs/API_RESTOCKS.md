# API Restock (Penerimaan Kulakan)

Basis: sama seperti produk/kasir — `Authorization: Bearer <accessToken>`,
isolasi per `store_id` dari JWT. Uang INTEGER rupiah.

## POST /api/v1/restocks

Mencatat penerimaan + menambah stok + update harga katalog atomik
(transaksi DB, baris produk dikunci `FOR UPDATE`).

Request:

```json
{
  "id": "uuid-opsional-dari-HP",
  "items": [
    { "productId": "uuid", "qty": 5, "costPrice": 2600, "sellPrice": 3600 },
    { "productId": "uuid", "qty": 3, "costPrice": 2100 }
  ]
}
```

- `productId` wajib merujuk produk toko sendiri yang belum dihapus.
- `qty` ≥ 1; `costPrice`/`sellPrice` 0..999999999.
- `sellPrice` opsional: bila dikirim, harga jual katalog ikut diperbarui;
  bila tidak, harga jual katalog tetap.
- Harga beli katalog selalu diperbarui ke `costPrice` terbaru.
- Stok produk `+= qty`. `total` = Σ qty×costPrice.

Respons 201: `{ id, total, status: "ok", voidReason: null, createdAt, items: [{ id, productId, name, qty, costPrice, sellPrice, subtotal }] }` (`sellPrice` null bila tidak diubah).

Error:

| Kode | Arti |
| ---- | ---- |
| 400 `validation` | body tidak valid (qty ≤ 0, items kosong, dsb) |
| 401 `missing token` | tanpa/expired token |
| 404 `product not found` | productId milik toko lain / tidak ada / terhapus |

Idempotent: `POST` dengan `id` yang sudah ada → 201 berisi dokumen lama
tanpa mutasi stok ulang (aman untuk retry HP).

## POST /api/v1/restocks/:id/void

Membatalkan penerimaan beraudit: status → `voided` + alasan wajib, stok
dikurangi kembali. Ditolak bila stok kini kurang (sudah terlanjur terjual).

Request: `{ "reason": "salah input" }`

Error:

| Kode | Arti |
| ---- | ---- |
| 400 `reason required` | alasan kosong |
| 401 `missing token` | tanpa/expired token |
| 404 `not found` | id tidak ada / sudah void / toko lain |
| 409 `insufficient stock` | stok kini kurang dari qty restock (tidak ada yang berubah) |

## GET /api/v1/restocks

Daftar penerimaan toko sendiri + items nested, terbaru dulu.
