import { createHash, randomUUID } from "node:crypto";
import jwt from "jsonwebtoken";

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

const PLACEHOLDERS = new Set(["change-me-32char", "dev-access-secret-change-me", "dev-refresh-secret-change-me"]);

function requiredSecret(name: "JWT_ACCESS_SECRET" | "JWT_REFRESH_SECRET"): string {
  const value = process.env[name];
  if (process.env.NODE_ENV === "production" && (!value || PLACEHOLDERS.has(value))) {
    throw new Error(`${name} must be set to a real secret in production`);
  }
  return value ?? (name === "JWT_ACCESS_SECRET" ? "dev-access-secret-change-me" : "dev-refresh-secret-change-me");
}

function accessSecret(): string {
  return requiredSecret("JWT_ACCESS_SECRET");
}

function refreshSecret(): string {
  return requiredSecret("JWT_REFRESH_SECRET");
}

export function signAccessToken(payload: {
  userId: string;
  storeId: string;
}): string {
  const expiresIn = process.env.ACCESS_TTL ?? "15m";
  return jwt.sign(payload, accessSecret(), { expiresIn } as jwt.SignOptions);
}

export function signRefreshToken(userId: string): string {
  return jwt.sign({ userId, jti: randomUUID() }, refreshSecret(), {
    expiresIn: "30d",
  });
}

export function verifyAccessToken(token: string): {
  userId: string;
  storeId: string;
} {
  return jwt.verify(token, accessSecret()) as {
    userId: string;
    storeId: string;
  };
}

export function verifyRefreshToken(token: string): { userId: string } {
  return jwt.verify(token, refreshSecret()) as { userId: string };
}

export function hashRefreshToken(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

export function refreshExpiresAt(): Date {
  const days = Number(process.env.REFRESH_TTL_DAYS ?? 30);
  return new Date(Date.now() + days * 24 * 60 * 60 * 1000);
}
