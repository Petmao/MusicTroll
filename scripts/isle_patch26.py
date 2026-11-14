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

# 1) 搜索缓存 + 总超时
s = sub(s, "// 多源聚合：所有启用的音乐源并发请求，结果合并去重",
    '''// 搜索缓存：同关键词 60 秒内直接复用，避免每次全打一遍
const SEARCH_TTL_MS = 60 * 1000;
const SEARCH_CACHE_MAX = 120;
const SEARCH_BUDGET_MS = 7000;
const searchCache = new Map();

function searchCacheGet(key) {
  const hit = searchCache.get(key);
  if (!hit) return null;
  if (Date.now() - hit.t > SEARCH_TTL_MS) {
    searchCache.delete(key);
    return null;
  }
  return hit.data;
}

function searchCachePut(key, data) {
  searchCache.set(key, { t: Date.now(), data });
  while (searchCache.size > SEARCH_CACHE_MAX) {
    const oldest = searchCache.keys().next().value;
    searchCache.delete(oldest);
  }
}

// 多源聚合：所有启用的音乐源并发请求，结果合并去重''', 'server 搜索缓存')

s = sub(s, '''  const rows = db.prepare("SELECT * FROM sources WHERE kind='music' AND enabled=1 ORDER BY sort ASC, id ASC").all();
  if (!rows.length) return res.json({ keyword: kw, count: 0, sources: [], rows: [] });''',
    '''  const cached = searchCacheGet(kw);
  if (cached) return res.json(cached);

  const rows = db.prepare("SELECT * FROM sources WHERE kind='music' AND enabled=1 ORDER BY sort ASC, id ASC").all();
  if (!rows.length) {
    const empty = { keyword: kw, count: 0, sources: [], rows: [] };
    searchCachePut(kw, empty);
    return res.json(empty);
  }''', 'server 命中缓存')

s = sub(s, '        timeout: 15000\n      });\n    } else {\n      let target;\n      try { target = buildSourceUrl(src, kw); } catch (_) { return { name: src.name, status: 0, ms: 0, items: [] }; }\n      r = await fetchJson(target, { headers: h || {}, timeout: 15000 });',
    '        timeout: 6000\n      });\n    } else {\n      let target;\n      try { target = buildSourceUrl(src, kw); } catch (_) { return { name: src.name, status: 0, ms: 0, items: [] }; }\n      r = await fetchJson(target, { headers: h || {}, timeout: 6000 });', 'server 单源超时降到 6s')

s = sub(s, '''  const per = await Promise.all(tasks);
  const seen = new Set();''',
    '''  // 总预算 7 秒：慢的源直接丢掉，先把拿到的结果返回，不让用户等满 6 秒×N
  const per = [];
  await new Promise((resolve) => {
    let done = 0;
    const timer = setTimeout(resolve, SEARCH_BUDGET_MS);
    tasks.forEach((task) => {
      task
        .then((r) => { per.push(r); })
        .catch(() => {})
        .finally(() => {
          done += 1;
          if (done === tasks.length) {
            clearTimeout(timer);
            resolve();
          }
        });
    });
  });

  const seen = new Set();''', 'server 总预算')

s = sub(s, '''  audit(null, 'search', kw + '/' + merged.length, req.ip);
  res.json({
    keyword: kw,
    count: merged.length,
    sources: per.map(r => ({ name: r.name, status: r.status, ms: r.ms, got: r.items.length })),
    rows: merged
  });''',
    '''  audit(null, 'search', kw + '/' + merged.length, req.ip);
  const payload = {
    keyword: kw,
    count: merged.length,
    sources: per.map(r => ({ name: r.name, status: r.status, ms: r.ms, got: r.items.length })),
    rows: merged
  };
  if (merged.length) searchCachePut(kw, payload);
  res.json(payload);''', 'server 写缓存')

save(p, s)
print('server.js done')
print('PATCH26 DONE')
