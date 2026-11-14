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

s = sub(s, '''function buildSourceUrl(src, kw) {
  const url = new URL(src.url);
  const p = src.params ? safeJson(src.params) : null;
  let injected = false;
  if (p) {
    for (const k of Object.keys(p)) {
      const v = String(p[k]);
      if (v.includes('{kw}')) {
        url.searchParams.set(k, v.split('{kw}').join(kw));
        injected = true;
      } else {
        url.searchParams.set(k, v);
      }
    }
  }
  if (!injected) {
    if (url.searchParams.has('kw')) url.searchParams.set('kw', kw);
    else if (url.searchParams.has('keyword')) url.searchParams.set('keyword', kw);
    else if (url.searchParams.has('w')) url.searchParams.set('w', kw);
    else url.searchParams.set('keyword', kw);
  }
  return url.toString();
}''',
    '''function buildSourceUrl(src, kw) {
  // 地址栏里直接写的 {kw}（例如 ?id={kw}、?s={kw}）也要替换，
  // 否则上游会收到字面量 "%7Bkw%7D"。先替换再解析，避免二次编码。
  const encoded = encodeURIComponent(kw);
  const raw = String(src.url).split('{kw}').join(encoded);
  let url;
  try { url = new URL(raw); } catch (_) { return String(src.url); }

  const p = src.params ? safeJson(src.params) : null;
  let injected = String(src.url).includes('{kw}');

  if (p) {
    for (const k of Object.keys(p)) {
      const v = String(p[k]);
      if (v.includes('{kw}')) {
        url.searchParams.set(k, v.split('{kw}').join(kw));
        injected = true;
      } else {
        url.searchParams.set(k, v);
      }
    }
  }

  if (!injected) {
    if (url.searchParams.has('kw')) url.searchParams.set('kw', kw);
    else if (url.searchParams.has('keyword')) url.searchParams.set('keyword', kw);
    else if (url.searchParams.has('w')) url.searchParams.set('w', kw);
    else if (url.searchParams.has('s')) url.searchParams.set('s', kw);
    else if (url.searchParams.has('q')) url.searchParams.set('q', kw);
    else url.searchParams.set('keyword', kw);
  }

  return url.toString();
}''', 'buildSourceUrl 支持地址内 {kw}')

save(p, s)
print('server-v2/server.js done')
print('PATCH13 DONE')
