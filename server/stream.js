'use strict';
const crypto = require('crypto');
const { Readable } = require('stream');

const SECRET = process.env.STREAM_SECRET || process.env.JWT_SECRET || 'dev';
const TTL = parseInt(process.env.STREAM_TTL_MS || '600000', 10);
const LOCAL_TTL = parseInt(process.env.LOCAL_PERMIT_TTL_MS || '300000', 10);
const BIND_IP = process.env.STREAM_BIND_IP === '1';
const ALLOW = (process.env.ALLOW_HOSTS || '').split(',').map(s => s.trim().toLowerCase()).filter(Boolean);

const b64u = (b) => Buffer.from(b).toString('base64url');
const unb64u = (s) => Buffer.from(s, 'base64url').toString('utf8');
const ipHash = (ip) => crypto.createHash('sha256').update(String(ip || '')).digest('base64url').slice(0, 16);
const mac = (payload) => crypto.createHmac('sha256', SECRET).update(payload).digest('base64url');

function issueTicket({ uid, kind, upstreamUrl, ip }) {
  const id = b64u(upstreamUrl);
  const exp = Date.now() + TTL;
  const iph = BIND_IP ? ipHash(ip) : '';
  const sig = mac(`${uid}|${kind}|${id}|${exp}|${iph}`);
  return { path: `/stream/${kind}/${id}?uid=${uid}&exp=${exp}&sig=${sig}`, exp, ttl: TTL };
}

function verifyTicket({ uid, kind, id, exp, sig, ip }) {
  const e = parseInt(exp, 10);
  if (!Number.isFinite(e) || e < Date.now()) return { err: 'expired' };
  const iph = BIND_IP ? ipHash(ip) : '';
  const want = mac(`${uid}|${kind}|${id}|${e}|${iph}`);
  const a = Buffer.from(want), b = Buffer.from(String(sig || ''));
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return { err: 'bad_sig' };
  return { url: unb64u(id) };
}

function issueLocalPermit({ uid, fileId, ip }) {
  const exp = Date.now() + LOCAL_TTL;
  const iph = BIND_IP ? ipHash(ip) : '';
  const sig = mac(`local|${uid}|${fileId}|${exp}|${iph}`);
  return { permit: `${exp}.${sig}`, exp, ttl: LOCAL_TTL, heartbeat: parseInt(process.env.LOCAL_HEARTBEAT_MS || '60000', 10) };
}

function verifyLocalPermit({ uid, fileId, permit, ip }) {
  const [expS, sig] = String(permit || '').split('.');
  const exp = parseInt(expS, 10);
  if (!Number.isFinite(exp)) return { err: 'bad_permit' };
  if (exp < Date.now()) return { err: 'expired' };
  const iph = BIND_IP ? ipHash(ip) : '';
  const want = mac(`local|${uid}|${fileId}|${exp}|${iph}`);
  const a = Buffer.from(want), b = Buffer.from(String(sig || ''));
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return { err: 'bad_sig' };
  return { exp };
}

function upstreamAllowed(raw) {
  let u;
  try { u = new URL(raw); } catch { return false; }
  if (!/^https?:$/.test(u.protocol)) return false;
  const host = u.hostname.toLowerCase();
  if (/^(localhost|127\.|0\.0\.0\.0|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.|169\.254\.)/.test(host)) return false;
  if (!ALLOW.length) return true;
  return ALLOW.some(h => host === h || host.endsWith('.' + h));
}

async function proxyStream(req, res, upstreamUrl) {
  const headers = { 'User-Agent': 'IsleMusic/1.0' };
  if (req.headers.range) headers.Range = req.headers.range;
  if (req.headers['if-range']) headers['If-Range'] = req.headers['if-range'];
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 20000);
  let r;
  try { r = await fetch(upstreamUrl, { headers, redirect: 'follow', signal: ctrl.signal }); }
  catch { clearTimeout(timer); return res.status(502).json({ error: 'upstream_unreachable' }); }
  clearTimeout(timer);
  if (![200, 206].includes(r.status)) return res.status(502).json({ error: 'upstream_' + r.status });
  res.status(r.status);
  for (const h of ['content-type', 'content-length', 'accept-ranges', 'content-range', 'etag', 'last-modified']) {
    const v = r.headers.get(h);
    if (v) res.setHeader(h, v);
  }
  if (!res.getHeader('accept-ranges')) res.setHeader('Accept-Ranges', 'bytes');
  res.setHeader('Cache-Control', 'no-store');
  if (!r.body) return res.end();
  Readable.fromWeb(r.body).pipe(res);
}

module.exports = { issueTicket, verifyTicket, issueLocalPermit, verifyLocalPermit, upstreamAllowed, proxyStream };
