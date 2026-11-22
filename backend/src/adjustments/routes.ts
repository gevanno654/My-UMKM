import { Router } from "express";
import { z } from "zod";
import { getPool } from "../db";
import { verifyAccessToken } from "../auth/tokens";

export const adjustmentsRouter = Router();

const adjustSchema = z.object({
  id: z.string().uuid().optional(),
  productId: z.string().uuid(),
  physicalStock: z.number().int().min(0).max(999999999),
  reason: z.string().trim().min(1).max(200),
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

adjustmentsRouter.use((req, res, next) => {
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

function toJson(a: Record<string, unknown>) {
  return {
    id: a.id,
    productId: a.product_id,
    name: a.name,
    stockBefore: a.stock_before,
    stockAfter: a.stock_after,
    diff: a.diff,
    reason: a.reason,
    status: a.status,
    voidReason: a.void_reason,
    createdAt: a.created_at,
    updatedAt: a.updated_at,
    voidedAt: a.voided_at,
  };
}

// Daftar penyesuaian milik store, terbaru dulu (flat, tanpa items nested).
adjustmentsRouter.get("/", async (req, res) => {
  const storeId = storeIdOf(req);
  const rows = await getPool().query(
    `SELECT id, product_id, name, stock_before, stock_after, diff,
            reason, status, void_reason, created_at, updated_at, voided_at
       FROM adjustments WHERE store_id = $1::uuid ORDER BY created_at DESC`,
    [storeId],
  );
  return res.status(200).json(rows.rows.map(toJson));
});

// Catat penyesuaian: insert adjustment + SET stok = fisik — semua dalam
// satu transaksi DB. Server terapkan diff relatif (after = stok_kini +
// diff) agar dua HP opname bersamaan tidak saling timpa.
adjustmentsRouter.post("/", async (req, res) => {
  const storeId = storeIdOf(req);
  const parsed = adjustSchema.safeParse(req.body);
  if (!parsed.success) {
    return res
      .status(400)
      .json({ error: "validation", details: parsed.error.flatten() });
  }
  const { id, productId, physicalStock, reason } = parsed.data;

  const client = await getPool().connect();
  try {
    // Idempotent: cek duplikat id DULU sebelum mutasi stok. Retry HP
    // (timeout lalu kirim ulang id sama) tidak boleh menambah stok 2x.
    if (id != null) {
      const existing = await client.query(
        `SELECT id, product_id, name, stock_before, stock_after, diff,
                reason, status, void_reason, created_at, updated_at, voided_at
           FROM adjustments WHERE id = $1::uuid AND store_id = $2::uuid`,
        [id, storeId],
      );
      if ((existing.rowCount ?? 0) > 0) {
        await client.query("ROLLBACK");
        return res.status(201).json(toJson(existing.rows[0]));
      }
    }
    await client.query("BEGIN");
    const prod = await client.query(
      `SELECT id, name, stock FROM products
        WHERE id = $1::uuid AND store_id = $2::uuid AND deleted_at IS NULL
        FOR UPDATE`,
      [productId, storeId],
    );
    if (prod.rowCount === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "product not found" });
    }
    const before = prod.rows[0].stock as number;
    const diff = physicalStock - before;
    if (diff === 0) {
      await client.query("ROLLBACK");
      return res
        .status(400)
        .json({ error: "no change", details: "Stok sama, tidak ada perubahan." });
    }
    const after = before + diff; // == physicalStock, >= 0 terjamin zod
    await client.query(
      "UPDATE products SET stock = $2, updated_at = now() WHERE id = $1::uuid",
      [productId, after],
    );
    const inserted = await client.query(
      `INSERT INTO adjustments
         (id, store_id, product_id, name, stock_before, stock_after, diff, reason)
       VALUES (COALESCE($1, gen_random_uuid()), $2::uuid, $3::uuid, $4, $5, $6, $7, $8)
       RETURNING id, product_id, name, stock_before, stock_after, diff,
                 reason, status, void_reason, created_at, updated_at, voided_at`,
      [id ?? null, storeId, productId, prod.rows[0].name, before, after, diff, reason],
    );
    await client.query("COMMIT");
    return res.status(201).json(toJson(inserted.rows[0]));
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
});

// Batalkan penyesuaian beraudit: status -> voided + alasan wajib,
// stok dikurangi kembali (-diff). Ditolak bila hasil kembali < 0.
adjustmentsRouter.post("/:id/void", async (req, res) => {
  const storeId = storeIdOf(req);
  const reasonRaw =
    typeof req.body?.reason === "string" ? req.body.reason.trim() : "";
  if (!reasonRaw) {
    return res.status(400).json({ error: "reason required" });
  }
  const client = await getPool().connect();
  try {
    await client.query("BEGIN");
    const found = await client.query(
      `SELECT id, product_id, diff, status FROM adjustments
        WHERE id = $1::uuid AND store_id = $2::uuid`,
      [req.params.id, storeId],
    );
    if (found.rowCount === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "not found" });
    }
    if (found.rows[0].status !== "ok") {
      // Sudah voided: idempoten tanpa mutasi ulang.
      const row = await client.query(
        `SELECT id, product_id, name, stock_before, stock_after, diff,
                reason, status, void_reason, created_at, updated_at, voided_at
           FROM adjustments WHERE id = $1::uuid`,
        [req.params.id],
      );
      await client.query("ROLLBACK");
      return res.status(200).json(toJson(row.rows[0]));
    }
    const productId = found.rows[0].product_id as string | null;
    const diff = found.rows[0].diff as number;
    if (productId != null) {
      const prod = await client.query(
        `SELECT id, stock FROM products WHERE id = $1::uuid FOR UPDATE`,
        [productId],
      );
      if ((prod.rowCount ?? 0) > 0) {
        const back = (prod.rows[0].stock as number) - diff;
        if (back < 0) {
          await client.query("ROLLBACK");
          return res.status(409).json({ error: "insufficient stock" });
        }
        await client.query(
          "UPDATE products SET stock = $2, updated_at = now() WHERE id = $1::uuid",
          [productId, back],
        );
      }
      // Produk dihapus: tetap void, stok tak kembali.
    }
    const updated = await client.query(
      `UPDATE adjustments SET status = 'voided', void_reason = $2,
         voided_at = now(), updated_at = now()
         WHERE id = $1::uuid
         RETURNING id, product_id, name, stock_before, stock_after, diff,
                   reason, status, void_reason, created_at, updated_at, voided_at`,
      [req.params.id, reasonRaw],
    );
    await client.query("COMMIT");
    return res.status(200).json(toJson(updated.rows[0]));
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
});
