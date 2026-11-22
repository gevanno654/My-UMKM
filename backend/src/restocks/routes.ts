import { Router } from "express";
import { z } from "zod";
import { getPool } from "../db";
import { verifyAccessToken } from "../auth/tokens";

export const restocksRouter = Router();

const itemSchema = z.object({
  productId: z.string().uuid(),
  qty: z.number().int().min(1).max(999999),
  costPrice: z.number().int().min(0).max(999999999),
  sellPrice: z.number().int().min(0).max(999999999).optional(),
});

const restockSchema = z.object({
  id: z.string().uuid().optional(),
  items: itemSchema.array().min(1).max(100),
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

restocksRouter.use((req, res, next) => {
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

function toJson(restock: Record<string, unknown>, items: unknown[]) {
  return {
    id: restock.id,
    total: restock.total,
    status: restock.status,
    voidReason: restock.void_reason,
    createdAt: restock.created_at,
    updatedAt: restock.updated_at,
    voidedAt: restock.voided_at,
    items,
  };
}

// Daftar penerimaan milik store + items nested, terbaru dulu.
restocksRouter.get("/", async (req, res) => {
  const storeId = storeIdOf(req);
  const restocks = await getPool().query(
    `SELECT id, total, status, void_reason, created_at, updated_at, voided_at
       FROM restocks WHERE store_id = $1::uuid ORDER BY created_at DESC`,
    [storeId],
  );
  const out = [];
  for (const r of restocks.rows) {
    const items = await getPool().query(
      `SELECT id, product_id, name, qty, cost_price, sell_price, subtotal
         FROM restock_items WHERE restock_id = $1 ORDER BY name`,
      [r.id],
    );
    out.push(
      toJson(
        r,
        items.rows.map((i) => ({
          id: i.id,
          productId: i.product_id,
          name: i.name,
          qty: i.qty,
          costPrice: i.cost_price,
          sellPrice: i.sell_price,
          subtotal: i.subtotal,
        })),
      ),
    );
  }
  return res.status(200).json(out);
});

// Buat penerimaan: insert restock+items, stok += qty, update harga —
// semua dalam satu transaksi DB.
restocksRouter.post("/", async (req, res) => {
  const storeId = storeIdOf(req);
  const parsed = restockSchema.safeParse(req.body);
  if (!parsed.success) {
    return res
      .status(400)
      .json({ error: "validation", details: parsed.error.flatten() });
  }
  const { id, items } = parsed.data;

  const client = await getPool().connect();
  try {
    // Idempotent: cek duplikat id DULU sebelum mutasi stok. Retry HP
    // (timeout lalu kirim ulang id sama) tidak boleh menambah stok 2x.
    if (id != null) {
      const existing = await client.query(
        `SELECT id, total, status, void_reason, created_at, updated_at, voided_at
           FROM restocks WHERE id = $1::uuid AND store_id = $2::uuid`,
        [id, storeId],
      );
      if ((existing.rowCount ?? 0) > 0) {
        const prev = existing.rows[0];
        const prevItems = await client.query(
          `SELECT id, product_id, name, qty, cost_price, sell_price, subtotal
             FROM restock_items WHERE restock_id = $1 ORDER BY name`,
          [prev.id],
        );
        await client.query("ROLLBACK");
        return res.status(201).json(
          toJson(
            prev,
            prevItems.rows.map((i) => ({
              id: i.id,
              productId: i.product_id,
              name: i.name,
              qty: i.qty,
              costPrice: i.cost_price,
              sellPrice: i.sell_price,
              subtotal: i.subtotal,
            })),
          ),
        );
      }
    }
    await client.query("BEGIN");
    const lines: {
      productId: string;
      name: string;
      qty: number;
      costPrice: number;
      sellPrice: number | null;
    }[] = [];
    for (const item of items) {
      const prod = await client.query(
        `SELECT id, name FROM products
          WHERE id = $1::uuid AND store_id = $2::uuid AND deleted_at IS NULL
          FOR UPDATE`,
        [item.productId, storeId],
      );
      if (prod.rowCount === 0) {
        await client.query("ROLLBACK");
        return res.status(404).json({ error: "product not found" });
      }
      lines.push({
        productId: item.productId,
        name: prod.rows[0].name as string,
        qty: item.qty,
        costPrice: item.costPrice,
        sellPrice: item.sellPrice ?? null,
      });
      await client.query(
        `UPDATE products SET stock = stock + $2, cost_price = $3,
           sell_price = COALESCE($4, sell_price), updated_at = now()
         WHERE id = $1::uuid`,
        [item.productId, item.qty, item.costPrice, item.sellPrice ?? null],
      );
    }
    const total = lines.reduce((sum, l) => sum + l.costPrice * l.qty, 0);
    const restockRows = await client.query(
      `INSERT INTO restocks (id, store_id, total)
        VALUES (COALESCE($1, gen_random_uuid()), $2::uuid, $3)
        RETURNING id, total, status, void_reason, created_at, updated_at, voided_at`,
      [id ?? null, storeId, total],
    );
    const restock = restockRows.rows[0];
    const outItems = [];
    for (const l of lines) {
      const itemRows = await client.query(
        `INSERT INTO restock_items
           (id, restock_id, product_id, name, qty, cost_price, sell_price, subtotal)
          VALUES (gen_random_uuid(), $1, $2::uuid, $3, $4, $5, $6::int, $7)
          RETURNING id, product_id, name, qty, cost_price, sell_price, subtotal`,
        [
          restock.id,
          l.productId,
          l.name,
          l.qty,
          l.costPrice,
          l.sellPrice,
          l.costPrice * l.qty,
        ],
      );
      const r = itemRows.rows[0];
      outItems.push({
        id: r.id,
        productId: r.product_id,
        name: r.name,
        qty: r.qty,
        costPrice: r.cost_price,
        sellPrice: r.sell_price,
        subtotal: r.subtotal,
      });
    }
    await client.query("COMMIT");
    return res.status(201).json(toJson(restock, outItems));
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
});

// Batalkan penerimaan beraudit: status -> voided + alasan wajib,
// stok dikurangi kembali. Ditolak bila stok kini kurang (sudah terjual).
restocksRouter.post("/:id/void", async (req, res) => {
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
      `SELECT id, status FROM restocks
        WHERE id = $1::uuid AND store_id = $2::uuid`,
      [req.params.id, storeId],
    );
    if (found.rowCount === 0 || found.rows[0].status !== "ok") {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "not found" });
    }
    const items = await client.query(
      `SELECT product_id, qty FROM restock_items WHERE restock_id = $1`,
      [req.params.id],
    );
    for (const item of items.rows) {
      if (item.product_id == null) continue;
      const prod = await client.query(
        `SELECT id, stock FROM products WHERE id = $1::uuid FOR UPDATE`,
        [item.product_id],
      );
      if (prod.rowCount === 0) continue; // produk dihapus: stok tak kembali
      if ((prod.rows[0].stock as number) < (item.qty as number)) {
        await client.query("ROLLBACK");
        return res.status(409).json({ error: "insufficient stock" });
      }
      await client.query(
        "UPDATE products SET stock = stock - $2, updated_at = now() WHERE id = $1::uuid",
        [item.product_id, item.qty],
      );
    }
    const updated = await client.query(
      `UPDATE restocks SET status = 'voided', void_reason = $2,
         voided_at = now(), updated_at = now()
         WHERE id = $1::uuid
         RETURNING id, total, status, void_reason, created_at, updated_at, voided_at`,
      [req.params.id, reasonRaw],
    );
    await client.query("COMMIT");
    return res.status(200).json(toJson(updated.rows[0], []));
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
});
