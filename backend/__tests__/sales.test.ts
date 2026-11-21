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
const emailA = `sale-a-${stamp}@warung.test`;
const emailB = `sale-b-${stamp}@warung.test`;

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
  await applyMigration("003_sales.sql");
  await getPool().query(
    "TRUNCATE refresh_tokens, users, sale_items, sales, products, stores RESTART IDENTITY CASCADE",
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
    .send({ name: "Indomie", sellPrice: 3500, stock: 10 });
  productIdA = prod.body.id as string;
});

afterAll(async () => {
  await closePool();
});

describe("POST /api/v1/sales", () => {
  it("tunai valid -> 201, total benar, stok berkurang", async () => {
    const res = await request(app)
      .post("/api/v1/sales")
      .set("Authorization", `Bearer ${tokenA}`)
      .send({
        number: "TE010120260001",
        items: [{ productId: productIdA, qty: 2 }],
        paid: 10000,
        method: "tunai",
      });
    expect(res.status).toBe(201);
    expect(res.body.number).toBe("TE010120260001");
    expect(res.body.total).toBe(7000);
    expect(res.body.change).toBe(3000);

    const prod = await getPool().query(
      "SELECT stock FROM products WHERE id = $1",
      [productIdA],
    );
    expect(prod.rows[0].stock).toBe(8);
  });

  it("nomor duplikat di toko sama -> 409", async () => {
    const res = await request(app)
      .post("/api/v1/sales")
      .set("Authorization", `Bearer ${tokenA}`)
      .send({
        number: "TE010120260001",
        items: [{ productId: productIdA, qty: 1 }],
        paid: 3500,
        method: "tunai",
      });
    expect(res.status).toBe(409);
  });

  it("stok kurang -> 409 insufficient stock", async () => {
    const res = await request(app)
      .post("/api/v1/sales")
      .set("Authorization", `Bearer ${tokenA}`)
      .send({
        number: "TE010120260002",
        items: [{ productId: productIdA, qty: 99 }],
        paid: 346500,
        method: "tunai",
      });
    expect(res.status).toBe(409);
    expect(res.body.error).toBe("insufficient stock");
  });

  it("tunai kurang bayar -> 400", async () => {
    const res = await request(app)
      .post("/api/v1/sales")
      .set("Authorization", `Bearer ${tokenA}`)
      .send({
        number: "TE010120260003",
        items: [{ productId: productIdA, qty: 1 }],
        paid: 1000,
        method: "tunai",
      });
    expect(res.status).toBe(400);
  });

  it("qty 0 -> 400", async () => {
    const res = await request(app)
      .post("/api/v1/sales")
      .set("Authorization", `Bearer ${tokenA}`)
      .send({
        number: "TE010120260004",
        items: [{ productId: productIdA, qty: 0 }],
        paid: 0,
        method: "qris",
      });
    expect(res.status).toBe(400);
  });

  it("produk toko lain -> 404", async () => {
    const res = await request(app)
      .post("/api/v1/sales")
      .set("Authorization", `Bearer ${tokenB}`)
      .send({
        number: "TB010120260001",
        items: [{ productId: productIdA, qty: 1 }],
        paid: 3500,
        method: "tunai",
      });
    expect(res.status).toBe(404);
  });
});

describe("GET /api/v1/sales", () => {
  it("isolasi per store + items nested", async () => {
    const resA = await request(app)
      .get("/api/v1/sales")
      .set("Authorization", `Bearer ${tokenA}`);
    expect(resA.status).toBe(200);
    expect(resA.body.length).toBe(1);
    expect(resA.body[0].items.length).toBe(1);
    expect(resA.body[0].items[0].qty).toBe(2);

    const resB = await request(app)
      .get("/api/v1/sales")
      .set("Authorization", `Bearer ${tokenB}`);
    expect(resB.status).toBe(200);
    expect(resB.body.length).toBe(0);
  });
});
