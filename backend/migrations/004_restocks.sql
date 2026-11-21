CREATE TABLE IF NOT EXISTS restocks (
  id uuid PRIMARY KEY,
  store_id uuid NOT NULL REFERENCES stores(id),
  total integer NOT NULL CHECK (total >= 0),
  status text NOT NULL DEFAULT 'ok' CHECK (status IN ('ok', 'voided')),
  void_reason text NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  voided_at timestamptz NULL
);

CREATE TABLE IF NOT EXISTS restock_items (
  id uuid PRIMARY KEY,
  restock_id uuid NOT NULL REFERENCES restocks(id) ON DELETE CASCADE,
  product_id uuid NULL,
  name text NOT NULL,
  qty integer NOT NULL CHECK (qty > 0),
  cost_price integer NOT NULL CHECK (cost_price >= 0),
  sell_price integer NULL CHECK (sell_price >= 0),
  subtotal integer NOT NULL CHECK (subtotal >= 0)
);
CREATE INDEX IF NOT EXISTS ix_restock_items_restock ON restock_items(restock_id);
