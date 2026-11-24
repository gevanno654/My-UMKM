import { afterAll, beforeAll, describe, expect, it } from "vitest";
import request from "supertest";
import { app } from "../src/app";
import { closePool } from "../src/db";

process.env.DATABASE_URL ??=
  "postgres://pos:pos@localhost:5432/pos_test";
process.env.JWT_ACCESS_SECRET ??= "test-access-secret-0123456789abcdef";
process.env.JWT_REFRESH_SECRET ??= "test-refresh-secret-0123456789abcdef";

const stamp = Date.now();
let token = "";
let holderId = "";

beforeAll(async () => {
  const res = await request(app).post("/api/v1/auth/register").send({
    storeName: "Toko Rekonsiliasi",
    ownerName: "Owner",
    email: `recon-${stamp}@warung.test`,
    password: "password123",
  });
  token = res.body.accessToken as string;

  const created = await request(app)
    .post("/api/v1/products")
    .set("Authorization", `Bearer ${token}`)
    .send({ name: "Minion", barcode: "767062281296", sellPrice: 10000 });
  holderId = created.body.id as string;
});

afterAll(async () => {
  await closePool();
});

describe("409 barcode taken menyertakan conflictWith", () => {
  it("POST barcode duplikat -> 409 + conflictWith id pemegang", async () => {
    const res = await request(app)
      .post("/api/v1/products")
      .set("Authorization", `Bearer ${token}`)
      .send({ name: "Minion Baru", barcode: "767062281296", sellPrice: 11000 });
    expect(res.status).toBe(409);
    expect(res.body.conflictWith).toBeDefined();
    expect(res.body.conflictWith.id).toBe(holderId);
  });

  it("PUT ganti barcode ke milik baris lain -> 409 + conflictWith benar", async () => {
    const other = await request(app)
      .post("/api/v1/products")
      .set("Authorization", `Bearer ${token}`)
      .send({ name: "Lain", barcode: "999000111222", sellPrice: 5000 });
    const res = await request(app)
      .put(`/api/v1/products/${other.body.id}`)
      .set("Authorization", `Bearer ${token}`)
      .send({ barcode: "767062281296" });
    expect(res.status).toBe(409);
    expect(res.body.conflictWith.id).toBe(holderId);
  });
});
