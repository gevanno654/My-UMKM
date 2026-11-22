CREATE TABLE IF NOT EXISTS products (
  id uuid PRIMARY KEY,
  store_id uuid NOT NULL REFERENCES stores(id),
  name text NOT NULL,
  barcode text NULL,
  cost_price integer NOT NULL DEFAULT 0,
  sell_price integer NOT NULL DEFAULT 0,
  stock integer NOT NULL DEFAULT 0,
  category text NOT NULL DEFAULT '',
  photo_path text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_products_store_barcode_active ON products(store_id, barcode) WHERE barcode IS NOT NULL AND deleted_at IS NULL;
