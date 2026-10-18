import pg from 'pg';
import { readFileSync } from 'node:fs';

const pool = new pg.Pool({ connectionString: process.env.WEB_MIGRATION_DATABASE_URL ?? process.env.WEB_DATABASE_URL,
  ssl: process.env.DATABASE_CA_FILE ? { ca: readFileSync(process.env.DATABASE_CA_FILE, 'utf8'), rejectUnauthorized: true } : undefined });
try {
  await pool.query(`
    CREATE SCHEMA IF NOT EXISTS bff;
    CREATE TABLE IF NOT EXISTS bff.web_sessions (
      id_hash text PRIMARY KEY, payload text NOT NULL, subject text NOT NULL,
      expires_at timestamptz NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS web_sessions_expiry ON bff.web_sessions(expires_at);
    CREATE TABLE IF NOT EXISTS bff.auth_attempts (
      state_hash text PRIMARY KEY, payload text NOT NULL, expires_at timestamptz NOT NULL
    );
    DELETE FROM bff.web_sessions WHERE expires_at < now();
    DELETE FROM bff.auth_attempts WHERE expires_at < now();
  `);
  console.log('BFF session schema ready.');
} finally { await pool.end(); }
