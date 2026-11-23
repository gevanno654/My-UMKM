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
// Isolasi file foto test dari data dev.
process.env.PHOTO_DIR ??= path.join(
  process.cwd(),
  ".data-test",
  "photos",
);

const stamp = Date.now();
const emailA = `photo-a-${stamp}@warung.test`;
const emailB = `photo-b-${stamp}@warung.test`;

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
  await applyMigration("008_product_photos.sql");
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

  const prod = await request(app)
    .post("/api/v1/products")
    .set("Authorization", `Bearer ${tokenA}`)
    .send({ name: "Indomie", sellPrice: 3500, stock: 10 });
  productIdA = prod.body.id as string;
});

afterAll(async () => {
  await closePool();
});

describe("foto produk", () => {
  it("upload → manifest → download round-trip per store", async () => {
    const bytes = Buffer.from([0xff, 0xd8, 0xff, 0xd9]);
    const up = await request(app)
      .post(`/api/v1/products/${productIdA}/photo`)
      .set("Authorization", `Bearer ${tokenA}`)
      .attach("photo", bytes, "a.jpg");
    expect(up.status).toBe(200);
    const expected = crypto.createHash("sha256").update(bytes).digest("hex");
    expect(up.body.photoHash).toBe(expected);
    expect(up.body.photoSize).toBe(bytes.length);

    const man = await request(app)
      .get("/api/v1/products/photo-manifest")
      .set("Authorization", `Bearer ${tokenA}`);
    expect(man.status).toBe(200);
    expect(man.body).toContainEqual({
      id: productIdA,
      photoHash: expected,
    });

    const dl = await request(app)
      .get(`/api/v1/products/photos/${expected}`)
      .set("Authorization", `Bearer ${tokenA}`);
    expect(dl.status).toBe(200);
    expect(dl.headers["content-type"]).toContain("image/jpeg");

    // Isolasi: store B tidak bisa unduh hash milik store A.
    const cross = await request(app)
      .get(`/api/v1/products/photos/${expected}`)
      .set("Authorization", `Bearer ${tokenB}`);
    expect(cross.status).toBe(404);
  });

  it("upload > 2MB → 413", async () => {
    const big = Buffer.alloc(2 * 1024 * 1024 + 1, 1);
    const res = await request(app)
      .post(`/api/v1/products/${productIdA}/photo`)
      .set("Authorization", `Bearer ${tokenA}`)
      .attach("photo", big, "big.jpg");
    expect(res.status).toBe(413);
  });

  it("delete foto → kolom kosong + file hilang", async () => {
    const bytes = Buffer.from([0xff, 0xd8, 0xff, 0xd9, 0x01]);
    const up = await request(app)
      .post(`/api/v1/products/${productIdA}/photo`)
      .set("Authorization", `Bearer ${tokenA}`)
      .attach("photo", bytes, "b.jpg");
    expect(up.status).toBe(200);
    const del = await request(app)
      .delete(`/api/v1/products/${productIdA}/photo`)
      .set("Authorization", `Bearer ${tokenA}`);
    expect(del.status).toBe(200);
    expect(del.body.photoHash).toBe("");
    const dl = await request(app)
      .get(`/api/v1/products/photos/${up.body.photoHash}`)
      .set("Authorization", `Bearer ${tokenA}`);
    expect(dl.status).toBe(404);
  });
});
