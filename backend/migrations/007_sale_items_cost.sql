ALTER TABLE sale_items ADD COLUMN IF NOT EXISTS cost_price integer NOT NULL DEFAULT 0 CHECK (cost_price >= 0);
