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

const email = `owner-${Date.now()}@warung.test`;

beforeAll(async () => {
  const sql = fs.readFileSync(
    path.join(process.cwd(), "migrations", "001_init.sql"),
    "utf8",
  );
  await getPool().query(sql);
  await getPool().query(
    "TRUNCATE refresh_tokens, users, stores RESTART IDENTITY CASCADE",
  );
});

afterAll(async () => {
  await closePool();
});

describe("POST /api/v1/auth/register", () => {
  it("201 + mengembalikan storeId", async () => {
    const res = await request(app).post("/api/v1/auth/register").send({
      storeName: "Warung Test",
      ownerName: "Owner",
      email,
      password: "password123",
    });
    expect(res.status).toBe(201);
    expect(res.body.user.storeId).toBeDefined();
    expect(res.body.store.id).toBe(res.body.user.storeId);
    expect(res.body.accessToken).toBeTypeOf("string");
    expect(res.body.refreshToken).toBeTypeOf("string");
  });

  it("email sama -> 409", async () => {
    const res = await request(app).post("/api/v1/auth/register").send({
      storeName: "Warung Lain",
      ownerName: "Owner 2",
      email,
      password: "password123",
    });
    expect(res.status).toBe(409);
  });

  it("password < 8 char -> 400", async () => {
    const res = await request(app).post("/api/v1/auth/register").send({
      storeName: "Warung X",
      ownerName: "Owner X",
      email: `short-${Date.now()}@warung.test`,
      password: "123",
    });
    expect(res.status).toBe(400);
  });
});

describe("POST /api/v1/auth/login", () => {
  it("salah password -> 401", async () => {
    const res = await request(app).post("/api/v1/auth/login").send({
      email,
      password: "salah-password",
    });
    expect(res.status).toBe(401);
  });

  it("sukses -> 200 + token", async () => {
    const res = await request(app).post("/api/v1/auth/login").send({
      email,
      password: "password123",
    });
    expect(res.status).toBe(200);
    expect(res.body.accessToken).toBeTypeOf("string");
  });
});

describe("POST /api/v1/auth/refresh", () => {
  it("memutar token: token lama -> 401", async () => {
    const login = await request(app).post("/api/v1/auth/login").send({
      email,
      password: "password123",
    });
    const oldRefresh = login.body.refreshToken as string;

    const rotated = await request(app)
      .post("/api/v1/auth/refresh")
      .send({ refreshToken: oldRefresh });
    expect(rotated.status).toBe(200);
    expect(rotated.body.refreshToken).not.toBe(oldRefresh);

    const reuse = await request(app)
      .post("/api/v1/auth/refresh")
      .send({ refreshToken: oldRefresh });
    expect(reuse.status).toBe(401);

    // reuse detection: semua token user ikut direvoke
    const afterNuke = await request(app)
      .post("/api/v1/auth/refresh")
      .send({ refreshToken: rotated.body.refreshToken });
    expect(afterNuke.status).toBe(401);
  });
});

describe("GET /api/v1/me", () => {
  it("tanpa token -> 401", async () => {
    const res = await request(app).get("/api/v1/me");
    expect(res.status).toBe(401);
  });

  it("dengan token -> 200 user+store", async () => {
    const login = await request(app).post("/api/v1/auth/login").send({
      email,
      password: "password123",
    });
    const res = await request(app)
      .get("/api/v1/me")
      .set("Authorization", `Bearer ${login.body.accessToken}`);
    expect(res.status).toBe(200);
    expect(res.body.user.email).toBe(email);
    expect(res.body.store.id).toBe(res.body.user.storeId);
  });
});
