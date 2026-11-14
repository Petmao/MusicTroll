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


# ============ core.js: fetchJson 默认浏览器头 ============
p = 'server-v2/core.js'
s = load(p)

s = sub(s, "async function fetchJson(url, opt) {",
    '''const DEFAULT_FETCH_HEADERS = {
  'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
  'Accept': 'application/json, text/plain, */*',
  'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8'
};

async function fetchJson(url, opt) {''', 'core 默认请求头')

s = sub(s, "    const res = await fetch(url, Object.assign({}, opt, { signal: ctl.signal }));",
    '''    const merged = Object.assign({}, opt, {
      signal: ctl.signal,
      headers: Object.assign({}, DEFAULT_FETCH_HEADERS, (opt && opt.headers) || {})
    });
    const res = await fetch(url, merged);''', 'core 合并请求头')

save(p, s)
print('core.js done')

# ============ server.js: probeSource 替换 {kw} 并返回响应片段 ============
p = 'server-v2/server.js'
s = load(p)

s = sub(s, '''async function probeSource(src) {
  const url = new URL(src.url);
  const p = src.params ? safeJson(src.params) : null;
  if (p) Object.keys(p).forEach(k => url.searchParams.set(k, p[k]));
  const h = src.headers ? safeJson(src.headers) : {};
  const r = await fetchJson(url.toString(), { method: src.method || 'GET', headers: h || {}, timeout: 12000 });
  db.prepare('UPDATE sources SET last_status=?, last_ms=?, checked_at=? WHERE id=?')
    .run(r.status, r.ms, now(), src.id);
  return { status: r.status, ms: r.ms, ok: r.ok };
}''',
    '''async function probeSource(src) {
  // 关键：测试也要走 buildSourceUrl，否则地址里的 {kw} 会原样发给上游，
  // 上游收到 %7Bkw%7D 基本都回 403 / 400。
  let target;
  try {
    target = buildSourceUrl(src, '测试');
  } catch (_) {
    target = String(src.url);
  }

  const h = src.headers ? safeJson(src.headers) : {};
  const r = await fetchJson(target, {
    method: src.method || 'GET',
    headers: h || {},
    timeout: 12000
  });

  db.prepare('UPDATE sources SET last_status=?, last_ms=?, checked_at=? WHERE id=?')
    .run(r.status, r.ms, now(), src.id);

  return {
    status: r.status,
    ms: r.ms,
    ok: r.ok,
    url: target,
    snippet: String(r.text || '').slice(0, 240)
  };
}''', 'server probeSource 替换 kw')

save(p, s)
print('server.js done')

# ============ admin.html: 测试结果带原文片段 ============
p = 'server-v2/public/admin.html'
s = load(p)

s = sub(s, """.then(function (r) { alert('状态 ' + r.status + ' · ' + r.ms + 'ms'); go(document.querySelector('aside a.on').dataset.v); })""",
    """.then(function (r) {
      var msg = '状态 ' + r.status + ' · ' + r.ms + 'ms';
      if (r.url) msg += '\\n' + r.url;
      if (r.snippet) msg += '\\n\\n' + r.snippet;
      alert(msg);
      go(document.querySelector('aside a.on').dataset.v);
    })""", 'admin 测试提示')

save(p, s)
print('admin.html done')

print('PATCH14 DONE')
