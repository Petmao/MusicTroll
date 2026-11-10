'use strict';
const fs = require('fs');
const path = require('path');
const Database = require('better-sqlite3');

const file = process.env.DB_PATH || './data/data.db';
fs.mkdirSync(path.dirname(file), { recursive: true });
const db = new Database(file);
db.pragma('journal_mode = WAL');

db.exec(`
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  account TEXT NOT NULL,
  account_key TEXT NOT NULL UNIQUE,
  nickname TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  phone_mask TEXT DEFAULT '',
  phone_enc TEXT DEFAULT '',
  avatar TEXT DEFAULT '',
  role TEXT NOT NULL DEFAULT 'free',
  role_expire_at INTEGER,
  status TEXT NOT NULL DEFAULT 'active',
  max_devices INTEGER,
  invite_code TEXT,
  invited_by INTEGER,
  note TEXT DEFAULT '',
  created_at INTEGER NOT NULL,
  last_login_at INTEGER
);
CREATE TABLE IF NOT EXISTS codes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT UNIQUE NOT NULL,
  role TEXT NOT NULL,
  days INTEGER NOT NULL,
  used_by INTEGER,
  used_at INTEGER,
  batch TEXT,
  created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS devices (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  device_id TEXT NOT NULL,
  name TEXT DEFAULT '',
  key_enc TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  grace_until INTEGER,
  revoked_at INTEGER,
  unbind_reason TEXT DEFAULT '',
  created_at INTEGER NOT NULL,
  last_seen_at INTEGER,
  UNIQUE(user_id, device_id)
);
CREATE TABLE IF NOT EXISTS points (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  delta INTEGER NOT NULL,
  reason TEXT NOT NULL,
  ref TEXT DEFAULT '',
  created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS checkins (
  user_id INTEGER NOT NULL,
  day TEXT NOT NULL,
  streak INTEGER NOT NULL,
  points INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (user_id, day)
);
CREATE TABLE IF NOT EXISTS invites (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL,
  inviter_id INTEGER NOT NULL,
  invitee_id INTEGER,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at INTEGER NOT NULL,
  redeemed_at INTEGER
);
CREATE TABLE IF NOT EXISTS cloud_playlists (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  pid TEXT NOT NULL,
  name TEXT NOT NULL,
  cover TEXT DEFAULT '',
  songs TEXT NOT NULL,
  rev INTEGER NOT NULL DEFAULT 1,
  updated_at INTEGER NOT NULL,
  deleted INTEGER NOT NULL DEFAULT 0,
  UNIQUE(user_id, pid)
);
CREATE TABLE IF NOT EXISTS progress (
  user_id INTEGER NOT NULL,
  track_key TEXT NOT NULL,
  position_ms INTEGER NOT NULL,
  duration_ms INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (user_id, track_key)
);
CREATE TABLE IF NOT EXISTS config (key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at INTEGER);
CREATE TABLE IF NOT EXISTS audit (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER, action TEXT NOT NULL, detail TEXT, ip TEXT, created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_codes_unused ON codes(used_by);
CREATE INDEX IF NOT EXISTS idx_points_user ON points(user_id);
`);

module.exports = db;
