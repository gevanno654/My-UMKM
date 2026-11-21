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
const emailA = `restock-a-${stamp}@warung.test`;
const emailB = `restock-b-${stamp}@warung.test`;

let tokenA = "";
let tokenB = "";
let productIdA = "";
let productIdB = "";

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
  await getPool().query(
    "TRUNCATE refresh_tokens, users, restock_items, restocks, sale_items, sales, products, stores RESTART IDENTITY CASCADE",
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

  const prod2 = await request(app)
    .post("/api/v1/products")
    .set("Authorization", `Bearer ${tokenA}`)
    .send({ name: "Kopi", costPrice: 2000, sellPrice: 3000, stock: 5 });
  productIdB = prod2.body.id as string;
});

afterAll(async () => {
  await closePool();
});

describe("POST /api/v1/restocks", () => {
  it("valid 2 item -> 201, stok bertambah, harga katalog update", async () => {
    const res = await request(app)
      .post("/api/v1/restocks")
      .set("Authorization", `Bearer ${tokenA}`)
      .send({
        items: [
          { productId: productIdA, qty: 5, costPrice: 2600, sellPrice: 3600 },
          { productId: productIdB, qty: 3, costPrice: 2100 },
        ],
      });
    expect(res.status).toBe(201);
    expect(res.body.total).toBe(5 * 2600 + 3 * 2100);
    expect(res.body.status).toBe("ok");
    expect(res.body.items.length).toBe(2);

    const prod = await getPool().query(
      "SELECT stock, cost_price, sell_price FROM products WHERE id = $1",
      [productIdA],
    );
    expect(prod.rows[0].stock).toBe(15);
    expect(prod.rows[0].cost_price).toBe(2600);
    expect(prod.rows[0].sell_price).toBe(3600);

    const prod2 = await getPool().query(
      "SELECT stock, cost_price, sell_price FROM products WHERE id = $1",
      [productIdB],
    );
    expect(prod2.rows[0].stock).toBe(8);
    expect(prod2.rows[0].cost_price).toBe(2100);
    // Tanpa sellPrice: harga jual katalog tetap.
    expect(prod2.rows[0].sell_price).toBe(3000);
  });

  it("produk toko lain -> 404", async () => {
    const res = await request(app)
      .post("/api/v1/restocks")
      .set("Authorization", `Bearer ${tokenB}`)
      .send({ items: [{ productId: productIdA, qty: 1, costPrice: 100 }] });
    expect(res.status).toBe(404);
  });

  it("qty 0 -> 400", async () => {
    const res = await request(app)
      .post("/api/v1/restocks")
      .set("Authorization", `Bearer ${tokenA}`)
      .send({ items: [{ productId: productIdA, qty: 0, costPrice: 100 }] });
    expect(res.status).toBe(400);
  });
});

describe("POST /api/v1/restocks/:id/void", () => {
  it("void + alasan -> status voided, stok kembali", async () => {
    const created = await request(app)
      .post("/api/v1/restocks")
      .set("Authorization", `Bearer ${tokenA}`)
      .send({ items: [{ productId: productIdA, qty: 4, costPrice: 2600 }] });
    expect(created.status).toBe(201);
    const id = created.body.id as string;

    const res = await request(app)
      .post(`/api/v1/restocks/${id}/void`)
      .set("Authorization", `Bearer ${tokenA}`)
      .send({ reason: "salah input" });
    expect(res.status).toBe(200);
    expect(res.body.status).toBe("voided");

    const prod = await getPool().query(
      "SELECT stock FROM products WHERE id = $1",
      [productIdA],
    );
    // 10 awal + 5 (test pertama) + 4 - 4 (void) = 15
    expect(prod.rows[0].stock).toBe(15);
  });

  it("void tanpa alasan -> 400", async () => {
    const created = await request(app)
      .post("/api/v1/restocks")
      .set("Authorization", `Bearer ${tokenA}`)
      .send({ items: [{ productId: productIdA, qty: 1, costPrice: 2600 }] });
    const id = created.body.id as string;
    const res = await request(app)
      .post(`/api/v1/restocks/${id}/void`)
      .set("Authorization", `Bearer ${tokenA}`)
      .send({ reason: "  " });
    expect(res.status).toBe(400);
  });

  it("void saat stok kurang (sudah terjual) -> 409, stok tidak berubah", async () => {
    const created = await request(app)
      .post("/api/v1/restocks")
      .set("Authorization", `Bearer ${tokenA}`)
      .send({ items: [{ productId: productIdB, qty: 3, costPrice: 2100 }] });
    const id = created.body.id as string;

    // Jual habis stok Kopi lewat kasir.
    const stock = await getPool().query(
      "SELECT stock FROM products WHERE id = $1",
      [productIdB],
    );
    const qty = stock.rows[0].stock as number;
    const sale = await request(app)
      .post("/api/v1/sales")
      .set("Authorization", `Bearer ${tokenA}`)
      .send({
        number: `RK${stamp}001`,
        items: [{ productId: productIdB, qty }],
        paid: qty * 3000,
        method: "tunai",
      });
    expect(sale.status).toBe(201);

    const res = await request(app)
      .post(`/api/v1/restocks/${id}/void`)
      .set("Authorization", `Bearer ${tokenA}`)
      .send({ reason: "salah input" });
    expect(res.status).toBe(409);
    expect(res.body.error).toBe("insufficient stock");

    const after = await getPool().query(
      "SELECT stock FROM products WHERE id = $1",
      [productIdB],
    );
    expect(after.rows[0].stock).toBe(0);
  });
});

describe("GET /api/v1/restocks", () => {
  it("isolasi per store + items nested", async () => {
    const resA = await request(app)
      .get("/api/v1/restocks")
      .set("Authorization", `Bearer ${tokenA}`);
    expect(resA.status).toBe(200);
    expect(resA.body.length).toBeGreaterThan(0);
    expect(resA.body[0].items.length).toBeGreaterThan(0);

    const resB = await request(app)
      .get("/api/v1/restocks")
      .set("Authorization", `Bearer ${tokenB}`);
    expect(resB.status).toBe(200);
    expect(resB.body.length).toBe(0);
  });
});
