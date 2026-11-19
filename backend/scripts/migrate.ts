import "dotenv/config";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { getPool, closePool } from "../src/db";

const dir = path.dirname(fileURLToPath(import.meta.url));
const sql = fs.readFileSync(path.join(dir, "..", "migrations", "001_init.sql"), "utf8");

await getPool().query(sql);
await closePool();
console.log("migration ok: 001_init.sql");
