'use strict';
const crypto = require('crypto');
const db = require('./db');

const MASTER = crypto.createHash('sha256').update(`${process.env.APP_SECRET}|device-kek`).digest();
const DEF_MAX = parseInt(process.env.MAX_DEVICES_DEFAULT || '3', 10);
const COOLDOWN_MS = parseInt(process.env.DEVICE_UNBIND_COOLDOWN_DAYS || '30', 10) * 86400000;
const GRACE_MS = parseInt(process.env.DEVICE_UNBIND_GRACE_HOURS || '24', 10) * 3600000;

const seal = (buf) => {
  const iv = crypto.randomBytes(12);
  const c = crypto.createCipheriv('aes-256-gcm', MASTER, iv);
  const e = Buffer.concat([c.update(buf), c.final()]);
  return [iv, c.getAuthTag(), e].map(b => b.toString('base64')).join('.');
};
const open = (t) => {
  const [i, g, e] = t.split('.').map(x => Buffer.from(x, 'base64'));
  const d = crypto.createDecipheriv('aes-256-gcm', MASTER, i);
  d.setAuthTag(g);
  return Buffer.concat([d.update(e), d.final()]);
};

const limitOf = (user) => Number.isFinite(user.max_devices) ? user.max_devices : DEF_MAX;

function usedSlots(userId) {
  const rows = db.prepare('SELECT status, grace_until FROM devices WHERE user_id=?').all(userId);
  const n = Date.now();
  return rows.filter(r => r.status === 'active' || (r.status === 'cooldown' && r.grace_until && r.grace_until > n)).length;
}

function cooldownLeft(userId) {
  const last = db.prepare("SELECT MAX(COALESCE(revoked_at,0)) t FROM devices WHERE user_id=? AND status IN ('cooldown','revoked')").get(userId);
  if (!last || !last.t) return 0;
  return Math.max(0, last.t + COOLDOWN_MS - Date.now());
}

function ensureDeviceKey(user, deviceId, name) {
  const row = db.prepare('SELECT * FROM devices WHERE user_id=? AND device_id=?').get(user.id, deviceId);
  if (row) {
    if (row.status === 'revoked') throw new Error('device_revoked');
    db.prepare('UPDATE devices SET status=?, grace_until=NULL, last_seen_at=? WHERE id=?').run('active', Date.now(), row.id);
    return { keyId: row.id, key: open(row.key_enc).toString('base64') };
  }
  if (usedSlots(user.id) >= limitOf(user)) throw new Error('device_limit');
  const key = crypto.randomBytes(32);
  const info = db.prepare('INSERT INTO devices (user_id,device_id,name,key_enc,status,created_at,last_seen_at) VALUES (?,?,?,?,?,?,?)')
    .run(user.id, deviceId, name || '', seal(key), 'active', Date.now(), Date.now());
  return { keyId: info.lastInsertRowid, key: key.toString('base64') };
}

function listDevices(userId, currentDeviceId) {
  return db.prepare('SELECT * FROM devices WHERE user_id=? ORDER BY last_seen_at DESC').all(userId).map(d => ({
    deviceId: d.device_id, name: d.name, status: d.status, graceUntil: d.grace_until,
    lastSeenAt: d.last_seen_at, isCurrent: d.device_id === currentDeviceId
  }));
}

function unbindDevice(user, deviceId, reason) {
  const left = cooldownLeft(user.id);
  if (left > 0) throw new Error('cooldown:' + Math.ceil(left / 86400000));
  const d = db.prepare('SELECT * FROM devices WHERE user_id=? AND device_id=?').get(user.id, deviceId);
  if (!d) throw new Error('not_found');
  if (d.status !== 'active') throw new Error('not_active');
  const grace = Date.now() + GRACE_MS;
  db.prepare("UPDATE devices SET status='cooldown', grace_until=?, revoked_at=?, unbind_reason=? WHERE id=?")
    .run(grace, Date.now(), reason || '', d.id);
  return { graceUntil: grace, cooldownDays: COOLDOWN_MS / 86400000 };
}

function sweepGrace() {
  db.prepare("UPDATE devices SET status='revoked' WHERE status='cooldown' AND grace_until < ?").run(Date.now());
}

module.exports = { ensureDeviceKey, listDevices, unbindDevice, sweepGrace, limitOf, usedSlots, cooldownLeft };
