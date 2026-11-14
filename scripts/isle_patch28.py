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


# ---------- core.js：fetchJson 带回最终 URL ----------
p = 'server-v2/core.js'
s = load(p)

s = sub(s, "    return { ok: res.ok, status: res.status, json: json, text: text, ms: Date.now() - started };",
    "    return { ok: res.ok, status: res.status, json: json, text: text, ms: Date.now() - started, finalUrl: res.url };", 'core finalUrl')

save(p, s)
print('core.js done')

# ---------- server.js：导入探针 ----------
p = 'server-v2/server.js'
s = load(p)

s = sub(s, "app.get('/api/health', (req, res) => {",
    '''// ---------------- 歌单导入诊断：看服务端到底从上游拿到了什么 ----------------

app.get('/api/import/probe', auth, limit('probe', 30, 60000), async (req, res) => {
  const source = String(req.query.source || 'netease').toLowerCase();
  const id = String(req.query.id || '').trim();
  if (!id) return res.status(400).json({ error: 'bad_id' });

  let target = '';
  let headers = {};

  if (source === 'netease') {
    target = 'https://music.163.com/api/v6/playlist/detail?id=' + encodeURIComponent(id);
    headers = { Referer: 'https://music.163.com/' };
  } else if (source === 'qq') {
    target = 'https://c.y.qq.com/qzone/fcg-bin/fcg_ucc_getcdinfo_byids_cp.fcg'
      + '?type=1&json=1&utf8=1&onlysong=0&disstid=' + encodeURIComponent(id)
      + '&format=json&g_tk=5381&loginUin=0&hostUin=0&inCharset=utf8&outCharset=utf-8'
      + '&notice=0&platform=yqq.json&needNewCode=0';
    headers = { Referer: 'https://y.qq.com/' };
  } else if (source === 'kugou') {
    target = 'http://mobilecdn.kugou.com/api/v3/special/song?specialid=' + encodeURIComponent(id)
      + '&page=1&pagesize=200&version=8000';
  } else {
    return res.json({ source, id, supported: false });
  }

  const r = await fetchJson(target, { headers, timeout: 15000 });

  let songCount = 0;
  let name = '';
  if (source === 'netease') {
    const pl = r.json && (r.json.playlist || (r.json.result && r.json.result.playlist));
    songCount = (pl && pl.tracks && pl.tracks.length) || 0;
    name = (pl && pl.name) || '';
  } else if (source === 'qq') {
    const cd = r.json && r.json.cdlist && r.json.cdlist[0];
    songCount = (cd && cd.songlist && cd.songlist.length) || 0;
    name = (cd && cd.dissname) || '';
  } else {
    const info = r.json && r.json.data && r.json.data.info;
    songCount = (info && info.length) || 0;
  }

  res.json({
    source,
    id,
    name,
    status: r.status,
    ms: r.ms,
    songCount,
    finalUrl: r.finalUrl || target,
    rawHead: String(r.text || '').slice(0, 600)
  });
});

app.get('/api/health', (req, res) => {''', 'server 导入探针')

save(p, s)
print('server.js done')
print('PATCH28 DONE')
