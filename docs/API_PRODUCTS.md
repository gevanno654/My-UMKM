# API Produk

Basis: JWT access (`Authorization: Bearer <accessToken>`), isolasi `store_id`
dari token. Semua harga/stok integer (rupiah/satuan).

## GET /api/v1/products → 200

List produk milik store (tanpa soft-deleted), `updated_at` terbaru dulu.

```json
[
  {
    "id": "uuid",
    "name": "Indomie Goreng",
    "barcode": "899001",
    "costPrice": 2500,
    "sellPrice": 3500,
    "stock": 10,
    "category": "Makanan",
    "photoPath": "",
    "updatedAt": "2026-11-20T04:00:00.000Z",
    "deletedAt": null
  }
]
```

## POST /api/v1/products → 201

Body: `{name, barcode?, costPrice?, sellPrice?, stock?, category?, id?}`.
`id` = UUID dari client bila valid, else generate server. `barcode` kosong
dinormalisasi ke null. Barcode duplikat per store → `409 {error:'barcode taken'}`.
Validasi gagal → `400 {error:'validation'}`.

## PUT /api/v1/products/:id → 200

Partial update; beda store → `404 {error:'not found'}`; barcode duplikat → 409.
**Stok tidak bisa diubah lewat PUT** (field `stock` di body diabaikan):
stok server hanya berubah via dokumen restock/sale (relatif, atomik) agar
sinkron HP tidak menimpa stok dengan angka absolut lokal (stok ganda).

## DELETE /api/v1/products/:id → 200

Soft delete (`deleted_at=now()`); beda store → 404. Balikan `{deleted:true}`.
