import { Router } from "express";
import { z } from "zod";
import { getPool } from "../db";
import { verifyAccessToken } from "../auth/tokens";

export const salesRouter = Router();

const itemSchema = z.object({
  productId: z.string().uuid().optional().nullable(),
  name: z.string().min(1).max(100).optional(),
  price: z.number().int().min(0).max(999999999).optional(),
  qty: z.number().int().min(1).max(9999),
});

const saleSchema = z.object({
  id: z.string().uuid().optional(),
  number: z.string().min(1).max(30),
  items: itemSchema.array().min(1).max(100),
  paid: z.number().int().min(0).max(999999999),
  method: z.enum(["tunai", "qris", "transfer"]),
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

salesRouter.use((req, res, next) => {
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

function toJson(sale: Record<string, unknown>, items: unknown[]) {
  return {
    id: sale.id,
    number: sale.number,
    total: sale.total,
    paid: sale.paid,
    change: sale.change,
    method: sale.method,
    status: sale.status,
    voidReason: sale.void_reason,
    createdAt: sale.created_at,
    updatedAt: sale.updated_at,
    voidedAt: sale.voided_at,
    items,
  };
}

// Daftar transaksi milik store + items nested, terbaru dulu.
salesRouter.get("/", async (req, res) => {
  const storeId = storeIdOf(req);
  const sales = await getPool().query(
    `SELECT id, number, total, paid, change, method, status, void_reason,
            created_at, updated_at, voided_at
       FROM sales WHERE store_id = $1::uuid ORDER BY created_at DESC`,
    [storeId],
  );
  const out = [];
  for (const s of sales.rows) {
    const items = await getPool().query(
      `SELECT id, product_id, name, price, qty, subtotal
         FROM sale_items WHERE sale_id = $1 ORDER BY name`,
      [s.id],
    );
    out.push(
      toJson(
        s,
        items.rows.map((r) => ({
          id: r.id,
          productId: r.product_id,
          name: r.name,
          price: r.price,
          qty: r.qty,
          subtotal: r.subtotal,
        })),
      ),
    );
  }
  return res.status(200).json(out);
});

// Buat transaksi: validasi stok (FOR UPDATE), insert sale+items,
// decrement stok — semua dalam satu transaksi DB.
salesRouter.post("/", async (req, res) => {
  const storeId = storeIdOf(req);
  const parsed = saleSchema.safeParse(req.body);
  if (!parsed.success) {
    return res
      .status(400)
      .json({ error: "validation", details: parsed.error.flatten() });
  }
  const { id, number, items, paid, method } = parsed.data;
  if (method === "tunai" && items.length === 0) {
    return res.status(400).json({ error: "validation" });
  }

  const client = await getPool().connect();
  try {
    await client.query("BEGIN");
    // Kunci baris produk agar 2 kasir bersamaan tidak menjual stok yang sama.
    const lines: {
      productId: string | null;
      name: string;
      price: number;
      qty: number;
    }[] = [];
    for (const item of items) {
      if (item.productId != null) {
        const prod = await client.query(
          `SELECT id, name, sell_price, stock FROM products
            WHERE id = $1::uuid AND store_id = $2::uuid AND deleted_at IS NULL
            FOR UPDATE`,
          [item.productId, storeId],
        );
        if (prod.rowCount === 0) {
          await client.query("ROLLBACK");
          return res.status(404).json({ error: "product not found" });
        }
        const row = prod.rows[0];
        if (row.stock < item.qty) {
          await client.query("ROLLBACK");
          return res.status(409).json({ error: "insufficient stock" });
        }
        lines.push({
          productId: row.id,
          name: row.name,
          price: row.sell_price,
          qty: item.qty,
        });
        await client.query(
          "UPDATE products SET stock = stock - $2, updated_at = now() WHERE id = $1::uuid",
          [item.productId, item.qty],
        );
      } else {
        // Item tanpa productId: snapshot manual dari client (v1: jarang dipakai).
        if (item.name == null || item.price == null) {
          await client.query("ROLLBACK");
          return res.status(400).json({ error: "validation" });
        }
        lines.push({
          productId: null,
          name: item.name,
          price: item.price,
          qty: item.qty,
        });
      }
    }
    const total = lines.reduce((sum, l) => sum + l.price * l.qty, 0);
    if (method === "tunai" && paid < total) {
      await client.query("ROLLBACK");
      return res.status(400).json({ error: "paid less than total" });
    }
    const change = paid - total;
    const saleRows = await client.query(
      `INSERT INTO sales (id, store_id, number, total, paid, change, method)
        VALUES (COALESCE($1, gen_random_uuid()), $2::uuid, $3, $4, $5, $6, $7)
        RETURNING id, number, total, paid, change, method, status,
                  void_reason, created_at, updated_at, voided_at`,
      [id ?? null, storeId, number, total, paid, change, method],
    );
    const sale = saleRows.rows[0];
    const outItems = [];
    for (const l of lines) {
      const itemRows = await client.query(
        `INSERT INTO sale_items (id, sale_id, product_id, name, price, qty, subtotal)
          VALUES (gen_random_uuid(), $1, $2::uuid, $3, $4, $5, $6)
          RETURNING id, product_id, name, price, qty, subtotal`,
        [sale.id, l.productId, l.name, l.price, l.qty, l.price * l.qty],
      );
      const r = itemRows.rows[0];
      outItems.push({
        id: r.id,
        productId: r.product_id,
        name: r.name,
        price: r.price,
        qty: r.qty,
        subtotal: r.subtotal,
      });
    }
    await client.query("COMMIT");
    return res.status(201).json(toJson(sale, outItems));
  } catch (err) {
    await client.query("ROLLBACK");
    if (
      typeof err === "object" &&
      err !== null &&
      "code" in err &&
      (err as { code: string }).code === "23505"
    ) {
      return res.status(409).json({ error: "number taken" });
    }
    throw err;
  } finally {
    client.release();
  }
});
