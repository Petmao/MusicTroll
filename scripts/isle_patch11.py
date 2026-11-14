#!/usr/bin/env python3
import io
import re
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


# ================= server-v2: /api/search 改成多源聚合 =================
p = 'server-v2/server.js'
s = load(p)

OLD_SEARCH = r"""app.get('/api/search', auth, limit('search', 30, 60000), async (req, res) => {
  const kw = String(req.query.kw || req.query.keyword || '').trim();
  if (!kw) return res.status(400).json({ error: 'bad_keyword' });
  const rows = db.prepare("SELECT * FROM sources WHERE kind='music' AND enabled=1 ORDER BY sort ASC, id ASC").all();
  for (const src of rows) {
    const url = new URL(src.url);
    const p = src.params ? safeJson(src.params) : {};
    Object.keys(p || {}).forEach(k => url.searchParams.set(k, String(p[k]).replace('{kw}', kw)));
    if (!p || !Object.values(p).some(v => String(v).includes('{kw}'))) {
      url.searchParams.set('keyword', kw);
      url.searchParams.set('kw', kw);
    }
    const h = src.headers ? safeJson(src.headers) : {};
    const r = await fetchJson(url.toString(), { headers: h || {}, timeout: 15000 });
    if (!r.ok || !r.json) continue;
    const list = src.result_path ? pick(r.json, src.result_path) : pick(r.json, 'data') || pick(r.json, 'result') || r.json;
    if (Array.isArray(list) && list.length) {
      return res.json({ source: src.name, rows: list });
    }
    if (list && typeof list === 'object') return res.json({ source: src.name, rows: [list] });
  }
  res.json({ source: null, rows: [] });
});"""

NEW_SEARCH = r"""// 从任意对象里挑第一个非空字符串
function pickStr(o, keys) {
  for (const k of keys) {
    const v = o[k];
    if (typeof v === 'string' && v.trim()) return v.trim();
    if (typeof v === 'number') return String(v);
  }
  return '';
}

// 把不同源的返回归一化成 {title, artist, url, cover}
function normalizeItem(o) {
  if (!o || typeof o !== 'object' || Array.isArray(o)) return null;
  const title = pickStr(o, ['title', 'name', 'song', 'songname', 'songName', 'track', 'trackName']);
  if (!title) return null;
  const artist = pickStr(o, ['artist', 'singer', 'author', 'artistName', 'artists', 'singerName']);
  const url = pickStr(o, ['url', 'music_url', 'play_url', 'link', 'src', 'playUrl', 'songUrl', 'mp3']);
  const cover = pickStr(o, ['cover', 'pic', 'album_pic', 'albumPic', 'img', 'image', 'picture', 'artwork']);
  return { title, artist: artist || '未知歌手', url, cover };
}

// 递归收集，最多下钻 6 层
function deepCollect(node, out, depth) {
  if (depth > 6 || node == null) return;
  if (Array.isArray(node)) {
    for (const v of node) deepCollect(v, out, depth + 1);
    return;
  }
  if (typeof node === 'object') {
    const it = normalizeItem(node);
    if (it) { out.push(it); return; }
    for (const k of Object.keys(node)) deepCollect(node[k], out, depth + 1);
  }
}

function buildSourceUrl(src, kw) {
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
}

// 多源聚合：所有启用的音乐源并发请求，结果合并去重
app.get('/api/search', limit('search', 60, 60000), async (req, res) => {
  const kw = String(req.query.kw || req.query.keyword || '').trim();
  if (!kw) return res.status(400).json({ error: 'bad_keyword' });

  const rows = db.prepare("SELECT * FROM sources WHERE kind='music' AND enabled=1 ORDER BY sort ASC, id ASC").all();
  if (!rows.length) return res.json({ keyword: kw, count: 0, sources: [], rows: [] });

  const tasks = rows.map(async (src) => {
    let target;
    try { target = buildSourceUrl(src, kw); } catch (_) { return { name: src.name, status: 0, ms: 0, items: [] }; }
    const h = src.headers ? safeJson(src.headers) : {};
    const r = await fetchJson(target, { headers: h || {}, timeout: 15000 });
    const out = [];
    if (r.json) deepCollect(r.json, out, 0);
    db.prepare('UPDATE sources SET last_status=?, last_ms=?, checked_at=? WHERE id=?')
      .run(r.status, r.ms, now(), src.id);
    return { name: src.name, status: r.status, ms: r.ms, items: out };
  });

  const per = await Promise.all(tasks);
  const seen = new Set();
  const merged = [];
  for (const r of per) {
    for (const it of r.items) {
      const key = it.title + '|' + it.artist;
      if (seen.has(key)) continue;
      seen.add(key);
      merged.push({ title: it.title, artist: it.artist, url: it.url, cover: it.cover, source: r.name });
    }
  }

  audit(null, 'search', kw + '/' + merged.length, req.ip);
  res.json({
    keyword: kw,
    count: merged.length,
    sources: per.map(r => ({ name: r.name, status: r.status, ms: r.ms, got: r.items.length })),
    rows: merged
  });
});"""

s = sub(s, OLD_SEARCH, NEW_SEARCH, 'server 搜索聚合')
save(p, s)
print('server-v2/server.js done')

# ================= 客户端：search 走聚合接口 =================
p = 'Isle/Sources/MusicEngine.swift'
s = load(p)

s = sub(s, """    /// 音源入口统一从 Config.apiBaseURL 派生，改域名只改 Config.swift 一处
    private var apiBase: String {
        Config.apiBaseURL.appendingPathComponent("api/wxmusic").absoluteString
    }""",
    """    /// 聚合搜索入口（读服务端 sources 表，多源并发）
    private var searchBase: String {
        Config.apiBaseURL.appendingPathComponent("api/search").absoluteString
    }

    /// 单曲兜底入口（v1 上游，sources 全空时用）
    private var legacyBase: String {
        Config.apiBaseURL.appendingPathComponent("api/wxmusic").absoluteString
    }""", '客户端端点拆分')

OLD_REQ = '''    private func requestOnce(_ keyword: String) async throws -> [[String: Any]] {
        guard var comps = URLComponents(string: apiBase) else { throw EngineError.api("bad_url") }
        comps.queryItems = [
            URLQueryItem(name: "source", value: "third"),
            URLQueryItem(name: "keyword", value: keyword)
        ]
        guard let url = comps.url else { throw EngineError.api("bad_url") }
        var req = URLRequest(url: url, timeoutInterval: 40)
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")

        let data: Data
        do { (data, _) = try await URLSession.shared.data(for: req) }
        catch let e as URLError {
            switch e.code {
            case .timedOut: throw EngineError.timeout
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
                throw EngineError.offline
            default: throw EngineError.api(e.localizedDescription)
            }
        }

        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw EngineError.api("返回不是 JSON")
        }
        let code = (obj["code"] as? Int) ?? 0
        let title = (obj["title"] as? String) ?? ""
        let singer = (obj["singer"] as? String) ?? ""
        let musicURL = (obj["music_url"] as? String) ?? (obj["link"] as? String) ?? ""
        let cover = (obj["cover"] as? String) ?? ""

        guard !musicURL.isEmpty else {
            if code == 200 { throw EngineError.noUrl }
            throw EngineError.api((obj["msg"] as? String) ?? "code \(code)")
        }
        return [["title": title.isEmpty ? keyword : title,
                 "artist": singer.isEmpty ? "未知歌手" : singer,
                 "url": musicURL,
                 "cover": cover]]
    }'''

NEW_REQ = '''    private func requestOnce(_ keyword: String) async throws -> [[String: Any]] {
        if let rows = try? await requestAggregated(keyword), !rows.isEmpty {
            return rows
        }
        return try await requestLegacy(keyword)
    }

    /// 走服务端 /api/search：服务端读 sources 表，多源并发，合并去重
    private func requestAggregated(_ keyword: String) async throws -> [[String: Any]] {
        guard var comps = URLComponents(string: searchBase) else { throw EngineError.api("bad_url") }
        comps.queryItems = [URLQueryItem(name: "kw", value: keyword)]
        guard let url = comps.url else { throw EngineError.api("bad_url") }
        var req = URLRequest(url: url, timeoutInterval: 40)
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        if let t = Keychain.get("token") {
            req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        do { (data, _) = try await URLSession.shared.data(for: req) }
        catch let e as URLError {
            switch e.code {
            case .timedOut: throw EngineError.timeout
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
                throw EngineError.offline
            default: throw EngineError.api(e.localizedDescription)
            }
        }

        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = obj["rows"] as? [[String: Any]] else { return [] }

        return rows.compactMap { r -> [String: Any]? in
            let u = (r["url"] as? String) ?? ""
            guard !u.isEmpty else { return nil }
            return ["title": (r["title"] as? String) ?? keyword,
                    "artist": (r["artist"] as? String) ?? "未知歌手",
                    "url": u,
                    "cover": (r["cover"] as? String) ?? ""]
        }
    }

    /// v1 上游单曲兜底
    private func requestLegacy(_ keyword: String) async throws -> [[String: Any]] {
        guard var comps = URLComponents(string: legacyBase) else { throw EngineError.api("bad_url") }
        comps.queryItems = [
            URLQueryItem(name: "source", value: "third"),
            URLQueryItem(name: "keyword", value: keyword)
        ]
        guard let url = comps.url else { throw EngineError.api("bad_url") }
        var req = URLRequest(url: url, timeoutInterval: 40)
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")

        let data: Data
        do { (data, _) = try await URLSession.shared.data(for: req) }
        catch let e as URLError {
            switch e.code {
            case .timedOut: throw EngineError.timeout
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
                throw EngineError.offline
            default: throw EngineError.api(e.localizedDescription)
            }
        }

        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw EngineError.api("返回不是 JSON")
        }
        let code = (obj["code"] as? Int) ?? 0
        let title = (obj["title"] as? String) ?? ""
        let singer = (obj["singer"] as? String) ?? ""
        let musicURL = (obj["music_url"] as? String) ?? (obj["link"] as? String) ?? ""
        let cover = (obj["cover"] as? String) ?? ""

        guard !musicURL.isEmpty else {
            if code == 200 { throw EngineError.noUrl }
            throw EngineError.api((obj["msg"] as? String) ?? "code \(code)")
        }
        return [["title": title.isEmpty ? keyword : title,
                 "artist": singer.isEmpty ? "未知歌手" : singer,
                 "url": musicURL,
                 "cover": cover]]
    }'''

s = sub(s, OLD_REQ, NEW_REQ, '客户端搜索走聚合')
save(p, s)
print('MusicEngine done')

print('PATCH11 DONE')
