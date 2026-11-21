CREATE TABLE IF NOT EXISTS sales (
  id uuid PRIMARY KEY,
  store_id uuid NOT NULL REFERENCES stores(id),
  number text NOT NULL,
  total integer NOT NULL CHECK (total >= 0),
  paid integer NOT NULL CHECK (paid >= 0),
  change integer NOT NULL DEFAULT 0,
  method text NOT NULL CHECK (method IN ('tunai', 'qris', 'transfer')),
  status text NOT NULL DEFAULT 'ok' CHECK (status IN ('ok', 'voided')),
  void_reason text NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  voided_at timestamptz NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_sales_store_number ON sales(store_id, number);

CREATE TABLE IF NOT EXISTS sale_items (
  id uuid PRIMARY KEY,
  sale_id uuid NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  product_id uuid NULL,
  name text NOT NULL,
  price integer NOT NULL CHECK (price >= 0),
  qty integer NOT NULL CHECK (qty > 0),
  subtotal integer NOT NULL CHECK (subtotal >= 0)
);
CREATE INDEX IF NOT EXISTS ix_sale_items_sale ON sale_items(sale_id);
