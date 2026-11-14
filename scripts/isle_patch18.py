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

# 1) 探测：GET 十二个参数名，再试 POST JSON
s = sub(s, '''async function guessKwParam(rawUrl) {
  const candidates = ['kw', 'keyword', 'keywords', 'w', 'word', 's', 'q', 'query', 'name', 'search', 'text', 'id'];
  for (const cand of candidates) {
    let u;
    try { u = new URL(rawUrl); } catch (_) { return null; }
    u.searchParams.set(cand, '夜航星');
    const r = await fetchJson(u.toString(), { timeout: 8000 });
    if (!r.ok || !r.json) continue;
    const out = [];
    deepCollect(r.json, out, 0);
    if (out.length) {
      console.log('guess param: ' + cand);
      return cand;
    }
  }
  return null;
}''',
    '''async function guessKwParam(rawUrl) {
  const getKeys = ['kw', 'keyword', 'keywords', 'w', 'word', 's', 'q', 'query', 'name', 'search', 'text', 'id'];

  // 一、GET + query 参数
  for (const cand of getKeys) {
    let u;
    try { u = new URL(rawUrl); } catch (_) { return null; }
    u.searchParams.set(cand, '夜航星');
    const r = await fetchJson(u.toString(), { timeout: 6000 });
    if (!r.ok || !r.json) continue;
    const out = [];
    deepCollect(r.json, out, 0);
    if (out.length) {
      console.log('guess GET: ' + cand);
      return cand;
    }
  }

  // 二、POST + JSON body
  const postKeys = ['keyword', 'kw', 'name', 's', 'q', 'word', 'search'];
  for (const cand of postKeys) {
    const body = {};
    body[cand] = '夜航星';
    const r = await fetchJson(String(rawUrl), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
      timeout: 6000
    });
    if (!r.ok || !r.json) continue;
    const out = [];
    deepCollect(r.json, out, 0);
    if (out.length) {
      console.log('guess POST: ' + cand);
      return 'POST:' + cand;
    }
  }

  return null;
}''', 'guessKwParam 加 POST')

# 2) method 改成可变，处理 POST: 前缀
s = sub(s, "  const { kind, name, url, method, headers, params, resultPath, note, enabled, sort } = req.body || {};",
    "  let { kind, name, url, method, headers, params, resultPath, note, enabled, sort } = req.body || {};", 'method 改 let')

s = sub(s, '''    guessed = await guessKwParam(String(url));
    if (guessed) finalParams = { [guessed]: '{kw}' };''',
    '''    guessed = await guessKwParam(String(url));
    if (guessed && guessed.startsWith('POST:')) {
      method = 'POST';
      finalParams = { [guessed.slice(5)]: '{kw}' };
    } else if (guessed) {
      finalParams = { [guessed]: '{kw}' };
    }''', '处理 POST 探测结果')

# 3) /api/search 支持 POST
s = sub(s, '''  const tasks = rows.map(async (src) => {
    let target;
    try { target = buildSourceUrl(src, kw); } catch (_) { return { name: src.name, status: 0, ms: 0, items: [] }; }
    const h = src.headers ? safeJson(src.headers) : {};
    const r = await fetchJson(target, { headers: h || {}, timeout: 15000 });''',
    '''  const tasks = rows.map(async (src) => {
    const h = src.headers ? safeJson(src.headers) : {};
    const isPost = String(src.method || 'GET').toUpperCase() === 'POST';

    let r;
    if (isPost) {
      const bodyObj = {};
      const p = src.params ? safeJson(src.params) : null;
      if (p) {
        for (const k of Object.keys(p)) bodyObj[k] = String(p[k]).split('{kw}').join(kw);
      } else {
        bodyObj.keyword = kw;
      }
      r = await fetchJson(String(src.url), {
        method: 'POST',
        headers: Object.assign({ 'Content-Type': 'application/json' }, h || {}),
        body: JSON.stringify(bodyObj),
        timeout: 15000
      });
    } else {
      let target;
      try { target = buildSourceUrl(src, kw); } catch (_) { return { name: src.name, status: 0, ms: 0, items: [] }; }
      r = await fetchJson(target, { headers: h || {}, timeout: 15000 });
    }''', 'search 支持 POST')

# 4) /api/videos 同样支持 POST
s = sub(s, '''  for (const src of rows) {
    let target;
    try { target = buildSourceUrl(src, String(req.query.kw || '')); } catch (_) { continue; }
    const h = src.headers ? safeJson(src.headers) : {};
    const r = await fetchJson(target, { headers: h || {}, timeout: 15000 });''',
    '''  for (const src of rows) {
    const h = src.headers ? safeJson(src.headers) : {};
    const isPost = String(src.method || 'GET').toUpperCase() === 'POST';

    let r;
    if (isPost) {
      r = await fetchJson(String(src.url), {
        method: 'POST',
        headers: Object.assign({ 'Content-Type': 'application/json' }, h || {}),
        body: JSON.stringify({ keyword: String(req.query.kw || '') }),
        timeout: 15000
      });
    } else {
      let target;
      try { target = buildSourceUrl(src, String(req.query.kw || '')); } catch (_) { continue; }
      r = await fetchJson(target, { headers: h || {}, timeout: 15000 });
    }''', 'videos 支持 POST')

save(p, s)
print('server.js done')
print('PATCH18 DONE')
