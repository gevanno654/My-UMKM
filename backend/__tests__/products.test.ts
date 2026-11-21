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
const emailA = `prod-a-${stamp}@warung.test`;
const emailB = `prod-b-${stamp}@warung.test`;

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
  await getPool().query(
    "TRUNCATE refresh_tokens, users, products, stores RESTART IDENTITY CASCADE",
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
});

afterAll(async () => {
  await closePool();
});

describe("POST /api/v1/products", () => {
  it("toko A membuat produk -> 201 + id kembali", async () => {
    const res = await request(app)
      .post("/api/v1/products")
      .set("Authorization", `Bearer ${tokenA}`)
      .send({
        name: "Indomie Goreng",
        barcode: "899001",
        costPrice: 2500,
        sellPrice: 3500,
        stock: 10,
        category: "Makanan",
      });
    expect(res.status).toBe(201);
    expect(res.body.id).toBeDefined();
    productIdA = res.body.id as string;
  });

  it("barcode sama di toko A -> 409", async () => {
    const res = await request(app)
      .post("/api/v1/products")
      .set("Authorization", `Bearer ${tokenA}`)
      .send({
        name: "Indomie Lain",
        barcode: "899001",
        costPrice: 2500,
        sellPrice: 3500,
      });
    expect(res.status).toBe(409);
  });

  it("barcode sama di toko B -> 201 (isolasi per store)", async () => {
    const res = await request(app)
      .post("/api/v1/products")
      .set("Authorization", `Bearer ${tokenB}`)
      .send({
        name: "Indomie Goreng",
        barcode: "899001",
        costPrice: 2500,
        sellPrice: 3500,
      });
    expect(res.status).toBe(201);
  });
});

describe("GET /api/v1/products", () => {
  it("toko A hanya melihat milik A (isolasi store)", async () => {
    const res = await request(app)
      .get("/api/v1/products")
      .set("Authorization", `Bearer ${tokenA}`);
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBe(1);
    expect(res.body[0].name).toBe("Indomie Goreng");
  });
});

describe("PUT /api/v1/products/:id", () => {
  it("beda store -> 404", async () => {
    const res = await request(app)
      .put(`/api/v1/products/${productIdA}`)
      .set("Authorization", `Bearer ${tokenB}`)
      .send({ name: "Diubah B" });
    expect(res.status).toBe(404);
  });
});

describe("DELETE /api/v1/products/:id", () => {
  it("soft delete -> GET tidak tampil lagi", async () => {
    const del = await request(app)
      .delete(`/api/v1/products/${productIdA}`)
      .set("Authorization", `Bearer ${tokenA}`);
    expect(del.status).toBe(200);
    expect(del.body.deleted).toBe(true);

    const list = await request(app)
      .get("/api/v1/products")
      .set("Authorization", `Bearer ${tokenA}`);
    expect(list.status).toBe(200);
    expect(list.body.length).toBe(0);
  });

  it("barcode produk terhapus bisa dipakai ulang", async () => {
    const res = await request(app)
      .post("/api/v1/products")
      .set("Authorization", `Bearer ${tokenA}`)
      .send({
        name: "Indomie Baru",
        barcode: "899001",
        costPrice: 2600,
        sellPrice: 3600,
      });
    expect(res.status).toBe(201);
    expect(res.body.barcode).toBe("899001");
  });
});
