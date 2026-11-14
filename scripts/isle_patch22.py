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


p = 'server-v2/server.js'
s = load(p)

OLD = r'''app.get('/api/import/playlist', auth, limit('imp', 20, 60000), async (req, res) => {
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
});'''

NEW = r'''async function importNetease(id) {
  const u = 'https://music.163.com/api/v6/playlist/detail?id=' + encodeURIComponent(id);
  const r = await fetchJson(u, {
    headers: { Referer: 'https://music.163.com/' },
    timeout: 15000
  });
  if (!r.json) return { name: '', songs: [] };
  const pl = r.json.playlist || (r.json.result && r.json.result.playlist);
  const tracks = (pl && pl.tracks) || [];
  const songs = tracks.map(t => {
    const ar = (t.ar && t.ar[0] && t.ar[0].name)
      || (t.artists && t.artists[0] && t.artists[0].name) || '';
    return ar ? (t.name + ' - ' + ar) : t.name;
  }).filter(Boolean);
  return { name: (pl && pl.name) || '', songs };
}

async function importQQ(id) {
  const u = 'https://c.y.qq.com/qzone/fcg-bin/fcg_ucc_getcdinfo_byids_cp.fcg'
    + '?type=1&json=1&utf8=1&onlysong=0&disstid=' + encodeURIComponent(id)
    + '&format=json&g_tk=5381&loginUin=0&hostUin=0&inCharset=utf8&outCharset=utf-8'
    + '&notice=0&platform=yqq.json&needNewCode=0';
  const r = await fetchJson(u, {
    headers: { Referer: 'https://y.qq.com/' },
    timeout: 15000
  });
  const cd = r.json && r.json.cdlist && r.json.cdlist[0];
  if (!cd) return { name: '', songs: [] };
  const songs = (cd.songlist || []).map(t => {
    const ar = (t.singer || []).map(x => x && x.name).filter(Boolean).join('/');
    return ar ? (t.songname + ' - ' + ar) : t.songname;
  }).filter(Boolean);
  return { name: cd.dissname || '', songs };
}

async function importKugou(id) {
  const u = 'http://mobilecdn.kugou.com/api/v3/special/song?specialid=' + encodeURIComponent(id)
    + '&page=1&pagesize=200&version=8000';
  const r = await fetchJson(u, { timeout: 20000 });
  const info = (r.json && r.json.data && r.json.data.info) || [];
  const songs = info.map(t => {
    if (t && t.filename) {
      return String(t.filename).replace(/<\\/?em>/g, '').trim();
    }
    if (t && t.songname) {
      return t.singername ? (t.songname + ' - ' + t.singername) : t.songname;
    }
    return '';
  }).filter(Boolean);
  return { name: '酷狗歌单 ' + id, songs };
}

app.get('/api/import/playlist', auth, limit('imp', 20, 60000), async (req, res) => {
  const source = String(req.query.source || 'netease').toLowerCase();
  const id = String(req.query.id || '').trim();
  if (!id) return res.status(400).json({ error: 'bad_id' });

  let out = { name: '', songs: [] };
  try {
    if (source === 'netease') out = await importNetease(id);
    else if (source === 'qq') out = await importQQ(id);
    else if (source === 'kugou') out = await importKugou(id);
    else if (source === 'soda') out = { name: '', songs: [], unsupported: 'soda' };
  } catch (e) {
    audit(req.user.id, 'import_playlist_fail', source + '/' + id + '/' + String(e.message || e), req.ip);
    return res.status(502).json({ error: 'upstream_failed' });
  }

  audit(req.user.id, 'import_playlist', source + '/' + id + '/' + out.songs.length, req.ip);
  res.json(out);
});'''

s = sub(s, OLD, NEW, 'import 支持 qq kugou')

save(p, s)
print('server.js done')
print('PATCH22 DONE')
