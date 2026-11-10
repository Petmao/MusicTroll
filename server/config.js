'use strict';
const db = require('./db');

const DEFAULTS = {
  checkin: { rewards: [10, 10, 15, 15, 20, 20], day7BonusRole: 'vip', day7BonusDays: 1, day7Points: 0 },
  exchange: { vip_1d: 300, vip_7d: 1800, svip_1d: 1000, svip_7d: 6000 },
  invite: { inviterDays: 7, inviteeDays: 7, monthlyCap: 10 }
};
let cache = null;

function load() {
  const row = db.prepare('SELECT value FROM config WHERE key=?').get('app');
  const saved = row ? JSON.parse(row.value) : {};
  cache = {
    checkin: { ...DEFAULTS.checkin, ...(saved.checkin || {}) },
    exchange: { ...DEFAULTS.exchange, ...(saved.exchange || {}) },
    invite: { ...DEFAULTS.invite, ...(saved.invite || {}) }
  };
  return cache;
}
function get() { return cache || load(); }
function save(patch) {
  const cur = get();
  const next = {
    checkin: { ...cur.checkin, ...(patch.checkin || {}) },
    exchange: { ...cur.exchange, ...(patch.exchange || {}) },
    invite: { ...cur.invite, ...(patch.invite || {}) }
  };
  const r = next.checkin.rewards;
  if (!Array.isArray(r) || r.length !== 6 || r.some(v => !Number.isFinite(v) || v < 0 || v > 100000))
    throw new Error('bad_rewards');
  for (const v of Object.values(next.exchange))
    if (!Number.isFinite(v) || v < 0) throw new Error('bad_exchange');
  db.prepare("INSERT INTO config (key,value,updated_at) VALUES ('app',?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=excluded.updated_at")
    .run(JSON.stringify(next), Date.now());
  cache = next;
  return next;
}
module.exports = { get, save, DEFAULTS };
