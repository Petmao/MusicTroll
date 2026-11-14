#!/usr/bin/env python3
import io
import sys


def load(p):
    with io.open(p, encoding='utf-8') as f:
        return f.read()


def save(p, s):
    with io.open(p, 'w', encoding='utf-8') as f:
        f.write(s)


def sub(s, old, new, label):
    if old not in s:
        if new and new in s:
            print('SKIP ' + label)
            return s
        print('MISS ' + label)
        sys.exit(1)
    print('OK   ' + label)
    return s.replace(old, new, 1)


# ---------------- core.js: 云同步表 ----------------
p = 'server-v2/core.js'
s = load(p)

s = sub(s, "CREATE INDEX IF NOT EXISTS idx_sources_kind ON sources(kind, enabled, sort);",
    '''CREATE TABLE IF NOT EXISTS cloud_playlists (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  pid TEXT NOT NULL,
  name TEXT NOT NULL,
  songs TEXT NOT NULL DEFAULT '[]',
  cover TEXT,
  rev INTEGER NOT NULL DEFAULT 1,
  updated_at INTEGER NOT NULL,
  UNIQUE(user_id, pid)
);
CREATE TABLE IF NOT EXISTS progress (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  track_key TEXT NOT NULL,
  position_ms INTEGER NOT NULL DEFAULT 0,
  duration_ms INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL,
  UNIQUE(user_id, track_key)
);
CREATE INDEX IF NOT EXISTS idx_sources_kind ON sources(kind, enabled, sort);
CREATE INDEX IF NOT EXISTS idx_cloud_user ON cloud_playlists(user_id, updated_at DESC);''', 'core 云同步表')

save(p, s)
print('core.js done')

# ---------------- server.js ----------------
p = 'server-v2/server.js'
s = load(p)

s = sub(s, "const express = require('express');",
    "const express = require('express');\nconst fs = require('fs');", 'server 引入 fs')

s = sub(s, "const app = express();",
    "const AVATAR_DIR = path.join(DATA, 'avatars');\nfs.mkdirSync(AVATAR_DIR, { recursive: true });\n\nconst app = express();", 'server 头像目录')

s = sub(s, "app.get('/api/health', (req, res) => {",
    '''// ---------------- 头像 ----------------

app.use('/avatars', express.static(AVATAR_DIR));

app.post('/api/user/avatar', auth, limit('ava', 20, 60000), (req, res) => {
  const raw = String((req.body || {}).image || '');
  const m = raw.match(/^data:image\\/(?:jpeg|jpg|png);base64,(.+)$/);
  const b64 = m ? m[1] : raw;
  if (!b64 || b64.length < 100) return res.status(400).json({ error: 'bad_image' });

  let buf;
  try { buf = Buffer.from(b64, 'base64'); } catch (_) { return res.status(400).json({ error: 'bad_image' }); }
  if (buf.length > 2 * 1024 * 1024) return res.status(413).json({ error: 'too_large' });

  const file = 'u' + req.user.id + '.jpg';
  fs.writeFileSync(path.join(AVATAR_DIR, file), buf);
  const url = '/avatars/' + file;
  db.prepare('UPDATE users SET avatar=? WHERE id=?').run(url, req.user.id);
  audit(req.user.id, 'avatar_upload', String(buf.length), req.ip);
  res.json({ avatar: url + '?v=' + now() });
});

app.delete('/api/user/avatar', auth, (req, res) => {
  try { fs.unlinkSync(path.join(AVATAR_DIR, 'u' + req.user.id + '.jpg')); } catch (_) {}
  db.prepare('UPDATE users SET avatar=NULL WHERE id=?').run(req.user.id);
  res.json({ ok: true });
});

// ---------------- 云同步 ----------------

app.get('/api/cloud/playlists', auth, (req, res) => {
  const rows = db.prepare('SELECT * FROM cloud_playlists WHERE user_id=? ORDER BY id DESC').all(req.user.id);
  res.json({
    rows: rows.map(r => ({
      pid: r.pid, name: r.name, cover: r.cover,
      songs: safeJson(r.songs) || [], rev: r.rev
    }))
  });
});

app.put('/api/cloud/playlists/:pid', auth, (req, res) => {
  const pid = String(req.params.pid);
  const { name, songs, cover, rev } = req.body || {};
  const arr = Array.isArray(songs) ? songs : [];
  const cur = db.prepare('SELECT * FROM cloud_playlists WHERE user_id=? AND pid=?').get(req.user.id, pid);

  if (cur) {
    if (rev !== undefined && Number(rev) < cur.rev) {
      return res.status(409).json({ error: 'stale', rev: cur.rev });
    }
    const nextRev = (Number(rev) || cur.rev) + 1;
    db.prepare('UPDATE cloud_playlists SET name=?, songs=?, cover=?, rev=?, updated_at=? WHERE id=?')
      .run(name || cur.name, JSON.stringify(arr), cover || cur.cover, nextRev, now(), cur.id);
    return res.json({ rev: nextRev });
  }

  db.prepare('INSERT INTO cloud_playlists (user_id,pid,name,songs,cover,rev,updated_at) VALUES (?,?,?,?,?,?,?)')
    .run(req.user.id, pid, name || '未命名', JSON.stringify(arr), cover || null, 1, now());
  res.json({ rev: 1 });
});

app.delete('/api/cloud/playlists/:pid', auth, (req, res) => {
  db.prepare('DELETE FROM cloud_playlists WHERE user_id=? AND pid=?')
    .run(req.user.id, String(req.params.pid));
  res.json({ ok: true });
});

app.post('/api/cloud/progress', auth, (req, res) => {
  const { trackKey, positionMs, durationMs } = req.body || {};
  if (!trackKey) return res.status(400).json({ error: 'bad_key' });
  const p1 = Number(positionMs) || 0;
  const d1 = Number(durationMs) || 0;
  const t = now();
  db.prepare(`INSERT INTO progress (user_id,track_key,position_ms,duration_ms,updated_at)
    VALUES (?,?,?,?,?)
    ON CONFLICT(user_id,track_key) DO UPDATE SET
      position_ms=excluded.position_ms,
      duration_ms=excluded.duration_ms,
      updated_at=excluded.updated_at`)
    .run(req.user.id, String(trackKey), p1, d1, t);
  res.json({ ok: true });
});

app.get('/api/cloud/progress/:key', auth, (req, res) => {
  const r = db.prepare('SELECT * FROM progress WHERE user_id=? AND track_key=?')
    .get(req.user.id, req.params.key);
  res.json(r ? { positionMs: r.position_ms, durationMs: r.duration_ms } : null);
});

// ---------------- 歌单导入 ----------------

app.get('/api/import/playlist', auth, limit('imp', 20, 60000), async (req, res) => {
  const source = String(req.query.source || 'netease').toLowerCase();
  const id = String(req.query.id || '').trim();
  if (!id) return res.status(400).json({ error: 'bad_id' });

  if (source === 'netease') {
    const u = 'https://music.163.com/api/v6/playlist/detail?id=' + encodeURIComponent(id);
    const r = await fetchJson(u, {
      headers: { Referer: 'https://music.163.com/' },
      timeout: 15000
    });
    if (r.json) {
      const pl = r.json.playlist || (r.json.result && r.json.result.playlist);
      const tracks = (pl && pl.tracks) || [];
      const songs = tracks.map(t => {
        const ar = (t.ar && t.ar[0] && t.ar[0].name) || (t.artists && t.artists[0] && t.artists[0].name) || '';
        return ar ? (t.name + ' - ' + ar) : t.name;
      }).filter(Boolean);
      audit(req.user.id, 'import_playlist', 'netease/' + id + '/' + songs.length, req.ip);
      return res.json({ name: (pl && pl.name) || '', songs });
    }
  }

  res.json({ name: '', songs: [] });
});

app.get('/api/health', (req, res) => {''', 'server 头像云同步导入')

save(p, s)
print('server.js done')
print('PATCH20 DONE')
