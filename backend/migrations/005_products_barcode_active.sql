-- Barcode unik hanya di antara produk aktif per toko: barcode produk
-- yang sudah dihapus (deleted_at NOT NULL) boleh dipakai ulang.
DO $$
BEGIN
  -- 1. Bersihkan duplikat lama: baris terhapus yang barcode-nya dipakai
  -- ulang produk aktif dinull-kan (bukan DELETE, FK riwayat tetap utuh).
  -- Idempoten: aman dijalankan berulang (test/dev).
  UPDATE products p_old
  SET barcode = NULL
  FROM products p_new
  WHERE p_old.deleted_at IS NOT NULL
    AND p_new.deleted_at IS NULL
    AND p_old.store_id = p_new.store_id
    AND p_old.barcode IS NOT NULL
    AND p_old.barcode = p_new.barcode;

  -- 2. Hapus SEMUA varian index lama (nama lama non-parsial maupun
  -- parsial dari versi migrasi sebelumnya), lalu buat yang benar.
  -- Perlu karena file migrasi 002 membuat index non-parsial bila tabel
  -- dibuat fresh SETELAH migrasi ini ditulis — urutan apply di test:
  -- 002 -> 005, dan 002 selalu membuat index non-parsial bila belum ada.
  DROP INDEX IF EXISTS uq_products_store_barcode;
  DROP INDEX IF EXISTS uq_products_store_barcode_active;
  CREATE UNIQUE INDEX uq_products_store_barcode_active
    ON products(store_id, barcode)
    WHERE barcode IS NOT NULL AND deleted_at IS NULL;
END $$;
