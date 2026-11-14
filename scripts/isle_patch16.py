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

# 1) 关键词参数自动探测
s = sub(s, 'async function probeSource(src) {',
    '''// 地址里没写参数名时，逐个试常见的关键词参数，哪个能出数据就用哪个
async function guessKwParam(rawUrl) {
  const candidates = ['kw', 'keyword', 'keywords', 'w', 'word', 's', 'q', 'query', 'name', 'search', 'text', 'id'];
  for (const p of candidates) {
    let u;
    try { u = new URL(rawUrl); } catch (_) { return null; }
    u.searchParams.set(p, '夜航星');
    const r = await fetchJson(u.toString(), { timeout: 8000 });
    if (!r.ok || !r.json) continue;
    const out = [];
    deepCollect(r.json, out, 0);
    if (out.length) {
      print('guess: ' + p);
      return p;
    }
  }
  return null;
}

async function probeSource(src) {''', 'server guessKwParam')

# 2) 新建源时自动补参数
s = sub(s, '''  if (!name || !url) return res.status(400).json({ error: 'bad_source' });
  const ins = db.prepare(`INSERT INTO sources''',
    '''  if (!name || !url) return res.status(400).json({ error: 'bad_source' });

  // 音乐源：地址里没写 {kw}、也没配 params 时，自动试出关键词参数名
  let finalParams = params || null;
  let guessed = null;
  if (kind === 'music' && !String(url).includes('{kw}') && !finalParams) {
    guessed = await guessKwParam(String(url));
    if (guessed) finalParams = { [guessed]: '{kw}' };
  }

  const ins = db.prepare(`INSERT INTO sources''', 'server 自动补参数前置')

s = sub(s, '''    params ? JSON.stringify(params) : null,
    resultPath || null, note || '', enabled === false ? 0 : 1,''',
    '''    finalParams ? JSON.stringify(finalParams) : null,
    resultPath || null, note || '', enabled === false ? 0 : 1,''', 'server 用 finalParams')

s = sub(s, '''  const p = await probeSource(row);
  audit(null, 'admin_add_source', kind + '/' + name + '/' + p.status, req.ip);
  res.json({ row: normalizeSource(db.prepare('SELECT * FROM sources WHERE id=?').get(row.id)), probe: p });''',
    '''  const p = await probeSource(row);
  audit(null, 'admin_add_source', kind + '/' + name + '/' + p.status, req.ip);
  res.json({
    row: normalizeSource(db.prepare('SELECT * FROM sources WHERE id=?').get(row.id)),
    probe: p,
    guessedParam: guessed
  });''', 'server 回传探测结果')

# 3) 一键导入内置源
s = sub(s, "app.get('/api/admin/sources', adminAuth, (req, res) => {",
    '''app.post('/api/admin/sources/seed', adminAuth, async (req, res) => {
  const self = 'http://127.0.0.1:' + C.port;
  const seed = [
    { kind: 'music', name: 'Meting · 网易云', url: 'https://api.i-meto.com/meting/api?server=netease&type=search&id={kw}', sort: 0 },
    { kind: 'music', name: 'Meting · QQ', url: 'https://api.i-meto.com/meting/api?server=tencent&type=search&id={kw}', sort: 1 },
    { kind: 'music', name: 'Meting · 酷狗', url: 'https://api.i-meto.com/meting/api?server=kugou&type=search&id={kw}', sort: 2 },
    { kind: 'music', name: '屿声上游', url: 'https://api.irepo.cn/api/wxmusic?source=third&keyword={kw}', sort: 3 },
    { kind: 'video', name: '内置演示片', url: self + '/feed.json', sort: 0 }
  ];

  const ins = db.prepare(`INSERT INTO sources
    (kind,name,url,method,enabled,sort,created_at)
    VALUES (?,?,?,'GET',1,?,?)`);

  let added = 0;
  const skipped = [];
  for (const it of seed) {
    if (db.prepare('SELECT 1 FROM sources WHERE url=?').get(it.url)) {
      skipped.push(it.name);
      continue;
    }
    ins.run(it.kind, it.name, it.url, it.sort, now());
    added++;
  }

  audit(null, 'admin_seed_sources', 'added ' + added, req.ip);
  res.json({ added, skipped });
});

app.get('/api/admin/sources', adminAuth, (req, res) => {''', 'server seed 接口')

save(p, s)
print('server.js done')

# ---------------- admin.html -------------
p = 'server-v2/public/admin.html'
s = load(p)

s = sub(s, """    h += '<h3>' + (kind === 'music' ? '音乐源' : '视频源') + ' <span>按 sort 升序并发请求，先到先出</span></h3>';""",
    """    h += '<h3>' + (kind === 'music' ? '音乐源' : '视频源') + ' <span>只填名称和地址就行，参数名服务端自己试</span></h3>';
    h += '<div style="margin-bottom:12px"><button onclick="seedSources()">一键导入内置源</button> <span class="hint" style="display:inline">Meting 三家 + 屿声上游 + 内置演示视频，已存在会自动跳过</span></div>';
    h += '<div id="seedOut"></div>';""", 'admin seed 按钮')

s = sub(s, """function testSrc(id) {""",
    """function seedSources() {
  api('/api/admin/sources/seed', { method: 'POST' })
    .then(function (r) {
      document.getElementById('seedOut').innerHTML = '<div class="card"><span class="tag ok">新增 ' + r.added + ' 条</span>' +
        (r.skipped && r.skipped.length ? ' <span class="hint" style="display:inline">已存在：' + esc(r.skipped.join('、')) + '</span>' : '') + '</div>';
      setTimeout(function () { go(document.querySelector('aside a.on').dataset.v); }, 900);
    })
    .catch(function (e) { alert(e.message); });
}

function testSrc(id) {""", 'admin seedSources')

s = sub(s, """  api('/api/admin/sources', { method: 'POST', body: body })
    .then(function () { sources(kind); })""",
    """  api('/api/admin/sources', { method: 'POST', body: body })
    .then(function (r) {
      if (r.guessedParam) alert('自动识别出关键词参数：' + r.guessedParam);
      sources(kind);
    })""", 'admin 提示探测参数')

save(p, s)
print('admin.html done')

print('PATCH16 DONE')
