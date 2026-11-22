import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import request from "supertest";
import { app } from "../src/app";
import { closePool, getPool } from "../src/db";

process.env.DATABASE_URL ??=
  "postgres://pos:pos@localhost:5432/pos_test";
process.env.JWT_ACCESS_SECRET ??= "test-access-secret-0123456789abcdef";
process.env.JWT_REFRESH_SECRET ??= "test-refresh-secret-0123456789abcdef";

const stamp = Date.now();
const emailA = `adjust-a-${stamp}@warung.test`;
const emailB = `adjust-b-${stamp}@warung.test`;

let tokenA = "";
let tokenB = "";
let productIdA = "";

async function applyMigration(file: string) {
  const sql = fs.readFileSync(
    path.join(process.cwd(), "migrations", file),
    "utf8",
  );
  await getPool().query(sql);
}

beforeAll(async () => {
  await applyMigration("001_init.sql");
  await applyMigration("002_products.sql");
  await applyMigration("005_products_barcode_active.sql");
  await applyMigration("003_sales.sql");
  await applyMigration("004_restocks.sql");
  await applyMigration("006_adjustments.sql");
  await getPool().query(
    "TRUNCATE refresh_tokens, users, adjustments, restock_items, restocks, sale_items, sales, products, stores RESTART IDENTITY CASCADE",
  );

  const resA = await request(app).post("/api/v1/auth/register").send({
    storeName: "Toko A",
    ownerName: "Owner A",
    email: emailA,
    password: "password123",
  });
  tokenA = resA.body.accessToken as string;

  const resB = await request(app).post("/api/v1/auth/register").send({
    storeName: "Toko B",
    ownerName: "Owner B",
    email: emailB,
    password: "password123",
  });
  tokenB = resB.body.accessToken as string;

  const prod = await request(app)
    .post("/api/v1/products")
    .set("Authorization", `Bearer ${tokenA}`)
    .send({ name: "Indomie", costPrice: 2500, sellPrice: 3500, stock: 10 });
  productIdA = prod.body.id as string;
});

afterAll(async () => {
  await closePool();
});

describe("POST /api/v1/adjustments", () => {
  it("fisik naik 10 -> 14: 201, stok 14, diff +4", async () => {
    const res = await request(app)
      .post("/api/v1/adjustments")
      .set("Authorization", `Bearer ${tokenA}`)
      .send({ productId: productIdA, physicalStock: 14, reason: "selip" });
    expect(res.status).toBe(201);
    expect(res.body.diff).toBe(4);
    expect(res.body.stockBefore).toBe(10);
    expect(res.body.stockAfter).toBe(14);

    const prod = await getPool().query(
      "SELECT stock FROM products WHERE id = $1",
      [productIdA],
    );
    expect(prod.rows[0].stock).toBe(14);
  });

  it("fisik turun 14 -> 11: stok 11, diff -3", async () => {
    const res = await request(app)
      .post("/api/v1/adjustments")
      .set("Authorization", `Bearer ${tokenA}`)
      .send({ productId: productIdA, physicalStock: 11, reason: "rusak" });
    expect(res.status).toBe(201);
    expect(res.body.diff).toBe(-3);

    const prod = await getPool().query(
      "SELECT stock FROM products WHERE id = $1",
      [productIdA],
    );
    expect(prod.rows[0].stock).toBe(11);
  });

  it("fisik sama dengan stok (diff 0) -> 400", async () => {
    const res = await request(app)
      .post("/api/v1/adjustments")
      .set("Authorization", `Bearer ${tokenA}`)
      .send({ productId: productIdA, physicalStock: 11, reason: "cek" });
    expect(res.status).toBe(400);
  });

  it("reason kosong -> 400", async () => {
    const res = await request(app)
      .post("/api/v1/adjustments")
      .set("Authorization", `Bearer ${tokenA}`)
      .send({ productId: productIdA, physicalStock: 12, reason: "  " });
    expect(res.status).toBe(400);
  });

  it("produk toko lain -> 404", async () => {
    const res = await request(app)
      .post("/api/v1/adjustments")
      .set("Authorization", `Bearer ${tokenB}`)
      .send({ productId: productIdA, physicalStock: 12, reason: "x" });
    expect(res.status).toBe(404);
  });

  it("retry id sama 2x paralel -> stok +diff sekali", async () => {
    const retryId = crypto.randomUUID();
    const before = await getPool().query(
      "SELECT stock FROM products WHERE id = $1",
      [productIdA],
    );
    const base = before.rows[0].stock as number;

    const [r1, r2] = await Promise.all([
      request(app)
        .post("/api/v1/adjustments")
        .set("Authorization", `Bearer ${tokenA}`)
        .send({
          id: retryId,
          productId: productIdA,
          physicalStock: base + 2,
          reason: "selip",
        }),
      request(app)
        .post("/api/v1/adjustments")
        .set("Authorization", `Bearer ${tokenA}`)
        .send({
          id: retryId,
          productId: productIdA,
          physicalStock: base + 2,
          reason: "selip",
        }),
    ]);
    expect([r1.status, r2.status]).toEqual([201, 201]);

    const after = await getPool().query(
      "SELECT stock FROM products WHERE id = $1",
      [productIdA],
    );
    expect(after.rows[0].stock).toBe(base + 2);
  });

  it("GET isolasi store: toko B tidak lihat adjustment toko A", async () => {
    const res = await request(app)
      .get("/api/v1/adjustments")
      .set("Authorization", `Bearer ${tokenB}`);
    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });
});

describe("POST /api/v1/adjustments/:id/void", () => {
  it("void + alasan -> status voided, stok kembali", async () => {
    const before = await getPool().query(
      "SELECT stock FROM products WHERE id = $1",
      [productIdA],
    );
    const base = before.rows[0].stock as number;
    const created = await request(app)
      .post("/api/v1/adjustments")
      .set("Authorization", `Bearer ${tokenA}`)
      .send({
        productId: productIdA,
        physicalStock: base + 5,
        reason: "selip",
      });
    expect(created.status).toBe(201);
    const id = created.body.id as string;

    const res = await request(app)
      .post(`/api/v1/adjustments/${id}/void`)
      .set("Authorization", `Bearer ${tokenA}`)
      .send({ reason: "salah hitung" });
    expect(res.status).toBe(200);
    expect(res.body.status).toBe("voided");

    const prod = await getPool().query(
      "SELECT stock FROM products WHERE id = $1",
      [productIdA],
    );
    expect(prod.rows[0].stock).toBe(base);
  });

  it("void tanpa alasan -> 400", async () => {
    const before = await getPool().query(
      "SELECT stock FROM products WHERE id = $1",
      [productIdA],
    );
    const base = before.rows[0].stock as number;
    const created = await request(app)
      .post("/api/v1/adjustments")
      .set("Authorization", `Bearer ${tokenA}`)
      .send({
        productId: productIdA,
        physicalStock: base + 1,
        reason: "selip",
      });
    const id = created.body.id as string;
    const res = await request(app)
      .post(`/api/v1/adjustments/${id}/void`)
      .set("Authorization", `Bearer ${tokenA}`)
      .send({ reason: "  " });
    expect(res.status).toBe(400);
  });

  it("void saat stok kurang (sudah terjual) -> 409, stok tidak berubah", async () => {
    const before = await getPool().query(
      "SELECT stock FROM products WHERE id = $1",
      [productIdA],
    );
    const base = before.rows[0].stock as number;
    const created = await request(app)
      .post("/api/v1/adjustments")
      .set("Authorization", `Bearer ${tokenA}`)
      .send({
        productId: productIdA,
        physicalStock: base + 4,
        reason: "selip",
      });
    const id = created.body.id as string;

    // Jual habis stok tambahan via sales POST.
    const sale = await request(app)
      .post("/api/v1/sales")
      .set("Authorization", `Bearer ${tokenA}`)
      .send({
        number: `VOID${stamp}001`,
        items: [{ productId: productIdA, qty: base + 4 }],
        paid: 1000000,
        method: "tunai",
      });
    expect(sale.status).toBe(201);

    const res = await request(app)
      .post(`/api/v1/adjustments/${id}/void`)
      .set("Authorization", `Bearer ${tokenA}`)
      .send({ reason: "batal" });
    expect(res.status).toBe(409);

    const prod = await getPool().query(
      "SELECT stock FROM products WHERE id = $1",
      [productIdA],
    );
    expect(prod.rows[0].stock).toBe(0);
  });

  it("void 2x -> 200 idempoten", async () => {
    const before = await getPool().query(
      "SELECT stock FROM products WHERE id = $1",
      [productIdA],
    );
    const base = before.rows[0].stock as number;
    const created = await request(app)
      .post("/api/v1/adjustments")
      .set("Authorization", `Bearer ${tokenA}`)
      .send({
        productId: productIdA,
        physicalStock: base + 2,
        reason: "selip",
      });
    const id = created.body.id as string;
    const v1 = await request(app)
      .post(`/api/v1/adjustments/${id}/void`)
      .set("Authorization", `Bearer ${tokenA}`)
      .send({ reason: "batal" });
    expect(v1.status).toBe(200);
    const v2 = await request(app)
      .post(`/api/v1/adjustments/${id}/void`)
      .set("Authorization", `Bearer ${tokenA}`)
      .send({ reason: "batal lagi" });
    expect(v2.status).toBe(200);

    const prod = await getPool().query(
      "SELECT stock FROM products WHERE id = $1",
      [productIdA],
    );
    expect(prod.rows[0].stock).toBe(base);
  });
});
