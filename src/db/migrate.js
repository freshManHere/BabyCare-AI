import 'dotenv/config';
import pool from './index.js';

const SQL = `
-- Users
CREATE TABLE IF NOT EXISTS users (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email       TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Refresh tokens
CREATE TABLE IF NOT EXISTS refresh_tokens (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  TEXT UNIQUE NOT NULL,
  expires_at  TIMESTAMPTZ NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Babies
CREATE TABLE IF NOT EXISTS babies (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  nickname    TEXT NOT NULL,
  birthday    DATE NOT NULL,
  gender      TEXT NOT NULL CHECK (gender IN ('男', '女', '未知')),
  avatar_url  TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Baby events
CREATE TABLE IF NOT EXISTS baby_events (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  baby_id     UUID NOT NULL REFERENCES babies(id) ON DELETE CASCADE,
  label       TEXT NOT NULL,
  start_time  TIMESTAMPTZ NOT NULL,
  end_time    TIMESTAMPTZ,
  payload     JSONB NOT NULL DEFAULT '{}',
  note        TEXT NOT NULL DEFAULT '',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at  TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS baby_events_baby_time ON baby_events(baby_id, start_time DESC);
CREATE INDEX IF NOT EXISTS baby_events_updated ON baby_events(baby_id, updated_at DESC);

-- Growth records
CREATE TABLE IF NOT EXISTS growth_records (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  baby_id     UUID NOT NULL REFERENCES babies(id) ON DELETE CASCADE,
  date        DATE NOT NULL,
  weight_kg   NUMERIC(5,3),
  height_cm   NUMERIC(5,1),
  head_cm     NUMERIC(5,1),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(baby_id, date)
);
`;

async function migrate() {
  const client = await pool.connect();
  try {
    await client.query(SQL);
    console.log('[migrate] ✓ All tables created / verified');
  } finally {
    client.release();
    await pool.end();
  }
}

migrate().catch(err => { console.error('[migrate] Failed:', err); process.exit(1); });
