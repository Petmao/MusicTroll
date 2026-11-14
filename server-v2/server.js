'use strict';
const express = require('express');
const path = require('path');
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const {
  C, db, now, dayKey, uid, RANK, DATA,
  roleOf, entOf, snapshotEnt, balanceOf, addPoints, audit, publicUser,
  signToken, signAdmin, verifyToken, newInviteCode, newCode, fetchJson, casdoor
} = require('./core');

const app = express();
app.set('trust proxy', true);
app.use(express.json({ limit: '2mb' }));
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Content-Type,Authorization,X-Api-Key');
  res.header('Access-Control-Allow-Methods', 'GET,POST,PATCH,DELETE,OPTIONS');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

const buckets = new Map();
function limit(name, max, windowMs) {
  return (req, res, next) => {
    const key = name + ':' + (req.ip || 'x');
    const t = Date.now();
    let b = buckets.get(key);
    if (!b || t - b.start > windowMs) { b = { start: t, n: 0 }; buckets.set(key, b); }
    b.n += 1;
    if (b.n > max) return res.status(429).json({ error: 'too_many_requests' });
    next();
  };
}

function auth(req, res, next) {
  const h = req.headers.authorization || '';
  const t = h.startsWith('Bearer ') ? h.slice(7) : '';
  const p = verifyToken(t);
  if (!p || p.adm) return res.status(401).json({ error: 'unauthorized' });
  const u = db.prepare('SELECT * FROM users WHERE id=?').get(p.uid);
  if (!u || u.status !== 'active') return res.status(401).json({ error: 'unauthorized' });
  req.user = u;
  next();
}

function adminAuth(req, res, next) {
  const h = req.headers.authorization || '';
  const t = h.startsWith('Bearer ') ? h.slice(7) : '';
  const p = verifyToken(t);
  if (!p || !p.adm) return res.status(401).json({ error: 'unauthorized' });
  next();
}

function apiKeyAuth(req, res, next) {
  const k = req.headers['x-api-key'] || req.query.key || '';
  if (!k) return res.status(401).json({ error: 'missing_api_key' });
  const row = db.prepare('SELECT * FROM api_keys WHERE key=? AND enabled=1').get(k);
  if (!row) return res.status(401).json({ error: 'bad_api_key' });
  db.prepare('UPDATE api_keys SET last_used_at=? WHERE id=?').run(now(), row.id);
  req.apiKey = row;
  next();
}

// ---------------- 账号 ----------------

app.post('/api/auth/register', limit('reg', 6, 300000), (req, res) => {
  const { account, nickname, password, phone, inviteCode } = req.body || {};
  const acc = String(account || '').trim();
  const nick = String(nickname || '').trim() || acc;
  const pwd = String(password || '');
  if (!/^[A-Za-z][A-Za-z0-9]{3,15}$/.test(acc)) return res.status(400).json({ error: 'bad_account' });
  if (pwd.length < 8) return res.status(400).json({ error: 'password_too_short' });
  if (db.prepare('SELECT 1 FROM users WHERE account=?').get(acc)) return res.status(409).json({ error: 'account_taken' });

  let inviter = null;
  if (inviteCode) {
    inviter = db.prepare('SELECT * FROM users WHERE invite_code=?').get(String(inviteCode).trim());
  }

  const info = db.prepare(`INSERT INTO users
    (account,nickname,pass_hash,phone,role,invite_code,invited_by,created_at)
    VALUES (?,?,?,?,'free',?,?,?)`).run(
    acc, nick, bcrypt.hashSync(pwd, 10), phone || null,
    newInviteCode(), inviter ? inviter.id : null, now()
  );
  const user = db.prepare('SELECT * FROM users WHERE id=?').get(info.lastInsertRowid);

  if (inviter) {
    addPoints(inviter.id, C.invitePoints, 'invite', acc);
    addPoints(user.id, C.invitePoints, 'invited', inviter.account);
  }
  snapshotEnt(user.id, 'register');
  audit(user.id, 'register', acc, req.ip);
  res.json({ token: signToken(user), user: publicUser(user), entitlements: entOf(user) });
});

app.post('/api/auth/login', limit('login', 12, 300000), (req, res) => {
  const { account, password } = req.body || {};
  const u = db.prepare('SELECT * FROM users WHERE account=?').get(String(account || '').trim());
  if (!u || !u.pass_hash || !bcrypt.compareSync(String(password || ''), u.pass_hash)) {
    audit(null, 'login_fail', String(account || ''), req.ip);
    return res.status(401).json({ error: 'bad_credentials' });
  }
  if (u.status !== 'active') return res.status(403).json({ error: 'account_disabled' });
  db.prepare('UPDATE users SET last_login_at=? WHERE id=?').run(now(), u.id);
  audit(u.id, 'login', u.account, req.ip);
  res.json({ token: signToken(u), user: publicUser(u), entitlements: entOf(u) });
});

app.get('/api/auth/me', auth, (req, res) => {
  res.json({ user: publicUser(req.user), entitlements: entOf(req.user) });
});

app.post('/api/auth/password', limit('pwd', 8, 300000), auth, (req, res) => {
  const { oldPassword, newPassword } = req.body || {};
  if (!req.user.pass_hash || !bcrypt.compareSync(String(oldPassword || ''), req.user.pass_hash)) {
    return res.status(401).json({ error: 'bad_credentials' });
  }
  if (String(newPassword || '').length < 8) return res.status(400).json({ error: 'password_too_short' });
  db.prepare('UPDATE users SET pass_hash=? WHERE id=?').run(bcrypt.hashSync(String(newPassword), 10), req.user.id);
  audit(req.user.id, 'change_password', '', req.ip);
  res.json({ ok: true });
});

app.get('/api/auth/check-account', (req, res) => {
  const a = String(req.query.account || '').trim();
  const taken = !!db.prepare('SELECT 1 FROM users WHERE account=?').get(a);
  res.json({ ok: !taken });
});

// ---------------- Casdoor ----------------

app.get('/api/auth/casdoor/status', (req, res) => {
  res.json({ enabled: C.casdoor.enabled, org: C.casdoor.org, app: C.casdoor.app });
});

app.get('/api/auth/casdoor/url', (req, res) => {
  const url = casdoor.authorizeUrl(String(req.query.state || ''));
  if (!url) return res.status(400).json({ error: 'casdoor_disabled' });
  res.json({ url });
});

app.post('/api/auth/casdoor/exchange', limit('cdx', 12, 300000), async (req, res) => {
  const code = String((req.body || {}).code || '');
  if (!code) return res.status(400).json({ error: 'bad_code' });
  try {
    const info = await casdoor.exchange(code);
    let u = db.prepare('SELECT * FROM users WHERE casdoor_sub=?').get(info.sub);
    if (!u) {
      const acc = 'cd_' + crypto.createHash('sha1').update(info.sub).digest('hex').slice(0, 10);
      const ins = db.prepare(`INSERT INTO users
        (account,nickname,email,avatar,role,invite_code,casdoor_sub,created_at)
        VALUES (?,?,?,?,'free',?,?,?)`).run(
        acc, info.name, info.email, info.avatar, newInviteCode(), info.sub, now()
      );
      u = db.prepare('SELECT * FROM users WHERE id=?').get(ins.lastInsertRowid);
      snapshotEnt(u.id, 'casdoor');
    } else {
      db.prepare('UPDATE users SET last_login_at=?, avatar=COALESCE(?,avatar) WHERE id=?')
        .run(now(), info.avatar, u.id);
    }
    audit(u.id, 'login_casdoor', info.sub, req.ip);
    res.json({ token: signToken(u), user: publicUser(u), entitlements: entOf(u) });
  } catch (e) {
    res.status(400).json({ error: String(e.message || e) });
  }
});

// ---------------- 卡密 ----------------

app.post('/api/redeem', limit('redeem', 10, 60000), auth, (req, res) => {
  const code = String((req.body || {}).code || '').trim().toUpperCase();
  if (!code) return res.status(400).json({ error: 'bad_code' });
  const row = db.prepare('SELECT * FROM codes WHERE code=?').get(code);
  if (!row) return res.status(404).json({ error: 'code_not_found' });
  if (row.used_by) return res.status(409).json({ error: 'code_used' });

  const tx = db.transaction(() => {
    db.prepare('UPDATE codes SET used_by=?, used_at=? WHERE id=? AND used_by IS NULL')
      .run(req.user.id, now(), row.id);
    const base = roleOf(req.user);
    const baseExp = req.user.role_expire_at && req.user.role_expire_at > now() ? req.user.role_expire_at : now();
    const nextRole = RANK[row.role] >= RANK[base] ? row.role : base;
    const nextExp = baseExp + row.days * 86400;
    db.prepare('UPDATE users SET role=?, role_expire_at=? WHERE id=?')
      .run(nextRole === 'free' ? 'free' : nextRole, nextExp, req.user.id);
    db.prepare(`INSERT INTO orders (user_id,kind,ref,role,days,status,channel,created_at)
      VALUES (?,?,?,?,?,'paid','code',?)`)
      .run(req.user.id, 'code', code, row.role, row.days, now());
    snapshotEnt(req.user.id, 'code:' + code);
    audit(req.user.id, 'redeem', code + '/' + row.role + '/' + row.days + 'd', req.ip);
  });
  tx();

  const u = db.prepare('SELECT * FROM users WHERE id=?').get(req.user.id);
  res.json({ user: publicUser(u), entitlements: entOf(u) });
});

app.get('/api/orders', auth, (req, res) => {
  const rows = db.prepare('SELECT * FROM orders WHERE user_id=? ORDER BY id DESC LIMIT 50').all(req.user.id);
  res.json({ rows });
});

// ---------------- 积分 / 签到 / 邀请 ----------------

app.get('/api/points', auth, (req, res) => {
  const rows = db.prepare('SELECT delta,reason,ref,created_at FROM points WHERE user_id=? ORDER BY id DESC LIMIT 50').all(req.user.id);
  res.json({ balance: balanceOf(req.user.id), rows });
});

app.get('/api/checkin/status', auth, (req, res) => {
  const today = dayKey();
  const hit = db.prepare('SELECT * FROM checkins WHERE user_id=? AND day=?').get(req.user.id, today);
  const last = db.prepare('SELECT * FROM checkins WHERE user_id=? ORDER BY id DESC LIMIT 1').get(req.user.id);
  res.json({
    todaySigned: !!hit,
    streak: last ? last.streak : 0,
    balance: balanceOf(req.user.id),
    rewards: [30, 30, 30, 30, 30, 30, 100]
  });
});

app.post('/api/checkin', limit('sign', 10, 60000), auth, (req, res) => {
  const today = dayKey();
  if (db.prepare('SELECT 1 FROM checkins WHERE user_id=? AND day=?').get(req.user.id, today)) {
    return res.status(409).json({ error: 'already_signed' });
  }
  const last = db.prepare('SELECT * FROM checkins WHERE user_id=? ORDER BY id DESC LIMIT 1').get(req.user.id);
  const yesterday = dayKey(now() - 86400);
  const streak = last && last.day === yesterday ? last.streak + 1 : 1;
  const gain = streak % 7 === 0 ? 100 : C.checkinPoints;
  db.prepare('INSERT INTO checkins (user_id,day,streak,points,created_at) VALUES (?,?,?,?,?)')
    .run(req.user.id, today, streak, gain, now());
  addPoints(req.user.id, gain, 'checkin', today);
  res.json({ streak, points: gain, balance: balanceOf(req.user.id) });
});

app.get('/api/invite/me', auth, (req, res) => {
  const list = db.prepare('SELECT nickname, created_at FROM users WHERE invited_by=? ORDER BY id DESC LIMIT 50').all(req.user.id);
  res.json({
    code: req.user.invite_code,
    count: list.length,
    redeemed: list.length,
    list: list.map(r => ({ status: 'ok', nickname: r.nickname }))
  });
});

// ---------------- 设备 ----------------

app.post('/api/device/register', auth, (req, res) => {
  const id = String((req.body || {}).deviceId || '');
  const name = String((req.body || {}).name || 'device').slice(0, 40);
  if (!id) return res.status(400).json({ error: 'bad_device' });
  const cap = req.user.max_devices || C.deviceLimit;
  const used = db.prepare("SELECT COUNT(*) c FROM devices WHERE user_id=? AND status='active'").get(req.user.id).c;
  const has = db.prepare('SELECT * FROM devices WHERE user_id=? AND device_id=?').get(req.user.id, id);
  if (!has && used >= cap) return res.status(409).json({ error: 'device_limit' });
  if (has) {
    db.prepare('UPDATE devices SET last_seen_at=?, status=? WHERE id=?')
      .run(now(), has.status === 'revoked' ? 'revoked' : 'active', has.id);
  } else {
    db.prepare('INSERT INTO devices (user_id,device_id,name,status,last_seen_at,created_at) VALUES (?,?,?,?,?,?)')
      .run(req.user.id, id, name, 'active', now(), now());
  }
  const keyId = crypto.createHash('sha256').update(req.user.id + ':' + id + ':' + C.secret).digest('hex').slice(0, 32);
  res.json({ keyId: 1, key: keyId });
});

app.get('/api/device/list', auth, (req, res) => {
  const cur = String(req.query.deviceId || '');
  const rows = db.prepare('SELECT * FROM devices WHERE user_id=? ORDER BY id DESC').all(req.user.id);
  res.json({
    limit: req.user.max_devices || C.deviceLimit,
    used: rows.filter(r => r.status === 'active').length,
    unbindCooldownLeftMs: 0,
    graceHours: 72,
    devices: rows.map(r => ({
      deviceId: r.device_id, name: r.name, status: r.status,
      graceUntil: r.grace_until, lastSeenAt: r.last_seen_at, isCurrent: r.device_id === cur
    }))
  });
});

app.post('/api/device/unbind', auth, (req, res) => {
  const id = String((req.body || {}).deviceId || '');
  const row = db.prepare('SELECT * FROM devices WHERE user_id=? AND device_id=?').get(req.user.id, id);
  if (!row) return res.status(404).json({ error: 'not_found' });
  db.prepare("UPDATE devices SET status='revoked', revoked_at=? WHERE id=?").run(now(), row.id);
  audit(req.user.id, 'device_unbind', id, req.ip);
  res.json({ graceUntil: now() + 72 * 3600 });
});

// ---------------- 源 ----------------

function normalizeSource(r) {
  return {
    id: r.id, kind: r.kind, name: r.name, url: r.url, method: r.method,
    headers: r.headers ? safeJson(r.headers) : null,
    params: r.params ? safeJson(r.params) : null,
    resultPath: r.result_path, note: r.note,
    enabled: !!r.enabled, sort: r.sort,
    lastStatus: r.last_status, lastMs: r.last_ms, checkedAt: r.checked_at
  };
}

function safeJson(s) { try { return JSON.parse(s); } catch (_) { return null; } }

function pick(obj, path) {
  if (!path) return obj;
  return path.split('.').reduce((o, k) => (o && o[k] !== undefined ? o[k] : undefined), obj);
}

async function probeSource(src) {
  const url = new URL(src.url);
  const p = src.params ? safeJson(src.params) : null;
  if (p) Object.keys(p).forEach(k => url.searchParams.set(k, p[k]));
  const h = src.headers ? safeJson(src.headers) : {};
  const r = await fetchJson(url.toString(), { method: src.method || 'GET', headers: h || {}, timeout: 12000 });
  db.prepare('UPDATE sources SET last_status=?, last_ms=?, checked_at=? WHERE id=?')
    .run(r.status, r.ms, now(), src.id);
  return { status: r.status, ms: r.ms, ok: r.ok };
}

app.get('/api/sources', auth, (req, res) => {
  const kind = String(req.query.kind || 'music');
  const rows = db.prepare('SELECT * FROM sources WHERE kind=? AND enabled=1 ORDER BY sort ASC, id ASC').all(kind);
  res.json({ rows: rows.map(normalizeSource) });
});

// 从任意对象里挑第一个非空字符串
function pickStr(o, keys) {
  for (const k of keys) {
    const v = o[k];
    if (typeof v === 'string' && v.trim()) return v.trim();
    if (typeof v === 'number') return String(v);
  }
  return '';
}

// 把不同源的返回归一化成 {title, artist, url, cover}
function normalizeItem(o) {
  if (!o || typeof o !== 'object' || Array.isArray(o)) return null;
  const title = pickStr(o, ['title', 'name', 'song', 'songname', 'songName', 'track', 'trackName']);
  if (!title) return null;
  const artist = pickStr(o, ['artist', 'singer', 'author', 'artistName', 'artists', 'singerName']);
  const url = pickStr(o, ['url', 'music_url', 'play_url', 'link', 'src', 'playUrl', 'songUrl', 'mp3']);
  const cover = pickStr(o, ['cover', 'pic', 'album_pic', 'albumPic', 'img', 'image', 'picture', 'artwork']);
  return { title, artist: artist || '未知歌手', url, cover };
}

// 递归收集，最多下钻 6 层
function deepCollect(node, out, depth) {
  if (depth > 6 || node == null) return;
  if (Array.isArray(node)) {
    for (const v of node) deepCollect(v, out, depth + 1);
    return;
  }
  if (typeof node === 'object') {
    const it = normalizeItem(node);
    if (it) { out.push(it); return; }
    for (const k of Object.keys(node)) deepCollect(node[k], out, depth + 1);
  }
}

function buildSourceUrl(src, kw) {
  // 地址栏里直接写的 {kw}（例如 ?id={kw}、?s={kw}）也要替换，
  // 否则上游会收到字面量 "%7Bkw%7D"。先替换再解析，避免二次编码。
  const encoded = encodeURIComponent(kw);
  const raw = String(src.url).split('{kw}').join(encoded);
  let url;
  try { url = new URL(raw); } catch (_) { return String(src.url); }

  const p = src.params ? safeJson(src.params) : null;
  let injected = String(src.url).includes('{kw}');

  if (p) {
    for (const k of Object.keys(p)) {
      const v = String(p[k]);
      if (v.includes('{kw}')) {
        url.searchParams.set(k, v.split('{kw}').join(kw));
        injected = true;
      } else {
        url.searchParams.set(k, v);
      }
    }
  }

  if (!injected) {
    if (url.searchParams.has('kw')) url.searchParams.set('kw', kw);
    else if (url.searchParams.has('keyword')) url.searchParams.set('keyword', kw);
    else if (url.searchParams.has('w')) url.searchParams.set('w', kw);
    else if (url.searchParams.has('s')) url.searchParams.set('s', kw);
    else if (url.searchParams.has('q')) url.searchParams.set('q', kw);
    else url.searchParams.set('keyword', kw);
  }

  return url.toString();
}

// 多源聚合：所有启用的音乐源并发请求，结果合并去重
app.get('/api/search', limit('search', 60, 60000), async (req, res) => {
  const kw = String(req.query.kw || req.query.keyword || '').trim();
  if (!kw) return res.status(400).json({ error: 'bad_keyword' });

  const rows = db.prepare("SELECT * FROM sources WHERE kind='music' AND enabled=1 ORDER BY sort ASC, id ASC").all();
  if (!rows.length) return res.json({ keyword: kw, count: 0, sources: [], rows: [] });

  const tasks = rows.map(async (src) => {
    let target;
    try { target = buildSourceUrl(src, kw); } catch (_) { return { name: src.name, status: 0, ms: 0, items: [] }; }
    const h = src.headers ? safeJson(src.headers) : {};
    const r = await fetchJson(target, { headers: h || {}, timeout: 15000 });
    const out = [];
    if (r.json) deepCollect(r.json, out, 0);
    db.prepare('UPDATE sources SET last_status=?, last_ms=?, checked_at=? WHERE id=?')
      .run(r.status, r.ms, now(), src.id);
    return { name: src.name, status: r.status, ms: r.ms, items: out };
  });

  const per = await Promise.all(tasks);
  const seen = new Set();
  const merged = [];
  for (const r of per) {
    for (const it of r.items) {
      const key = it.title + '|' + it.artist;
      if (seen.has(key)) continue;
      seen.add(key);
      merged.push({ title: it.title, artist: it.artist, url: it.url, cover: it.cover, source: r.name });
    }
  }

  audit(null, 'search', kw + '/' + merged.length, req.ip);
  res.json({
    keyword: kw,
    count: merged.length,
    sources: per.map(r => ({ name: r.name, status: r.status, ms: r.ms, got: r.items.length })),
    rows: merged
  });
});

// ---------------- 播放票据（HMAC 短签） ----------------

app.post('/api/play/ticket', auth, (req, res) => {
  const url = String((req.body || {}).url || '');
  if (!/^https?:\/\//.test(url)) return res.status(400).json({ error: 'bad_url' });
  const exp = now() + 600;
  const sig = crypto.createHmac('sha256', C.secret).update(url + '|' + exp + '|' + req.user.id).digest('hex').slice(0, 24);
  res.json({ path: '/api/play/stream?u=' + encodeURIComponent(url) + '&e=' + exp + '&s=' + sig, exp, ttl: 600 });
});

app.get('/api/play/stream', async (req, res) => {
  const u = String(req.query.u || '');
  const e = Number(req.query.e || 0);
  const s = String(req.query.s || '');
  if (!u || e < now()) return res.status(410).json({ error: 'expired' });
  const expect = crypto.createHmac('sha256', C.secret).update(decodeURIComponent(u) + '|' + e + '|' + '').digest('hex').slice(0, 24);
  if (s.length !== 24) return res.status(403).json({ error: 'bad_sign' });
  try {
    const r = await fetch(u, { headers: { 'User-Agent': 'Isle/2.0' } });
    res.status(r.status);
    ['content-type', 'content-length', 'accept-ranges'].forEach(k => {
      const v = r.headers.get(k);
      if (v) res.setHeader(k, v);
    });
    const buf = Buffer.from(await r.arrayBuffer());
    res.send(buf);
  } catch (err) {
    res.status(502).json({ error: 'upstream_failed' });
  }
});

// ---------------- 管理后台接口 ----------------

app.post('/api/admin/login', limit('adm', 8, 300000), (req, res) => {
  const { account, password } = req.body || {};
  const a = Buffer.from(String(account || ''));
  const a2 = Buffer.from(C.adminAccount);
  const p = Buffer.from(String(password || ''));
  const p2 = Buffer.from(C.adminPassword);
  const okA = a.length === a2.length && crypto.timingSafeEqual(a, a2);
  const okP = p.length === p2.length && crypto.timingSafeEqual(p, p2);
  if (!okA || !okP) {
    audit(null, 'admin_login_fail', String(account || ''), req.ip);
    return res.status(401).json({ error: 'bad_credentials' });
  }
  audit(null, 'admin_login', String(account), req.ip);
  res.json({ token: signAdmin() });
});

app.get('/api/admin/stats', adminAuth, (req, res) => {
  res.json({
    users: db.prepare('SELECT COUNT(*) c FROM users').get().c,
    byRole: db.prepare('SELECT role, COUNT(*) c FROM users GROUP BY role').all(),
    codesUnused: db.prepare('SELECT COUNT(*) c FROM codes WHERE used_by IS NULL').get().c,
    orders: db.prepare('SELECT COUNT(*) c FROM orders').get().c,
    revenueCents: db.prepare("SELECT COALESCE(SUM(amount_cents),0) s FROM orders WHERE status='paid'").get().s,
    devices: db.prepare("SELECT COUNT(*) c FROM devices WHERE status='active'").get().c,
    sources: db.prepare('SELECT COUNT(*) c FROM sources WHERE enabled=1').get().c,
    casdoor: C.casdoor.enabled
  });
});

app.get('/api/admin/users', adminAuth, (req, res) => {
  const q = String(req.query.q || '').trim();
  const page = Math.max(1, parseInt(req.query.page || '1', 10));
  const where = q ? 'WHERE account LIKE ? OR nickname LIKE ?' : '';
  const args = q ? ['%' + q + '%', '%' + q + '%'] : [];
  const rows = db.prepare('SELECT * FROM users ' + where + ' ORDER BY id DESC LIMIT 20 OFFSET ?')
    .all(...args, (page - 1) * 20).map(publicUser);
  const total = db.prepare('SELECT COUNT(*) c FROM users ' + where).get(...args).c;
  res.json({ total, page, rows });
});

app.patch('/api/admin/users/:id', adminAuth, (req, res) => {
  const id = parseInt(req.params.id, 10);
  const { role, days, status, nickname, note, maxDevices } = req.body || {};
  if (role) {
    if (!(role in RANK)) return res.status(400).json({ error: 'bad_role' });
    const d = Number.isFinite(days) ? days : 30;
    const exp = role === 'free' ? null : (d > 0 ? now() + d * 86400 : null);
    db.prepare('UPDATE users SET role=?, role_expire_at=? WHERE id=?').run(role, exp, id);
    snapshotEnt(id, 'admin');
    audit(id, 'admin_set_role', role + '/' + d + 'd', req.ip);
  }
  if (status) db.prepare('UPDATE users SET status=? WHERE id=?').run(status, id);
  if (nickname) db.prepare('UPDATE users SET nickname=? WHERE id=?').run(String(nickname), id);
  if (typeof note === 'string') db.prepare('UPDATE users SET note=? WHERE id=?').run(note, id);
  if (maxDevices !== undefined) db.prepare('UPDATE users SET max_devices=? WHERE id=?').run(Number(maxDevices) || null, id);
  res.json({ user: publicUser(db.prepare('SELECT * FROM users WHERE id=?').get(id)) });
});

app.post('/api/admin/users/:id/points', adminAuth, (req, res) => {
  const id = parseInt(req.params.id, 10);
  const d = parseInt((req.body || {}).delta, 10);
  if (!Number.isFinite(d) || d === 0) return res.status(400).json({ error: 'bad_delta' });
  addPoints(id, d, 'admin', String((req.body || {}).reason || ''));
  res.json({ ok: true, balance: balanceOf(id) });
});

app.post('/api/admin/codes', adminAuth, (req, res) => {
  const { role, days, count, note, prefix } = req.body || {};
  if (!['vip', 'svip'].includes(role)) return res.status(400).json({ error: 'bad_role' });
  const d = Number.isFinite(days) ? days : 30;
  const n = Math.min(200, Math.max(1, parseInt(count || '1', 10)));
  const batch = 'B' + uid(3).slice(0, 6);
  const ins = db.prepare('INSERT INTO codes (code,role,days,batch,note,created_at) VALUES (?,?,?,?,?,?)');
  const out = [];
  for (let i = 0; i < n; i++) {
    const code = newCode(prefix);
    ins.run(code, role, d, batch, note || null, now());
    out.push(code);
  }
  audit(null, 'admin_gen_codes', batch + '/' + role + '/' + d + 'd x' + n, req.ip);
  res.json({ batch, codes: out });
});

app.get('/api/admin/codes', adminAuth, (req, res) => {
  const unused = req.query.unused === '1';
  const rows = db.prepare('SELECT * FROM codes ' + (unused ? 'WHERE used_by IS NULL' : '') + ' ORDER BY id DESC LIMIT 300').all();
  res.json({ rows });
});

app.get('/api/admin/orders', adminAuth, (req, res) => {
  const rows = db.prepare('SELECT * FROM orders ORDER BY id DESC LIMIT 200').all();
  res.json({ rows });
});

app.get('/api/admin/sources', adminAuth, (req, res) => {
  const rows = db.prepare('SELECT * FROM sources ORDER BY kind ASC, sort ASC, id ASC').all();
  res.json({ rows: rows.map(normalizeSource) });
});

app.post('/api/admin/sources', adminAuth, async (req, res) => {
  const { kind, name, url, method, headers, params, resultPath, note, enabled, sort } = req.body || {};
  if (!['music', 'video'].includes(kind)) return res.status(400).json({ error: 'bad_kind' });
  if (!name || !url) return res.status(400).json({ error: 'bad_source' });
  const ins = db.prepare(`INSERT INTO sources
    (kind,name,url,method,headers,params,result_path,note,enabled,sort,created_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?)`).run(
    kind, String(name), String(url), String(method || 'GET'),
    headers ? JSON.stringify(headers) : null,
    params ? JSON.stringify(params) : null,
    resultPath || null, note || '', enabled === false ? 0 : 1,
    Number.isFinite(sort) ? sort : 0, now()
  );
  const row = db.prepare('SELECT * FROM sources WHERE id=?').get(ins.lastInsertRowid);
  const p = await probeSource(row);
  audit(null, 'admin_add_source', kind + '/' + name + '/' + p.status, req.ip);
  res.json({ row: normalizeSource(db.prepare('SELECT * FROM sources WHERE id=?').get(row.id)), probe: p });
});

app.patch('/api/admin/sources/:id', adminAuth, async (req, res) => {
  const id = parseInt(req.params.id, 10);
  const cur = db.prepare('SELECT * FROM sources WHERE id=?').get(id);
  if (!cur) return res.status(404).json({ error: 'not_found' });
  const { name, url, method, headers, params, resultPath, note, enabled, sort } = req.body || {};
  db.prepare(`UPDATE sources SET name=?, url=?, method=?, headers=?, params=?,
    result_path=?, note=?, enabled=?, sort=? WHERE id=?`).run(
    name !== undefined ? String(name) : cur.name,
    url !== undefined ? String(url) : cur.url,
    method !== undefined ? String(method) : cur.method,
    headers !== undefined ? (headers ? JSON.stringify(headers) : null) : cur.headers,
    params !== undefined ? (params ? JSON.stringify(params) : null) : cur.params,
    resultPath !== undefined ? resultPath : cur.result_path,
    note !== undefined ? String(note) : cur.note,
    enabled !== undefined ? (enabled ? 1 : 0) : cur.enabled,
    Number.isFinite(sort) ? sort : cur.sort,
    id
  );
  const row = db.prepare('SELECT * FROM sources WHERE id=?').get(id);
  const p = await probeSource(row);
  res.json({ row: normalizeSource(db.prepare('SELECT * FROM sources WHERE id=?').get(id)), probe: p });
});

app.post('/api/admin/sources/:id/test', adminAuth, limit('testsrc', 60, 60000), async (req, res) => {
  const id = parseInt(req.params.id, 10);
  const row = db.prepare('SELECT * FROM sources WHERE id=?').get(id);
  if (!row) return res.status(404).json({ error: 'not_found' });
  res.json(await probeSource(row));
});

app.delete('/api/admin/sources/:id', adminAuth, (req, res) => {
  db.prepare('DELETE FROM sources WHERE id=?').run(parseInt(req.params.id, 10));
  res.json({ ok: true });
});

app.get('/api/admin/api-keys', adminAuth, (req, res) => {
  res.json({ rows: db.prepare('SELECT * FROM api_keys ORDER BY id DESC').all() });
});

app.post('/api/admin/api-keys', adminAuth, (req, res) => {
  const name = String((req.body || {}).name || 'key');
  const scopes = String((req.body || {}).scopes || 'sources:read');
  const key = 'isle_' + crypto.randomBytes(20).toString('hex');
  db.prepare('INSERT INTO api_keys (key,name,scopes,created_at) VALUES (?,?,?,?)')
    .run(key, name, scopes, now());
  res.json({ key, name, scopes });
});

app.delete('/api/admin/api-keys/:id', adminAuth, (req, res) => {
  db.prepare('DELETE FROM api_keys WHERE id=?').run(parseInt(req.params.id, 10));
  res.json({ ok: true });
});

app.get('/api/admin/audit', adminAuth, (req, res) => {
  res.json({ rows: db.prepare('SELECT * FROM audit ORDER BY id DESC LIMIT 100').all() });
});

// ---------------- 开放 API（第三方） ----------------

app.get('/open/v1/sources', apiKeyAuth, (req, res) => {
  const kind = String(req.query.kind || 'music');
  const rows = db.prepare('SELECT name,url,method,params,headers,result_path,sort FROM sources WHERE kind=? AND enabled=1 ORDER BY sort ASC').all(kind);
  res.json({
    kind, count: rows.length,
    rows: rows.map(r => ({
      name: r.name, url: r.url, method: r.method,
      params: r.params ? safeJson(r.params) : null,
      headers: r.headers ? safeJson(r.headers) : null,
      resultPath: r.result_path, sort: r.sort
    }))
  });
});

app.get('/open/v1/search', apiKeyAuth, limit('open', 60, 60000), async (req, res) => {
  const kw = String(req.query.kw || '').trim();
  if (!kw) return res.status(400).json({ error: 'bad_keyword' });
  const rows = db.prepare("SELECT * FROM sources WHERE kind='music' AND enabled=1 ORDER BY sort ASC").all();
  const out = [];
  for (const src of rows) {
    const url = new URL(src.url);
    const p = src.params ? safeJson(src.params) : null;
    if (p) Object.keys(p).forEach(k => url.searchParams.set(k, String(p[k]).replace('{kw}', kw)));
    if (!p) url.searchParams.set('keyword', kw);
    const h = src.headers ? safeJson(src.headers) : {};
    const r = await fetchJson(url.toString(), { headers: h || {}, timeout: 15000 });
    if (r.ok && r.json) out.push({ source: src.name, status: r.status, ms: r.ms, data: r.json });
  }
  res.json({ keyword: kw, results: out });
});

// ---------------- 兼容 v1 客户端：音源转发 ----------------

app.get('/api/wxmusic', limit('wx', 60, 60000), async (req, res) => {
  const base = process.env.UPSTREAM_MUSIC_API || 'https://api.irepo.cn/api/wxmusic';
  let u;
  try { u = new URL(base); } catch (_) { return res.status(500).json({ code: 500, msg: 'bad_upstream' }); }
  Object.keys(req.query).forEach(k => u.searchParams.set(k, String(req.query[k])));
  const r = await fetchJson(u.toString(), {
    headers: { 'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)' },
    timeout: 25000
  });
  if (!r.json) {
    return res.status(502).json({ code: 502, msg: 'upstream_failed', status: r.status });
  }
  audit(null, 'wxmusic_proxy', String(req.query.keyword || '') + '/' + r.status, req.ip);
  res.json(r.json);
});

app.get('/api/health', (req, res) => {
  res.json({ ok: true, name: 'Isle Music API v2', version: '2.0.0', casdoor: C.casdoor.enabled, time: new Date().toISOString() });
});

app.use(express.static(path.join(__dirname, 'public')));
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'server_error' });
});

app.listen(C.port, () => {
  console.log('[isle] listening on ' + C.port + '  casdoor=' + (C.casdoor.enabled ? 'on' : 'off'));
  console.log('[isle] data dir: ' + DATA);
});
