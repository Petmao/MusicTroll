'use strict';
const express = require('express');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const db = require('./db');
const conf = require('./config');
const dev = require('./device');
const st = require('./stream');

const SECRET = process.env.JWT_SECRET || 'dev-secret';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'admin';
const KEY = crypto.createHash('sha256').update(process.env.APP_SECRET || SECRET).digest();
const RANK = { free: 0, vip: 1, svip: 2 };
const AVATAR_DIR = process.env.AVATAR_DIR || path.join(__dirname, 'data/avatars');
fs.mkdirSync(AVATAR_DIR, { recursive: true });

const app = express();
app.use(express.json({ limit: '2mb' }));
app.use('/avatar', express.static(AVATAR_DIR, { maxAge: '7d', immutable: true }));
app.use(express.static(path.join(__dirname, 'public')));

const now = () => Date.now();
const today = () => new Date(Date.now() + 8 * 3600e3).toISOString().slice(0, 10);
const yesterday = () => new Date(Date.now() - 864e5 + 8 * 3600e3).toISOString().slice(0, 10);

const enc = (s) => { const iv = crypto.randomBytes(12); const c = crypto.createCipheriv('aes-256-gcm', KEY, iv); const e = Buffer.concat([c.update(s, 'utf8'), c.final()]); return [iv, c.getAuthTag(), e].map(b => b.toString('base64')).join('.'); };
const dec = (t) => { const [i, g, e] = t.split('.').map(x => Buffer.from(x, 'base64')); const d = crypto.createDecipheriv('aes-256-gcm', KEY, i); d.setAuthTag(g); return Buffer.concat([d.update(e), d.final()]).toString('utf8'); };
const maskPhone = (p) => p.slice(0, 3) + '****' + p.slice(-4);
const audit = (uid, action, detail, ip) => db.prepare('INSERT INTO audit (user_id,action,detail,ip,created_at) VALUES (?,?,?,?,?)').run(uid || null, action, detail || '', ip || '', now());
const balanceOf = (uid) => db.prepare('SELECT COALESCE(SUM(delta),0) s FROM points WHERE user_id=?').get(uid).s;

function normalize(u) {
  let role = u.role, exp = u.role_expire_at;
  if (role !== 'free' && exp && exp < now()) {
    role = 'free'; exp = null;
    db.prepare('UPDATE users SET role=?, role_expire_at=? WHERE id=?').run('free', null, u.id);
  }
  return { id: u.id, account: u.account, nickname: u.nickname, avatar: u.avatar || '', role, roleExpireAt: exp, phoneMasked: u.phone_mask || '', status: u.status, inviteCode: u.invite_code || '', points: balanceOf(u.id) };
}
const entitle = (r) => ({ canPlayMusic: RANK[r] >= RANK.vip, canUseVideo: RANK[r] >= RANK.svip, canManageSources: true });

function grantRole(uid, role, days, tag) {
  const u = db.prepare('SELECT * FROM users WHERE id=?').get(uid);
  if (!u) return;
  const cur = normalize(u);
  let base = now();
  if (RANK[cur.role] >= RANK[role] && cur.roleExpireAt && cur.roleExpireAt > base) base = cur.roleExpireAt;
  const expire = days > 0 ? base + days * 864e5 : null;
  const next = RANK[role] >= RANK[cur.role] ? role : cur.role;
  db.prepare('UPDATE users SET role=?, role_expire_at=? WHERE id=?').run(next, expire, uid);
  audit(uid, 'grant', `${role}/${days}d/${tag || ''}`, '');
}

const hits = new Map();
const limit = (name, max, winMs) => (req, res, next) => {
  const k = name + ':' + req.ip;
  const r = hits.get(k) || { n: 0, t: now() };
  if (now() - r.t > winMs) { r.n = 0; r.t = now(); }
  r.n++; hits.set(k, r);
  if (r.n > max) return res.status(429).json({ error: 'too_many_requests' });
  next();
};

function auth(req, res, next) {
  const h = req.headers.authorization || '';
  const t = h.startsWith('Bearer ') ? h.slice(7) : '';
  try {
    const p = jwt.verify(t, SECRET);
    const u = db.prepare('SELECT * FROM users WHERE id=?').get(p.uid);
    if (!u || u.status !== 'active') return res.status(401).json({ error: 'unauthorized' });
    req.user = normalize(u);
    next();
  } catch { res.status(401).json({ error: 'unauthorized' }); }
}
const need = (role) => (req, res, next) => RANK[req.user.role] >= RANK[role] ? next() : res.status(403).json({ error: 'need_' + role });

function adminAuth(req, res, next) {
  const h = req.headers.authorization || '';
  const t = h.startsWith('Bearer ') ? h.slice(7) : '';
  try { const p = jwt.verify(t, SECRET); if (!p.admin) throw 0; next(); }
  catch { res.status(401).json({ error: 'unauthorized' }); }
}

const ACCOUNT_RE = /^[A-Za-z][A-Za-z0-9]{3,15}$/;
const PHONE_RE = /^1[3-9]\d{9}$/;
const sign = (uid, account) => jwt.sign({ uid, account }, SECRET, { expiresIn: '30d' });

/* ---------- 注册 / 登录 ---------- */
app.post('/api/auth/register', limit('reg', 8, 60000), async (req, res) => {
  const { account, nickname, password, phone, inviteCode } = req.body || {};
  if (!ACCOUNT_RE.test(String(account || ''))) return res.status(400).json({ error: 'bad_account' });
  if (!nickname || String(nickname).length > 20) return res.status(400).json({ error: 'bad_nickname' });
  if (String(password || '').length < 8) return res.status(400).json({ error: 'password_too_short' });
  if (phone && !PHONE_RE.test(String(phone))) return res.status(400).json({ error: 'bad_phone' });
  const key = String(account).toLowerCase();
  if (db.prepare('SELECT 1 FROM users WHERE account_key=?').get(key)) return res.status(409).json({ error: 'account_taken' });

  const hash = await bcrypt.hash(String(password), 10);
  const info = db.prepare('INSERT INTO users (account,account_key,nickname,password_hash,phone_mask,phone_enc,role,created_at) VALUES (?,?,?,?,?,?,?,?)')
    .run(String(account), key, String(nickname), hash, phone ? maskPhone(String(phone)) : '', phone ? enc(String(phone)) : '', 'free', now());
  const uid = info.lastInsertRowid;
  const myCode = 'MT' + crypto.randomBytes(3).toString('hex').toUpperCase();
  db.prepare('UPDATE users SET invite_code=? WHERE id=?').run(myCode, uid);

  if (inviteCode) {
    const inviter = db.prepare('SELECT * FROM users WHERE invite_code=?').get(String(inviteCode).toUpperCase());
    if (inviter && inviter.id !== uid) {
      db.prepare('INSERT INTO invites (code,inviter_id,invitee_id,status,created_at) VALUES (?,?,?,?,?)')
        .run(String(inviteCode).toUpperCase(), inviter.id, uid, 'pending', now());
      db.prepare('UPDATE users SET invited_by=? WHERE id=?').run(inviter.id, uid);
    }
  }
  const user = normalize(db.prepare('SELECT * FROM users WHERE id=?').get(uid));
  audit(uid, 'register', String(account), req.ip);
  res.json({ token: sign(uid, user.account), user, entitlements: entitle(user.role) });
});

app.get('/api/auth/check-account', limit('chk', 40, 60000), (req, res) => {
  const a = String(req.query.account || '');
  if (!ACCOUNT_RE.test(a)) return res.json({ ok: false, reason: 'format' });
  const taken = !!db.prepare('SELECT 1 FROM users WHERE account_key=?').get(a.toLowerCase());
  res.json({ ok: !taken, reason: taken ? 'taken' : 'free' });
});

app.post('/api/auth/login', limit('login', 15, 60000), async (req, res) => {
  const key = String((req.body || {}).account || '').toLowerCase();
  const u = db.prepare('SELECT * FROM users WHERE account_key=?').get(key);
  if (!u) return res.status(401).json({ error: 'bad_credentials' });
  if (u.status !== 'active') return res.status(403).json({ error: 'banned' });
  if (!(await bcrypt.compare(String((req.body || {}).password || ''), u.password_hash))) return res.status(401).json({ error: 'bad_credentials' });
  db.prepare('UPDATE users SET last_login_at=? WHERE id=?').run(now(), u.id);
  const user = normalize(u);
  audit(u.id, 'login', '', req.ip);
  res.json({ token: sign(u.id, u.account), user, entitlements: entitle(user.role) });
});

app.get('/api/auth/me', auth, (req, res) => res.json({ user: req.user, entitlements: entitle(req.user.role) }));

app.post('/api/auth/password', auth, async (req, res) => {
  const { oldPassword, newPassword } = req.body || {};
  if (String(newPassword || '').length < 8) return res.status(400).json({ error: 'password_too_short' });
  const u = db.prepare('SELECT * FROM users WHERE id=?').get(req.user.id);
  if (!(await bcrypt.compare(String(oldPassword || ''), u.password_hash))) return res.status(401).json({ error: 'bad_credentials' });
  db.prepare('UPDATE users SET password_hash=? WHERE id=?').run(await bcrypt.hash(String(newPassword), 10), u.id);
  res.json({ ok: true });
});

/* ---------- 头像 ---------- */
app.post('/api/user/avatar', auth, limit('avatar', 12, 60000), (req, res) => {
  const { image } = req.body || {};
  if (!image || String(image).length > 900000) return res.status(400).json({ error: 'too_large' });
  const buf = Buffer.from(String(image), 'base64');
  const isJpg = buf[0] === 0xFF && buf[1] === 0xD8;
  const isPng = buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4E && buf[3] === 0x47;
  if (!isJpg && !isPng) return res.status(400).json({ error: 'bad_image' });
  if (buf.length > 512 * 1024) return res.status(400).json({ error: 'too_large' });
  const name = req.user.id + '_' + now() + (isPng ? '.png' : '.jpg');
  fs.writeFileSync(path.join(AVATAR_DIR, name), buf);
  const old = db.prepare('SELECT avatar FROM users WHERE id=?').get(req.user.id).avatar;
  if (old) { try { fs.unlinkSync(path.join(AVATAR_DIR, old.split('/').pop())); } catch {} }
  const rel = '/avatar/' + name;
  db.prepare('UPDATE users SET avatar=? WHERE id=?').run(rel, req.user.id);
  res.json({ avatar: rel });
});

app.delete('/api/user/avatar', auth, (req, res) => {
  const old = db.prepare('SELECT avatar FROM users WHERE id=?').get(req.user.id).avatar;
  if (old) { try { fs.unlinkSync(path.join(AVATAR_DIR, old.split('/').pop())); } catch {} }
  db.prepare('UPDATE users SET avatar=? WHERE id=?').run('', req.user.id);
  res.json({ ok: true });
});

/* ---------- 卡密兑换 ---------- */
app.post('/api/redeem', auth, limit('redeem', 10, 60000), (req, res) => {
  const code = String((req.body || {}).code || '').trim().toUpperCase();
  const c = db.prepare('SELECT * FROM codes WHERE code=?').get(code);
  if (!c) return res.status(404).json({ error: 'code_not_found' });
  if (c.used_by) return res.status(409).json({ error: 'code_used' });
  db.prepare('UPDATE codes SET used_by=?, used_at=? WHERE id=? AND used_by IS NULL').run(req.user.id, now(), c.id);
  grantRole(req.user.id, c.role, c.days, 'redeem:' + code);
  rewardInvite(req.user.id);
  const user = normalize(db.prepare('SELECT * FROM users WHERE id=?').get(req.user.id));
  audit(req.user.id, 'redeem', code, req.ip);
  res.json({ user, entitlements: entitle(user.role) });
});

function rewardInvite(inviteeId) {
  const inv = db.prepare("SELECT * FROM invites WHERE invitee_id=? AND status='pending'").get(inviteeId);
  if (!inv) return;
  const c = conf.get().invite;
  db.prepare("UPDATE invites SET status='redeemed', redeemed_at=? WHERE id=?").run(now(), inv.id);
  grantRole(inv.inviter_id, 'vip', c.inviterDays, 'invite:' + inviteeId);
  grantRole(inviteeId, 'vip', c.inviteeDays, 'invited:' + inv.inviter_id);
}

/* ---------- 设备 ---------- */
app.post('/api/device/register', auth, need('vip'), limit('devreg', 30, 60000), (req, res) => {
  const { deviceId, name } = req.body || {};
  if (!deviceId) return res.status(400).json({ error: 'bad_device' });
  try { res.json(dev.ensureDeviceKey(req.user, String(deviceId), String(name || ''))); }
  catch (e) {
    const m = String(e.message);
    if (m === 'device_limit') return res.status(409).json({ error: 'device_limit', limit: dev.limitOf(req.user), used: dev.usedSlots(req.user.id), devices: dev.listDevices(req.user.id, deviceId) });
    res.status(403).json({ error: m });
  }
});

app.post('/api/device/key', auth, need('vip'), (req, res) => {
  try { res.json(dev.ensureDeviceKey(req.user, String((req.body || {}).deviceId || ''), '')); }
  catch (e) { res.status(403).json({ error: String(e.message) }); }
});

app.get('/api/device/list', auth, (req, res) => res.json({
  limit: dev.limitOf(req.user), used: dev.usedSlots(req.user.id),
  unbindCooldownLeftMs: dev.cooldownLeft(req.user.id),
  graceHours: parseInt(process.env.DEVICE_UNBIND_GRACE_HOURS || '24', 10),
  devices: dev.listDevices(req.user.id, String(req.query.deviceId || ''))
}));

app.post('/api/device/unbind', auth, limit('unbind', 5, 86400000), (req, res) => {
  try { res.json(dev.unbindDevice(req.user, String((req.body || {}).deviceId || ''), String((req.body || {}).reason || ''))); }
  catch (e) {
    const m = String(e.message);
    if (m.startsWith('cooldown:')) return res.status(429).json({ error: 'cooldown', daysLeft: parseInt(m.split(':')[1], 10) });
    res.status(400).json({ error: m });
  }
});

/* ---------- 播放票据 / 流代理 / 本地许可 ---------- */
app.post('/api/play/ticket', auth, limit('ticket', 120, 60000), (req, res) => {
  const { kind, url } = req.body || {};
  if (!['audio', 'video'].includes(kind)) return res.status(400).json({ error: 'bad_kind' });
  if (!url || !st.upstreamAllowed(String(url))) return res.status(400).json({ error: 'url_not_allowed' });
  if (kind === 'audio' && RANK[req.user.role] < RANK.vip) return res.status(403).json({ error: 'need_vip' });
  if (kind === 'video' && RANK[req.user.role] < RANK.svip) return res.status(403).json({ error: 'need_svip' });
  res.json(st.issueTicket({ uid: req.user.id, kind, upstreamUrl: String(url), ip: req.ip }));
});

app.get('/stream/:kind/:id', async (req, res) => {
  const { kind, id } = req.params;
  const { uid, exp, sig } = req.query;
  if (!['audio', 'video'].includes(kind)) return res.status(400).end();
  const v = st.verifyTicket({ uid, kind, id, exp, sig, ip: req.ip });
  if (v.err) return res.status(403).json({ error: v.err });
  const u = db.prepare('SELECT * FROM users WHERE id=?').get(parseInt(uid, 10));
  if (!u || u.status !== 'active') return res.status(403).json({ error: 'banned' });
  const nu = normalize(u);
  if (kind === 'audio' && RANK[nu.role] < RANK.vip) return res.status(403).json({ error: 'need_vip' });
  if (kind === 'video' && RANK[nu.role] < RANK.svip) return res.status(403).json({ error: 'need_svip' });
  if (!st.upstreamAllowed(v.url)) return res.status(400).json({ error: 'url_not_allowed' });
  await st.proxyStream(req, res, v.url);
});

app.post('/api/play/permit', auth, need('vip'), limit('permit', 180, 60000), (req, res) => {
  const { fileId, name } = req.body || {};
  if (!fileId) return res.status(400).json({ error: 'bad_file_id' });
  const p = st.issueLocalPermit({ uid: req.user.id, fileId: String(fileId), ip: req.ip });
  audit(req.user.id, 'local_permit', String(name || '').slice(0, 60), req.ip);
  res.json(p);
});

app.post('/api/play/permit/check', auth, limit('permitcheck', 900, 60000), (req, res) => {
  const { fileId, permit } = req.body || {};
  const v = st.verifyLocalPermit({ uid: req.user.id, fileId: String(fileId), permit, ip: req.ip });
  if (v.err) return res.status(403).json({ error: v.err });
  if (RANK[req.user.role] < RANK.vip) return res.status(403).json({ error: 'need_vip' });
  if (v.exp - now() < 60000) return res.json({ ok: true, ...st.issueLocalPermit({ uid: req.user.id, fileId: String(fileId), ip: req.ip }) });
  res.json({ ok: true, exp: v.exp });
});

/* ---------- 签到 / 积分 ---------- */
app.get('/api/checkin/status', auth, (req, res) => {
  const c = conf.get().checkin;
  const rows = db.prepare('SELECT day FROM checkins WHERE user_id=? ORDER BY day DESC LIMIT 7').all(req.user.id);
  const last = rows[0] && rows[0].day;
  const streak = last === today() ? rows.length : (last === yesterday() ? rows.length : 0);
  res.json({ todaySigned: last === today(), streak, balance: balanceOf(req.user.id), rewards: c.rewards, day7: { role: c.day7BonusRole, days: c.day7BonusDays, points: c.day7Points } });
});

app.post('/api/checkin', auth, limit('checkin', 8, 60000), (req, res) => {
  const d = today();
  if (db.prepare('SELECT 1 FROM checkins WHERE user_id=? AND day=?').get(req.user.id, d)) return res.status(409).json({ error: 'already_signed' });
  const c = conf.get().checkin;
  const prev = db.prepare('SELECT * FROM checkins WHERE user_id=? ORDER BY day DESC LIMIT 1').get(req.user.id);
  const streak = prev && prev.day === yesterday() ? prev.streak + 1 : 1;
  const is7 = streak % 7 === 0;
  const pts = is7 ? (c.day7Points || 0) : (c.rewards[Math.min(streak, 6) - 1] || 0);
  db.prepare('INSERT INTO checkins (user_id,day,streak,points,created_at) VALUES (?,?,?,?,?)').run(req.user.id, d, streak, pts, now());
  if (pts > 0) db.prepare('INSERT INTO points (user_id,delta,reason,ref,created_at) VALUES (?,?,?,?,?)').run(req.user.id, pts, 'checkin', d, now());
  if (is7) grantRole(req.user.id, c.day7BonusRole, c.day7BonusDays, 'checkin_day7:' + d);
  res.json({ streak, points: pts, balance: balanceOf(req.user.id), bonus: is7 ? c.day7BonusRole : null });
});

const GOODS = () => { const e = conf.get().exchange; return { vip_1d: { role: 'vip', days: 1, cost: e.vip_1d }, vip_7d: { role: 'vip', days: 7, cost: e.vip_7d }, svip_1d: { role: 'svip', days: 1, cost: e.svip_1d }, svip_7d: { role: 'svip', days: 7, cost: e.svip_7d } }; };

app.get('/api/points/goods', auth, (req, res) => res.json({ balance: balanceOf(req.user.id), goods: GOODS() }));

app.post('/api/points/exchange', auth, limit('ex', 20, 60000), (req, res) => {
  const g = GOODS()[String((req.body || {}).goods || '')];
  if (!g) return res.status(400).json({ error: 'bad_goods' });
  if (balanceOf(req.user.id) < g.cost) return res.status(400).json({ error: 'not_enough_points' });
  db.prepare('INSERT INTO points (user_id,delta,reason,ref,created_at) VALUES (?,?,?,?,?)').run(req.user.id, -g.cost, 'exchange', (req.body || {}).goods, now());
  grantRole(req.user.id, g.role, g.days, 'points');
  const user = normalize(db.prepare('SELECT * FROM users WHERE id=?').get(req.user.id));
  res.json({ user, balance: balanceOf(req.user.id), entitlements: entitle(user.role) });
});

/* ---------- 邀请 ---------- */
app.get('/api/invite/me', auth, (req, res) => {
  let code = req.user.inviteCode;
  if (!code) { code = 'MT' + crypto.randomBytes(3).toString('hex').toUpperCase(); db.prepare('UPDATE users SET invite_code=? WHERE id=?').run(code, req.user.id); }
  const list = db.prepare('SELECT i.status,i.created_at,i.redeemed_at,u.nickname FROM invites i LEFT JOIN users u ON u.id=i.invitee_id WHERE i.inviter_id=? ORDER BY i.id DESC LIMIT 50').all(req.user.id);
  res.json({ code, count: list.length, redeemed: list.filter(x => x.status === 'redeemed').length, list });
});

/* ---------- 云歌单 / 进度 ---------- */
app.get('/api/cloud/playlists', auth, (req, res) => {
  const rows = db.prepare('SELECT * FROM cloud_playlists WHERE user_id=? AND deleted=0 ORDER BY updated_at DESC').all(req.user.id)
    .map(r => ({ pid: r.pid, name: r.name, cover: r.cover, songs: JSON.parse(r.songs), rev: r.rev, updatedAt: r.updated_at }));
  res.json({ rows });
});

app.put('/api/cloud/playlists/:pid', auth, (req, res) => {
  const { name, cover, songs, rev } = req.body || {};
  if (!Array.isArray(songs) || songs.length > 5000) return res.status(400).json({ error: 'bad_songs' });
  const cur = db.prepare('SELECT * FROM cloud_playlists WHERE user_id=? AND pid=?').get(req.user.id, req.params.pid);
  if (cur && rev !== undefined && cur.rev !== rev) return res.status(409).json({ error: 'conflict', server: { pid: cur.pid, rev: cur.rev, songs: JSON.parse(cur.songs) } });
  const newRev = (cur ? cur.rev : 0) + 1;
  db.prepare('INSERT INTO cloud_playlists (user_id,pid,name,cover,songs,rev,updated_at) VALUES (?,?,?,?,?,?,?) ON CONFLICT(user_id,pid) DO UPDATE SET name=excluded.name, cover=excluded.cover, songs=excluded.songs, rev=excluded.rev, updated_at=excluded.updated_at')
    .run(req.user.id, req.params.pid, String(name || '未命名'), String(cover || ''), JSON.stringify(songs), newRev, now());
  res.json({ rev: newRev });
});

app.delete('/api/cloud/playlists/:pid', auth, (req, res) => {
  db.prepare('UPDATE cloud_playlists SET deleted=1, updated_at=? WHERE user_id=? AND pid=?').run(now(), req.user.id, req.params.pid);
  res.json({ ok: true });
});

app.post('/api/cloud/progress', auth, limit('prog', 900, 60000), (req, res) => {
  const { trackKey, positionMs, durationMs } = req.body || {};
  if (!trackKey) return res.status(400).json({ error: 'bad_key' });
  db.prepare('INSERT INTO progress (user_id,track_key,position_ms,duration_ms,updated_at) VALUES (?,?,?,?,?) ON CONFLICT(user_id,track_key) DO UPDATE SET position_ms=excluded.position_ms, duration_ms=excluded.duration_ms, updated_at=excluded.updated_at')
    .run(req.user.id, String(trackKey), positionMs | 0, durationMs | 0, now());
  res.json({ ok: true });
});

app.get('/api/cloud/progress/:key', auth, (req, res) => {
  const r = db.prepare('SELECT * FROM progress WHERE user_id=? AND track_key=?').get(req.user.id, req.params.key);
  res.json(r ? { positionMs: r.position_ms, durationMs: r.duration_ms } : null);
});

/* ---------- 管理后台 ---------- */
app.post('/api/admin/login', limit('adminlogin', 6, 300000), (req, res) => {
  const a = Buffer.from(String((req.body || {}).password || ''));
  const b = Buffer.from(ADMIN_PASSWORD);
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return res.status(401).json({ error: 'bad_credentials' });
  res.json({ token: jwt.sign({ admin: true }, SECRET, { expiresIn: '12h' }) });
});

app.get('/api/admin/users', adminAuth, (req, res) => {
  const q = String(req.query.q || '').trim();
  const page = Math.max(1, parseInt(req.query.page || '1', 10));
  const where = q ? 'WHERE u.account LIKE ? OR u.nickname LIKE ?' : '';
  const args = q ? ['%' + q + '%', '%' + q + '%'] : [];
  const rows = db.prepare('SELECT u.*, COALESCE((SELECT SUM(delta) FROM points p WHERE p.user_id=u.id),0) AS pts FROM users u ' + where + ' ORDER BY u.id DESC LIMIT 20 OFFSET ?')
    .all(...args, (page - 1) * 20).map(r => Object.assign(normalize(r), { points: r.pts }));
  const total = db.prepare('SELECT COUNT(*) c FROM users u ' + where).get(...args).c;
  res.json({ total, page, rows });
});

app.patch('/api/admin/users/:id', adminAuth, (req, res) => {
  const id = parseInt(req.params.id, 10);
  const { role, days, status, nickname, note, maxDevices } = req.body || {};
  if (role) {
    if (!(role in RANK)) return res.status(400).json({ error: 'bad_role' });
    const d = Number.isFinite(days) ? days : 30;
    const expire = role === 'free' ? null : (d > 0 ? now() + d * 864e5 : null);
    db.prepare('UPDATE users SET role=?, role_expire_at=? WHERE id=?').run(role, expire, id);
    audit(id, 'admin_set_role', role + '/' + d + 'd', req.ip);
  }
  if (status) db.prepare('UPDATE users SET status=? WHERE id=?').run(status, id);
  if (nickname) db.prepare('UPDATE users SET nickname=? WHERE id=?').run(String(nickname), id);
  if (typeof note === 'string') db.prepare('UPDATE users SET note=? WHERE id=?').run(note, id);
  if ('maxDevices' in (req.body || {})) db.prepare('UPDATE users SET max_devices=? WHERE id=?').run(Number(maxDevices) || null, id);
  res.json({ user: normalize(db.prepare('SELECT * FROM users WHERE id=?').get(id) ) });
});

app.post('/api/admin/users/:id/points', adminAuth, (req, res) => {
  const id = parseInt(req.params.id, 10);
  const d = parseInt((req.body || {}).delta, 10);
  if (!Number.isFinite(d) || d === 0) return res.status(400).json({ error: 'bad_delta' });
  db.prepare('INSERT INTO points (user_id,delta,reason,ref,created_at) VALUES (?,?,?,?,?)').run(id, d, 'admin', String((req.body || {}).reason || '').slice(0, 80), now());
  audit(id, 'admin_points', String(d), req.ip);
  res.json({ ok: true, balance: balanceOf(id) });
});

app.get('/api/admin/users/:id/points', adminAuth, (req, res) => {
  const id = parseInt(req.params.id, 10);
  res.json({ balance: balanceOf(id), rows: db.prepare('SELECT delta,reason,ref,created_at FROM points WHERE user_id=? ORDER BY id DESC LIMIT 50').all(id) });
});

app.get('/api/admin/users/:id/devices', adminAuth, (req, res) => res.json(dev.listDevices(parseInt(req.params.id, 10), '')));
app.post('/api/admin/devices/:id/revoke', adminAuth, (req, res) => { db.prepare("UPDATE devices SET status='revoked', grace_until=NULL, revoked_at=? WHERE id=?").run(now(), parseInt(req.params.id, 10)); res.json({ ok: true }); });
app.post('/api/admin/users/:id/reset-cooldown', adminAuth, (req, res) => { db.prepare('UPDATE devices SET revoked_at=NULL WHERE user_id=?').run(parseInt(req.params.id, 10)); res.json({ ok: true }); });
app.get('/api/admin/users/:id/phone', adminAuth, (req, res) => {
  const u = db.prepare('SELECT phone_enc FROM users WHERE id=?').get(parseInt(req.params.id, 10));
  if (!u || !u.phone_enc) return res.status(404).json({ error: 'not_found' });
  res.json({ phone: dec(u.phone_enc) });
});

app.post('/api/admin/codes', adminAuth, (req, res) => {
  const { role, days, count } = req.body || {};
  if (!['vip', 'svip'].includes(role)) return res.status(400).json({ error: 'bad_role' });
  const d = Number.isFinite(days) ? days : 30;
  const n = Math.min(200, Math.max(1, parseInt(count || '1', 10)));
  const batch = 'B' + crypto.randomBytes(3).toString('hex').toUpperCase();
  const ins = db.prepare('INSERT INTO codes (code,role,days,batch,created_at) VALUES (?,?,?,?,?)');
  const out = [];
  for (let i = 0; i < n; i++) { const code = 'MT-' + crypto.randomBytes(6).toString('hex').toUpperCase(); ins.run(code, role, d, batch, now()); out.push(code); }
  res.json({ batch, codes: out });
});

app.get('/api/admin/codes', adminAuth, (req, res) => {
  const unused = req.query.unused === '1';
  res.json({ rows: db.prepare('SELECT * FROM codes ' + (unused ? 'WHERE used_by IS NULL' : '') + ' ORDER BY id DESC LIMIT 300').all() });
});

app.get('/api/admin/config', adminAuth, (req, res) => res.json(conf.get()));
app.put('/api/admin/config', adminAuth, (req, res) => {
  try { res.json(conf.save(req.body || {})); } catch (e) { res.status(400).json({ error: String(e.message) }); }
});

app.get('/api/admin/stats', adminAuth, (req, res) => res.json({
  users: db.prepare('SELECT COUNT(*) c FROM users').get().c,
  byRole: db.prepare('SELECT role, COUNT(*) c FROM users GROUP BY role').all(),
  codesUnused: db.prepare('SELECT COUNT(*) c FROM codes WHERE used_by IS NULL').get().c,
  devices: db.prepare("SELECT COUNT(*) c FROM devices WHERE status='active'").get().c
}));

app.get('/api/health', (req, res) => res.json({ ok: true, name: 'Isle Music API', ts: now() }));
app.use((err, req, res, next) => { console.error(err); res.status(500).json({ error: 'server_error' }); });

setInterval(() => { try { dev.sweepGrace(); } catch {} }, 10 * 60000);

const PORT = process.env.PORT || 8787;
app.listen(PORT, () => console.log('Isle Music API on ' + PORT + '  public=' + (process.env.PUBLIC_URL || '')));
