-- Barcode unik hanya di antara produk aktif per toko: barcode produk
-- yang sudah dihapus (deleted_at NOT NULL) boleh dipakai ulang.
--
-- Perbaikan data lama: sebelum index parsial dibuat, baris terhapus yang
-- barcode-nya dipakai ulang oleh produk aktif dinull-kan barcode-nya
-- (bukan DELETE, agar riwayat sale/restock_items yang menunjuk product_id
-- tetap utuh).
UPDATE products p_old
SET barcode = NULL
FROM products p_new
WHERE p_old.deleted_at IS NOT NULL
  AND p_new.deleted_at IS NULL
  AND p_old.store_id = p_new.store_id
  AND p_old.barcode IS NOT NULL
  AND p_old.barcode = p_new.barcode;
DROP INDEX IF EXISTS uq_products_store_barcode;
CREATE UNIQUE INDEX IF NOT EXISTS uq_products_store_barcode_active
  ON products(store_id, barcode)
  WHERE barcode IS NOT NULL AND deleted_at IS NULL;
