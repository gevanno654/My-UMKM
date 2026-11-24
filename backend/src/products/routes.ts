import { Router } from "express";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import multer from "multer";
import { z } from "zod";
import { getPool } from "../db";
import { verifyAccessToken } from "../auth/tokens";

export const productsRouter = Router();

/// Direktori file foto per store: `<DATA_DIR>/<storeId>/<hash>.jpg`.
/// `PHOTO_DIR` menimpa default agar test terisolasi dari data dev.
function photoDir(): string {
  return (
    process.env.PHOTO_DIR ?? path.join(process.cwd(), ".data", "photos")
  );
}

function photoPathFor(storeId: string, hash: string): string {
  return path.join(photoDir(), storeId, `${hash}.jpg`);
}

/// Upload ≤2MB (memory), selebihnya 413 di handler error di bawah.
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 2 * 1024 * 1024 },
});

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
    photoHash: row.photo_hash ?? "",
    photoSize: row.photo_size ?? 0,
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

/// Baris aktif pemegang barcode (rekonsiliasi 409): null bila tak ada.
/// Dipakai client untuk adopsi ID server saat ID lokalnya asing.
async function findByBarcode(storeId: string, barcode: string | null) {
  if (barcode == null) return null;
  const rows = await getPool().query(
    `SELECT id, name, barcode, cost_price, sell_price, stock, category,
            photo_path, photo_hash, photo_size, updated_at, deleted_at
       FROM products
      WHERE store_id = $1::uuid AND barcode = $2 AND deleted_at IS NULL
      LIMIT 1`,
    [storeId, barcode],
  );
  if (!rows.rowCount) return null;
  return toJson(rows.rows[0]);
}

productsRouter.get("/", async (req, res) => {
  const storeId = storeIdOf(req);
  const rows = await getPool().query(
    `SELECT id, name, barcode, cost_price, sell_price, stock, category,
            photo_path, photo_hash, photo_size, updated_at, deleted_at
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
                 photo_path, photo_hash, photo_size, updated_at, deleted_at`,
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
      return res.status(409).json({
        error: "barcode taken",
        conflictWith: await findByBarcode(storeId, barcode ?? null),
      });
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
                 photo_path, photo_hash, photo_size, updated_at, deleted_at`,
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
      return res.status(409).json({
        error: "barcode taken",
        conflictWith: await findByBarcode(storeId, barcode ?? null),
      });
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

/// Manifest ringan sinkron foto: id + hash per produk (tanpa bytes).
/// Client bandingkan dengan hash lokal, transfer hanya yang beda.
productsRouter.get("/photo-manifest", async (req, res) => {
  const storeId = storeIdOf(req);
  const rows = await getPool().query(
    `SELECT id, photo_hash FROM products
      WHERE store_id = $1::uuid AND deleted_at IS NULL`,
    [storeId],
  );
  return res.status(200).json(
    rows.rows.map((r) => ({ id: r.id, photoHash: r.photo_hash ?? "" })),
  );
});

/// Unduh file foto milik store. Hash yang bukan milik store → 404
/// (isolasi antar toko, bukan 403 agar tidak membocorkan keberadaan).
productsRouter.get("/photos/:hash", async (req, res) => {
  const storeId = storeIdOf(req);
  const hash = req.params.hash;
  if (!/^[0-9a-f]{64}$/.test(hash)) {
    return res.status(400).json({ error: "validation" });
  }
  const owned = await getPool().query(
    `SELECT 1 FROM products
      WHERE store_id = $1::uuid AND photo_hash = $2 AND deleted_at IS NULL
      LIMIT 1`,
    [storeId, hash],
  );
  if ((owned.rowCount ?? 0) === 0) {
    return res.status(404).json({ error: "not found" });
  }
  const file = photoPathFor(storeId, hash);
  if (!fs.existsSync(file)) {
    return res.status(404).json({ error: "not found" });
  }
  res.setHeader("Content-Type", "image/jpeg");
  res.setHeader("Content-Length", String(fs.statSync(file).size));
  return res.status(200).send(fs.readFileSync(file));
});

/// Upload foto produk (multipart field `photo`, ≤2MB).
/// Simpan apa adanya dari HP; nama file = hash (idempoten, dedup alami).
productsRouter.post(
  "/:id/photo",
  (req, res, next) => {
    upload.single("photo")(req, res, (err) => {
      if (err != null && (err as { code?: string }).code === "LIMIT_FILE_SIZE") {
        return res.status(413).json({ error: "photo too large" });
      }
      if (err != null) {
        return res.status(400).json({ error: "validation" });
      }
      next();
    });
  },
  async (req, res) => {
    const storeId = storeIdOf(req);
    const idParsed = idSchema.safeParse(req.params.id);
    const file = (req as unknown as { file?: Express.Multer.File }).file;
    if (!idParsed.success || file == null || file.size === 0) {
      return res.status(400).json({ error: "validation" });
    }
    const found = await getPool().query(
      `SELECT id FROM products
        WHERE id = $1::uuid AND store_id = $2::uuid AND deleted_at IS NULL`,
      [idParsed.data, storeId],
    );
    if ((found.rowCount ?? 0) === 0) {
      return res.status(404).json({ error: "not found" });
    }
    const hash = crypto.createHash("sha256").update(file.buffer).digest("hex");
    const dest = photoPathFor(storeId, hash);
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.writeFileSync(dest, file.buffer);
    const rows = await getPool().query(
      `UPDATE products SET photo_hash = $3, photo_size = $4, updated_at = now()
        WHERE id = $1::uuid AND store_id = $2::uuid
        RETURNING id, name, barcode, cost_price, sell_price, stock, category,
                  photo_path, photo_hash, photo_size, updated_at, deleted_at`,
      [idParsed.data, storeId, hash, file.size],
    );
    return res.status(200).json(toJson(rows.rows[0]));
  },
);

/// Hapus file foto produk (dipakai purge; abaikan 404 di client).
/// Sengaja mencakup baris soft-deleted: alur purge memanggil endpoint ini
/// SETELAH `DELETE /:id`, sehingga kondisi `deleted_at IS NULL` akan selalu
/// gagal dan file yatim menumpuk bila dipakai.
productsRouter.delete("/:id/photo", async (req, res) => {
  const storeId = storeIdOf(req);
  const idParsed = idSchema.safeParse(req.params.id);
  if (!idParsed.success) {
    return res.status(400).json({ error: "validation" });
  }
  const rows = await getPool().query(
    `UPDATE products SET photo_hash = '', photo_size = 0, updated_at = now()
      WHERE id = $1::uuid AND store_id = $2::uuid
      RETURNING id, photo_hash`,
    [idParsed.data, storeId],
  );
  if (!rows.rowCount) {
    return res.status(404).json({ error: "not found" });
  }
  // File dihapus best-effort; DB tetap benar walau file sudah hilang.
  try {
    const dir = path.join(photoDir(), storeId);
    if (fs.existsSync(dir)) {
      for (const f of fs.readdirSync(dir)) {
        const still = await getPool().query(
          `SELECT 1 FROM products
            WHERE store_id = $1::uuid AND photo_hash = $2 AND deleted_at IS NULL
            LIMIT 1`,
          [storeId, path.basename(f, ".jpg")],
        );
        if ((still.rowCount ?? 0) === 0) {
          fs.unlinkSync(path.join(dir, f));
        }
      }
    }
  } catch {
    // Abaikan: kebersihan disk tidak boleh menggagalkan request.
  }
  return res.status(200).json({ deleted: true, photoHash: "" });
});
