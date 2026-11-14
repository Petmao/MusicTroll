'use strict';
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const Database = require('better-sqlite3');
const jwt = require('jsonwebtoken');

const ROOT = __dirname;
const DATA = process.env.DATA_DIR || path.join(ROOT, 'data');
fs.mkdirSync(DATA, { recursive: true });

const C = {
  port: Number(process.env.PORT || 8787),
  secret: process.env.JWT_SECRET || crypto.randomBytes(32).toString('hex'),
  adminAccount: process.env.ADMIN_ACCOUNT || 'admin',
  adminPassword: process.env.ADMIN_PASSWORD || 'change-me',
  codePrefix: process.env.CODE_PREFIX || 'MT',
  deviceLimit: Number(process.env.DEVICE_LIMIT || 5),
  unbindCooldownHours: Number(process.env.UNBIND_COOLDOWN_HOURS || 168),
  invitePoints: Number(process.env.INVITE_POINTS || 200),
  checkinPoints: Number(process.env.CHECKIN_POINTS || 30),
  casdoor: {
    enabled: process.env.CASDOOR_ENABLED === '1',
    endpoint: (process.env.CASDOOR_ENDPOINT || '').replace(/\/+$/, ''),
    clientId: process.env.CASDOOR_CLIENT_ID || '',
    clientSecret: process.env.CASDOOR_CLIENT_SECRET || '',
    org: process.env.CASDOOR_ORG || 'built-in',
    app: process.env.CASDOOR_APP || 'app-built-in',
    redirect: process.env.CASDOOR_REDIRECT || 'isle://auth'
  }
};

const db = new Database(path.join(DATA, 'isle.db'));
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

db.exec(`
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  account TEXT UNIQUE NOT NULL,
  nickname TEXT NOT NULL,
  pass_hash TEXT,
  phone TEXT,
  email TEXT,
  avatar TEXT,
  role TEXT NOT NULL DEFAULT 'free',
  role_expire_at INTEGER,
  invite_code TEXT UNIQUE,
  invited_by INTEGER,
  status TEXT NOT NULL DEFAULT 'active',
  note TEXT,
  max_devices INTEGER,
  casdoor_sub TEXT UNIQUE,
  created_at INTEGER NOT NULL,
  last_login_at INTEGER
);
CREATE TABLE IF NOT EXISTS codes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT UNIQUE NOT NULL,
  role TEXT NOT NULL,
  days INTEGER NOT NULL,
  batch TEXT NOT NULL,
  note TEXT,
  used_by INTEGER,
  used_at INTEGER,
  created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS orders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  kind TEXT NOT NULL,
  ref TEXT,
  role TEXT NOT NULL,
  days INTEGER NOT NULL,
  amount_cents INTEGER NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'CNY',
  status TEXT NOT NULL DEFAULT 'paid',
  channel TEXT,
  created_at INTEGER NOT NULL,
  refunded_at INTEGER
);
CREATE TABLE IF NOT EXISTS entitlements (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  can_play_music INTEGER NOT NULL DEFAULT 0,
  can_use_video INTEGER NOT NULL DEFAULT 0,
  can_manage_sources INTEGER NOT NULL DEFAULT 0,
  expires_at INTEGER,
  source TEXT,
  created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS points (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  delta INTEGER NOT NULL,
  reason TEXT,
  ref TEXT,
  created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS checkins (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  day TEXT NOT NULL,
  streak INTEGER NOT NULL DEFAULT 1,
  points INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  UNIQUE(user_id, day)
);
CREATE TABLE IF NOT EXISTS devices (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  device_id TEXT NOT NULL,
  name TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  grace_until INTEGER,
  revoked_at INTEGER,
  last_seen_at INTEGER,
  created_at INTEGER NOT NULL,
  UNIQUE(user_id, device_id)
);
CREATE TABLE IF NOT EXISTS sources (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kind TEXT NOT NULL,
  name TEXT NOT NULL,
  url TEXT NOT NULL,
  method TEXT NOT NULL DEFAULT 'GET',
  headers TEXT,
  params TEXT,
  result_path TEXT,
  note TEXT,
  enabled INTEGER NOT NULL DEFAULT 1,
  sort INTEGER NOT NULL DEFAULT 0,
  last_status INTEGER,
  last_ms INTEGER,
  checked_at INTEGER,
  created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS api_keys (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  key TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  scopes TEXT NOT NULL DEFAULT 'sources:read',
  enabled INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL,
  last_used_at INTEGER
);
CREATE TABLE IF NOT EXISTS audit (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER,
  action TEXT NOT NULL,
  detail TEXT,
  ip TEXT,
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_orders_user ON orders(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_points_user ON points(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ent_user ON entitlements(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sources_kind ON sources(kind, enabled, sort);
`);

const now = () => Math.floor(Date.now() / 1000);
const dayKey = (t) => new Date((t || now()) * 1000).toISOString().slice(0, 10);
const uid = (n) => crypto.randomBytes(n || 6).toString('hex').toUpperCase();

const RANK = { free: 0, vip: 1, svip: 2 };

function roleOf(user) {
  if (!user) return 'free';
  if (user.role === 'free') return 'free';
  if (!user.role_expire_at) return user.role;
  return user.role_expire_at > now() ? user.role : 'free';
}

function entOf(user) {
  const r = roleOf(user);
  return {
    role: r,
    canPlayMusic: RANK[r] >= 1,
    canUseVideo: RANK[r] >= 2,
    canManageSources: RANK[r] >= 2
  };
}

function snapshotEnt(userId, source) {
  const u = db.prepare('SELECT * FROM users WHERE id=?').get(userId);
  const e = entOf(u);
  db.prepare(`INSERT INTO entitlements
    (user_id, can_play_music, can_use_video, can_manage_sources, expires_at, source, created_at)
    VALUES (?,?,?,?,?,?,?)`).run(
    userId,
    e.canPlayMusic ? 1 : 0,
    e.canUseVideo ? 1 : 0,
    e.canManageSources ? 1 : 0,
    u ? u.role_expire_at : null,
    source || null,
    now()
  );
}

function balanceOf(userId) {
  const r = db.prepare('SELECT COALESCE(SUM(delta),0) AS b FROM points WHERE user_id=?').get(userId);
  return r ? r.b : 0;
}

function addPoints(userId, delta, reason, ref) {
  db.prepare('INSERT INTO points (user_id,delta,reason,ref,created_at) VALUES (?,?,?,?,?)')
    .run(userId, delta, reason || '', ref || '', now());
}

function audit(userId, action, detail, ip) {
  try {
    db.prepare('INSERT INTO audit (user_id,action,detail,ip,created_at) VALUES (?,?,?,?,?)')
      .run(userId || null, action, String(detail || '').slice(0, 300), ip || '', now());
  } catch (_) {}
}

function publicUser(u) {
  if (!u) return null;
  const effective = roleOf(u);
  return {
    id: u.id,
    account: u.account,
    nickname: u.nickname,
    avatar: u.avatar || null,
    role: effective,
    roleExpireAt: u.role_expire_at || null,
    phoneMasked: u.phone ? String(u.phone).replace(/^(\d{3})\d+(\d{4})$/, '$1****$2') : null,
    status: u.status,
    inviteCode: u.invite_code || null,
    points: balanceOf(u.id)
  };
}

function signToken(user, hours) {
  return jwt.sign({ uid: user.id, adm: false }, C.secret, { expiresIn: (hours || 720) + 'h' });
}

function signAdmin() {
  return jwt.sign({ adm: true }, C.secret, { expiresIn: '12h' });
}

function verifyToken(t) {
  try { return jwt.verify(t, C.secret); } catch (_) { return null; }
}

function newInviteCode() {
  let code;
  do { code = 'IS' + uid(3).slice(0, 6); }
  while (db.prepare('SELECT 1 FROM users WHERE invite_code=?').get(code));
  return code;
}

function newCode(prefix) {
  return (prefix || C.codePrefix) + '-' + uid(6);
}

async function fetchJson(url, opt) {
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), (opt && opt.timeout) || 12000);
  const started = Date.now();
  try {
    const res = await fetch(url, Object.assign({}, opt, { signal: ctl.signal }));
    const text = await res.text();
    let json = null;
    try { json = JSON.parse(text); } catch (_) {}
    return { ok: res.ok, status: res.status, json: json, text: text, ms: Date.now() - started };
  } catch (e) {
    return { ok: false, status: 0, json: null, text: String(e.message || e), ms: Date.now() - started };
  } finally {
    clearTimeout(timer);
  }
}

const casdoor = {
  authorizeUrl(state) {
    if (!C.casdoor.enabled) return null;
    const p = new URLSearchParams({
      client_id: C.casdoor.clientId,
      response_type: 'code',
      redirect_uri: C.casdoor.redirect,
      scope: 'read',
      state: state || uid(4),
      type: 'code'
    });
    return C.casdoor.endpoint + '/login/oauth/authorize?' + p.toString();
  },

  async exchange(code) {
    if (!C.casdoor.enabled) throw new Error('casdoor_disabled');
    const tokenUrl = C.casdoor.endpoint + '/api/login/oauth/access_token';
    const body = new URLSearchParams({
      grant_type: 'authorization_code',
      client_id: C.casdoor.clientId,
      client_secret: C.casdoor.clientSecret,
      code: code
    });
    const r = await fetchJson(tokenUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString()
    });
    if (!r.ok || !r.json || !r.json.access_token) {
      throw new Error('casdoor_token_failed');
    }
    const info = await fetchJson(C.casdoor.endpoint + '/api/userinfo', {
      headers: { Authorization: 'Bearer ' + r.json.access_token }
    });
    if (!info.ok || !info.json) throw new Error('casdoor_userinfo_failed');
    const d = info.json;
    return {
      sub: String(d.sub || d.id || d.name || ''),
      name: d.name || d.displayName || d.preferred_username || 'casdoor user',
      email: d.email || null,
      avatar: d.avatar || null
    };
  }
};

module.exports = {
  C, db, now, dayKey, uid, RANK, ROOT, DATA,
  roleOf, entOf, snapshotEnt, balanceOf, addPoints, audit, publicUser,
  signToken, signAdmin, verifyToken, newInviteCode, newCode, fetchJson, casdoor
};
