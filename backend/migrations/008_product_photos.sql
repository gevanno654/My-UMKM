ALTER TABLE products ADD COLUMN IF NOT EXISTS photo_hash text NOT NULL DEFAULT '';
ALTER TABLE products ADD COLUMN IF NOT EXISTS photo_size integer NOT NULL DEFAULT 0 CHECK (photo_size >= 0);
