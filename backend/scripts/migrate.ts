import "dotenv/config";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { getPool, closePool } from "../src/db";

async function main() {
  const dir = path.dirname(fileURLToPath(import.meta.url));
  const migrationsDir = path.join(dir, "..", "migrations");
  const files = fs
    .readdirSync(migrationsDir)
    .filter((f: string) => f.endsWith(".sql"))
    .sort();
  for (const file of files) {
    const sql = fs.readFileSync(path.join(migrationsDir, file), "utf8");
    await getPool().query(sql);
    console.log(`migration ok: ${file}`);
  }
  await closePool();
}

void main();
