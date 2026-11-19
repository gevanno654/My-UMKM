import { Router } from "express";
import { z } from "zod";
import { getPool } from "../db";
import { comparePassword, hashPassword } from "./password";
import {
  hashRefreshToken,
  refreshExpiresAt,
  signAccessToken,
  signRefreshToken,
  verifyAccessToken,
  verifyRefreshToken,
} from "./tokens";

export const authRouter = Router();
export const meRouter = Router();

const registerSchema = z.object({
  storeName: z.string().min(1),
  ownerName: z.string().min(1),
  email: z.string().email(),
  password: z.string().min(8),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

const refreshSchema = z.object({
  refreshToken: z.string().min(1),
});

function toAuthPayload(
  user: { id: string; store_id: string; name: string; email: string },
  store: { id: string; name: string },
  accessToken: string,
  refreshToken: string,
) {
  return {
    user: {
      id: user.id,
      storeId: user.store_id,
      name: user.name,
      email: user.email,
    },
    store: { id: store.id, name: store.name },
    accessToken,
    refreshToken,
  };
}

async function issueTokens(userId: string, storeId: string) {
  const accessToken = signAccessToken({ userId, storeId });
  const refreshToken = signRefreshToken(userId);
  await getPool().query(
    "INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES ($1, $2, $3)",
    [userId, hashRefreshToken(refreshToken), refreshExpiresAt()],
  );
  return { accessToken, refreshToken };
}

authRouter.post("/register", async (req, res) => {
  const parsed = registerSchema.safeParse(req.body);
  if (!parsed.success) {
    return res
      .status(400)
      .json({ error: "validation", details: parsed.error.flatten() });
  }
  const { storeName, ownerName, email, password } = parsed.data;
  const existing = await getPool().query(
    "SELECT id FROM users WHERE email = $1",
    [email],
  );
  if (existing.rowCount) {
    return res.status(409).json({ error: "email taken" });
  }

  const client = await getPool().connect();
  try {
    await client.query("BEGIN");
    const storeRes = await client.query(
      "INSERT INTO stores (name) VALUES ($1) RETURNING id, name",
      [storeName],
    );
    const store = storeRes.rows[0];
    const userRes = await client.query(
      "INSERT INTO users (store_id, name, email, password_hash) VALUES ($1, $2, $3, $4) RETURNING id, store_id, name, email",
      [store.id, ownerName, email, await hashPassword(password)],
    );
    const user = userRes.rows[0];
    const accessToken = signAccessToken({ userId: user.id, storeId: store.id });
    const refreshToken = signRefreshToken(user.id);
    await client.query(
      "INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES ($1, $2, $3)",
      [user.id, hashRefreshToken(refreshToken), refreshExpiresAt()],
    );
    await client.query("COMMIT");
    return res
      .status(201)
      .json(toAuthPayload(user, store, accessToken, refreshToken));
  } catch (err) {
    await client.query("ROLLBACK");
    if (
      typeof err === "object" &&
      err !== null &&
      "code" in err &&
      (err as { code: string }).code === "23505"
    ) {
      return res.status(409).json({ error: "email taken" });
    }
    throw err;
  } finally {
    client.release();
  }
});

authRouter.post("/login", async (req, res) => {
  const parsed = loginSchema.safeParse(req.body);
  if (!parsed.success) {
    return res
      .status(400)
      .json({ error: "validation", details: parsed.error.flatten() });
  }
  const { email, password } = parsed.data;
  const userRes = await getPool().query(
    "SELECT id, store_id, name, email, password_hash FROM users WHERE email = $1",
    [email],
  );
  const user = userRes.rows[0];
  if (!user || !(await comparePassword(password, user.password_hash))) {
    return res.status(401).json({ error: "wrong credentials" });
  }
  const storeRes = await getPool().query(
    "SELECT id, name FROM stores WHERE id = $1",
    [user.store_id],
  );
  const tokens = await issueTokens(user.id, user.store_id);
  return res
    .status(200)
    .json(toAuthPayload(user, storeRes.rows[0], tokens.accessToken, tokens.refreshToken));
});

authRouter.post("/refresh", async (req, res) => {
  const parsed = refreshSchema.safeParse(req.body);
  if (!parsed.success) {
    return res
      .status(400)
      .json({ error: "validation", details: parsed.error.flatten() });
  }
  let payload: { userId: string };
  try {
    payload = verifyRefreshToken(parsed.data.refreshToken);
  } catch {
    return res.status(401).json({ error: "invalid refresh token" });
  }
  const tokenHash = hashRefreshToken(parsed.data.refreshToken);
  const found = await getPool().query(
    "SELECT id, user_id, expires_at, revoked_at FROM refresh_tokens WHERE token_hash = $1",
    [tokenHash],
  );
  const row = found.rows[0];
  if (
    !row ||
    row.revoked_at ||
    row.user_id !== payload.userId ||
    new Date(row.expires_at) < new Date()
  ) {
    // Reuse detection: revoke semua token user itu
    await getPool().query(
      "UPDATE refresh_tokens SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL",
      [payload.userId],
    );
    return res.status(401).json({ error: "invalid refresh token" });
  }
  await getPool().query("UPDATE refresh_tokens SET revoked_at = now() WHERE id = $1", [
    row.id,
  ]);
  const userRes = await getPool().query(
    "SELECT store_id FROM users WHERE id = $1",
    [payload.userId],
  );
  if (!userRes.rowCount) {
    return res.status(401).json({ error: "invalid refresh token" });
  }
  const tokens = await issueTokens(payload.userId, userRes.rows[0].store_id);
  return res.status(200).json(tokens);
});

meRouter.get("/me", async (req, res) => {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    return res.status(401).json({ error: "missing token" });
  }
  let payload: { userId: string; storeId: string };
  try {
    payload = verifyAccessToken(header.slice("Bearer ".length));
  } catch {
    return res.status(401).json({ error: "invalid token" });
  }
  const userRes = await getPool().query(
    "SELECT id, store_id, name, email FROM users WHERE id = $1",
    [payload.userId],
  );
  const user = userRes.rows[0];
  if (!user) {
    return res.status(401).json({ error: "invalid token" });
  }
  const storeRes = await getPool().query(
    "SELECT id, name FROM stores WHERE id = $1",
    [user.store_id],
  );
  return res.status(200).json({
    user: { id: user.id, storeId: user.store_id, name: user.name, email: user.email },
    store: storeRes.rows[0],
  });
});
