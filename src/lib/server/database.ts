import pg from 'pg';
import { env } from '$env/dynamic/private';
import { readFileSync } from 'node:fs';

let pool: pg.Pool | undefined;
export function database() {
  if (!env.WEB_DATABASE_URL) throw new Error('Web database is not configured');
  if (process.env.NODE_ENV === 'production' && !env.DATABASE_CA_FILE) throw new Error('Database TLS is not configured');
  const parameters = new URL(env.WEB_DATABASE_URL).searchParams;
  if (['sslmode', 'sslcert', 'sslkey', 'sslrootcert'].some(name => parameters.has(name))) throw new Error('Configure database TLS through the CA file');
  if (pool) return pool;
  pool = new pg.Pool({
    connectionString: env.WEB_DATABASE_URL,
    max: 5,
    connectionTimeoutMillis: 3000,
    idleTimeoutMillis: 30_000,
    ssl: env.DATABASE_CA_FILE ? { ca: readFileSync(env.DATABASE_CA_FILE, 'utf8'), rejectUnauthorized: true } : undefined
  });
  pool.on('error', () => undefined);
  setInterval(() => {
    pool?.query('DELETE FROM bff.web_sessions WHERE expires_at < now(); DELETE FROM bff.auth_attempts WHERE expires_at < now();').catch(() => undefined);
  }, 600_000).unref();
  return pool;
}
