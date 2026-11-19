import { Pool } from "pg";

let pool: Pool | null = null;

export function getPool(): Pool {
  if (!pool) {
    const connectionString =
      process.env.DATABASE_URL ??
      "postgres://pos:pos@localhost:5432/pos_dev";
    pool = new Pool({ connectionString });
  }
  return pool;
}

export async function closePool(): Promise<void> {
  if (pool) {
    await pool.end();
    pool = null;
  }
}
