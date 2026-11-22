import { Router } from "express";
import { z } from "zod";
import { getPool } from "../db";
import { verifyAccessToken } from "../auth/tokens";

export const productsRouter = Router();

const idSchema = z.string().uuid();

const productSchema = z.object({
  id: z.string().uuid().optional(),
  name: z.string().min(1).max(100),
  barcode: z.string().max(50).optional().nullable(),
  costPrice: z.number().int().min(0).max(999999999).default(0),
  sellPrice: z.number().int().min(0).max(999999999).default(0),
  stock: z.number().int().min(0).max(999999999).default(0),
  category: z.string().max(50).default(""),
});

const productPatchSchema = productSchema.partial().extend({
  name: z.string().min(1).max(100).optional(),
});

type Authed = { userId: string; storeId: string };

function auth(req: { headers: Record<string, unknown> }): Authed | null {
  const header = req.headers.authorization;
  if (typeof header !== "string" || !header.startsWith("Bearer ")) return null;
  try {
    return verifyAccessToken(header.slice("Bearer ".length));
  } catch {
    return null;
  }
}

function toJson(row: Record<string, unknown>) {
  return {
    id: row.id,
    name: row.name,
    barcode: row.barcode,
    costPrice: row.cost_price,
    sellPrice: row.sell_price,
    stock: row.stock,
    category: row.category,
    photoPath: row.photo_path,
    updatedAt: row.updated_at,
    deletedAt: row.deleted_at,
  };
}

function normalizeBarcode(raw: unknown): string | null {
  if (typeof raw !== "string") return null;
  const trimmed = raw.trim();
  return trimmed === "" ? null : trimmed;
}

productsRouter.use((req, res, next) => {
  const authed = auth(req);
  if (!authed) {
    return res.status(401).json({ error: "missing token" });
  }
  (req as unknown as { auth: Authed }).auth = authed;
  next();
});

function storeIdOf(req: unknown): string {
  return (req as { auth: Authed }).auth.storeId;
}

productsRouter.get("/", async (req, res) => {
  const storeId = storeIdOf(req);
  const rows = await getPool().query(
    `SELECT id, name, barcode, cost_price, sell_price, stock, category,
            photo_path, updated_at, deleted_at
       FROM products
      WHERE store_id = $1 AND deleted_at IS NULL
      ORDER BY updated_at DESC`,
    [storeId],
  );
  return res.status(200).json(rows.rows.map(toJson));
});

productsRouter.post("/", async (req, res) => {
  const storeId = storeIdOf(req);
  const parsed = productSchema.safeParse(req.body);
  if (!parsed.success) {
    return res
      .status(400)
      .json({ error: "validation", details: parsed.error.flatten() });
  }
  const p = parsed.data;
  const barcode = normalizeBarcode(p.barcode);
  try {
    const rows = await getPool().query(
      `INSERT INTO products
         (id, store_id, name, barcode, cost_price, sell_price, stock, category)
       VALUES (COALESCE($1, gen_random_uuid()), $2, $3, $4, $5, $6, $7, $8)
       RETURNING id, name, barcode, cost_price, sell_price, stock, category,
                 photo_path, updated_at, deleted_at`,
      [p.id ?? null, storeId, p.name, barcode, p.costPrice, p.sellPrice, p.stock, p.category],
    );
    return res.status(201).json(toJson(rows.rows[0]));
  } catch (err) {
    if (
      typeof err === "object" &&
      err !== null &&
      "code" in err &&
      (err as { code: string }).code === "23505"
    ) {
      return res.status(409).json({ error: "barcode taken" });
    }
    throw err;
  }
});

productsRouter.put("/:id", async (req, res) => {
  const storeId = storeIdOf(req);
  const idParsed = idSchema.safeParse(req.params.id);
  const bodyParsed = productPatchSchema.safeParse(req.body);
  if (!idParsed.success || !bodyParsed.success) {
    return res.status(400).json({ error: "validation" });
  }
  const p = bodyParsed.data;
  const barcode =
    p.barcode === undefined ? undefined : normalizeBarcode(p.barcode);
  try {
    const rows = await getPool().query(
      // Stok SENGAJA tidak bisa diubah lewat PUT: stok server hanya berubah
      // via dokumen restock/sale (relatif, atomik). PUT sync yang membawa
      // stok absolut lokal (hasil mutasi lokal) akan menimpa stok server
      // yang sudah benar -> stok ganda. Field stock di body diabaikan.
      `UPDATE products SET
         name = COALESCE($3, name),
         barcode = CASE WHEN $8 THEN barcode ELSE $4::text END,
         cost_price = COALESCE($5, cost_price),
         sell_price = COALESCE($6, sell_price),
         category = COALESCE($7, category),
         updated_at = now()
       WHERE id = $1::uuid AND store_id = $2::uuid AND deleted_at IS NULL
       RETURNING id, name, barcode, cost_price, sell_price, stock, category,
                 photo_path, updated_at, deleted_at`,
      [
        idParsed.data,
        storeId,
        p.name ?? null,
        barcode ?? null,
        p.costPrice ?? null,
        p.sellPrice ?? null,
        p.category ?? null,
        p.barcode === undefined,
      ],
    );
    if (!rows.rowCount) {
      return res.status(404).json({ error: "not found" });
    }
    return res.status(200).json(toJson(rows.rows[0]));
  } catch (err) {
    if (
      typeof err === "object" &&
      err !== null &&
      "code" in err &&
      (err as { code: string }).code === "23505"
    ) {
      return res.status(409).json({ error: "barcode taken" });
    }
    throw err;
  }
});

productsRouter.delete("/:id", async (req, res) => {
  const storeId = storeIdOf(req);
  const idParsed = idSchema.safeParse(req.params.id);
  if (!idParsed.success) {
    return res.status(400).json({ error: "validation" });
  }
  const rows = await getPool().query(
    `UPDATE products SET deleted_at = now(), updated_at = now()
      WHERE id = $1 AND store_id = $2 AND deleted_at IS NULL
      RETURNING id`,
    [idParsed.data, storeId],
  );
  if (!rows.rowCount) {
    return res.status(404).json({ error: "not found" });
  }
  return res.status(200).json({ deleted: true });
});
