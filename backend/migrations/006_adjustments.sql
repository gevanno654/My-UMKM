CREATE TABLE IF NOT EXISTS adjustments (
  id uuid PRIMARY KEY,
  store_id uuid NOT NULL REFERENCES stores(id),
  product_id uuid NULL,
  name text NOT NULL,
  stock_before integer NOT NULL CHECK (stock_before >= 0),
  stock_after integer NOT NULL CHECK (stock_after >= 0),
  diff integer NOT NULL CHECK (diff != 0),
  reason text NOT NULL,
  status text NOT NULL DEFAULT 'ok' CHECK (status IN ('ok', 'voided')),
  void_reason text NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  voided_at timestamptz NULL
);
CREATE INDEX IF NOT EXISTS ix_adjustments_store ON adjustments(store_id, created_at DESC);
