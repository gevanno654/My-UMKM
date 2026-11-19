import { createHash, randomUUID } from "node:crypto";
import jwt from "jsonwebtoken";

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

function accessSecret(): string {
  return process.env.JWT_ACCESS_SECRET ?? "dev-access-secret-change-me";
}

function refreshSecret(): string {
  return process.env.JWT_REFRESH_SECRET ?? "dev-refresh-secret-change-me";
}

export function signAccessToken(payload: {
  userId: string;
  storeId: string;
}): string {
  return jwt.sign(payload, accessSecret(), { expiresIn: "15m" });
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
