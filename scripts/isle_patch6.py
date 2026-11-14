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


# ---------- 客户端：音源地址统一走 Config ----------
p = 'Isle/Sources/MusicEngine.swift'
s = load(p)

s = sub(s, "    private let apiBase = \"https://api.irepo.cn/api/wxmusic\"",
    """    /// 音源入口统一从 Config.apiBaseURL 派生，改域名只改 Config.swift 一处
    private var apiBase: String {
        Config.apiBaseURL.appendingPathComponent("api/wxmusic").absoluteString
    }""", '客户端音源域名')

save(p, s)
print('MusicEngine done')

# ---------- 服务端：兼容 v1 客户端的 /api/wxmusic 转发 ----------
p = 'server-v2/server.js'
s = load(p)

s = sub(s, "app.get('/api/health', (req, res) => {",
    """// ---------------- 兼容 v1 客户端：音源转发 ----------------

app.get('/api/wxmusic', limit('wx', 60, 60000), async (req, res) => {
  const base = process.env.UPSTREAM_MUSIC_API || 'https://api.irepo.cn/api/wxmusic';
  let u;
  try { u = new URL(base); } catch (_) { return res.status(500).json({ code: 500, msg: 'bad_upstream' }); }
  Object.keys(req.query).forEach(k => u.searchParams.set(k, String(req.query[k])));
  const r = await fetchJson(u.toString(), {
    headers: { 'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)' },
    timeout: 25000
  });
  if (!r.json) {
    return res.status(502).json({ code: 502, msg: 'upstream_failed', status: r.status });
  }
  audit(null, 'wxmusic_proxy', String(req.query.keyword || '') + '/' + r.status, req.ip);
  res.json(r.json);
});

app.get('/api/health', (req, res) => {""", '服务端音源转发')

save(p, s)
print('server-v2/server.js done')

# ---------- 环境变量样例 ----------
p = 'server-v2/.env.example'
s = load(p)

s = sub(s, "CHECKIN_POINTS=30",
    """CHECKIN_POINTS=30

# 兼容 v1 客户端的音源上游（/api/wxmusic 转发目标）
UPSTREAM_MUSIC_API=https://api.irepo.cn/api/wxmusic""", 'env 音源上游')

save(p, s)
print('.env.example done')

# ---------- 文档：域名统一为 ys.irepo.cn ----------
p = 'server-v2/README.md'
s = load(p)
before = s.count('ys.example.com')
s = s.replace('ys.example.com', 'ys.irepo.cn')
s = s.replace('door.example.com', 'door.ys.irepo.cn')
print('OK   README 替换示例域名 x' + str(before))

s = sub(s, """```swift
static let apiBaseURL: URL = {
    let parts = [\"aHR0cHM6Ly8=\", \"eXMuaXJlcG8uY24=\"]  // https:// + 域名
    ...
}()
```""",
    """当前 `Isle/Config.swift` 已经指向 `https://ys.irepo.cn`，两段 Base64 分别是：

```swift
let parts = [\"aHR0cHM6Ly8=\", \"eXMuaXJlcG8uY24=\"]
//              https://          ys.irepo.cn
```

要换域名，分别生成两段：""", 'README Config 段')

save(p, s)
print('README done')

print('PATCH6 DONE')
