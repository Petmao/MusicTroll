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


# ===================== server-v2 =====================
p = 'server-v2/server.js'
s = load(p)

s = sub(s, '''function normalizeSource(r) {
  return {
    id: r.id, kind: r.kind, name: r.name, url: r.url, method: r.method,
    headers: r.headers ? safeJson(r.headers) : null,
    params: r.params ? safeJson(r.params) : null,
    resultPath: r.result_path, note: r.note,
    enabled: !!r.enabled, sort: r.sort,
    lastStatus: r.last_status, lastMs: r.last_ms, checkedAt: r.checked_at
  };
}''',
    '''function normalizeSource(r) {
  const ok = r.last_status && r.last_status >= 200 && r.last_status < 400;
  return {
    id: r.id, kind: r.kind, name: r.name, url: r.url, method: r.method,
    headers: r.headers ? safeJson(r.headers) : null,
    params: r.params ? safeJson(r.params) : null,
    resultPath: r.result_path, note: r.note,
    enabled: !!r.enabled, sort: r.sort,
    // 后台用数字，客户端用字符串，两套都给，避免类型不匹配导致解码整包失败
    lastStatus: r.last_status,
    lastMs: r.last_ms,
    last_status: r.last_status ? (ok ? 'ok' : 'fail') : null,
    last_ms: r.last_ms,
    checkedAt: r.checked_at
  };
}''', 'server normalizeSource 双字段')

s = sub(s, """  const rows = db.prepare('SELECT * FROM sources WHERE kind=? AND enabled=1 ORDER BY sort ASC, id ASC').all(kind);
  res.json({ rows: rows.map(normalizeSource) });""",
    """  const rows = db.prepare('SELECT * FROM sources WHERE kind=? AND enabled=1 ORDER BY sort ASC, id ASC').all(kind);
  res.json({ kind, rows: rows.map(normalizeSource) });""", 'server sources 带 kind')

# 在 /api/play/ticket 之前插入视频聚合接口
s = sub(s, "// ---------------- 播放票据（HMAC 短签） ----------------",
    '''// ---------------- 视频：从后台配的视频源里抽出可播地址 ----------------

function collectMedia(node, out, depth) {
  if (depth > 6 || node == null) return;
  if (Array.isArray(node)) {
    for (const v of node) collectMedia(v, out, depth + 1);
    return;
  }
  if (typeof node === 'object') {
    const url = pickStr(node, ['url', 'video', 'src', 'mp4', 'play_url', 'video_url', 'file', 'link', 'videoUrl']);
    if (/^https?:\\/\\//i.test(url)) {
      out.push({
        url,
        title: pickStr(node, ['title', 'name', 'desc', 'description', 'caption', 'text']) || '',
        cover: pickStr(node, ['cover', 'pic', 'poster', 'image', 'thumb', 'thumbnail', 'img']) || ''
      });
      return;
    }
    for (const k of Object.keys(node)) collectMedia(node[k], out, depth + 1);
  }
}

app.get('/api/videos', auth, limit('videos', 60, 60000), async (req, res) => {
  const srcId = Number(req.query.src || 0);
  const rows = srcId
    ? db.prepare("SELECT * FROM sources WHERE kind='video' AND id=? AND enabled=1").all(srcId)
    : db.prepare("SELECT * FROM sources WHERE kind='video' AND enabled=1 ORDER BY sort ASC, id ASC").all();

  if (!rows.length) return res.json({ count: 0, sources: [], rows: [] });

  const out = [];
  const seen = new Set();
  const report = [];

  for (const src of rows) {
    let target;
    try { target = buildSourceUrl(src, String(req.query.kw || '')); } catch (_) { continue; }
    const h = src.headers ? safeJson(src.headers) : {};
    const r = await fetchJson(target, { headers: h || {}, timeout: 15000 });
    const items = [];
    if (r.json) collectMedia(r.json, items, 0);
    db.prepare('UPDATE sources SET last_status=?, last_ms=?, checked_at=? WHERE id=?')
      .run(r.status, r.ms, now(), src.id);
    report.push({ name: src.name, status: r.status, ms: r.ms, got: items.length });

    for (const it of items) {
      if (seen.has(it.url)) continue;
      seen.add(it.url);
      out.push({ url: it.url, title: it.title, cover: it.cover, source: src.name });
    }
  }

  audit(null, 'videos', String(out.length), req.ip);
  res.json({ count: out.length, sources: report, rows: out });
});

// ---------------- 播放票据（HMAC 短签） ----------------''', 'server 视频聚合接口')

save(p, s)
print('server-v2/server.js done')

# ===================== APIExtras =====================
p = 'Isle/Network/APIExtras.swift'
s = load(p)

if 'struct VideoItem' not in s:
    s += '''

/// 视频源聚合结果
struct VideoItem: Codable, Identifiable {
    var id: String { url }
    let url: String
    let title: String?
    let cover: String?
    let source: String?
}

struct VideosResp: Codable {
    let count: Int
    let rows: [VideoItem]
}

extension APIClient {
    /// 从后台配置的视频源里抽出可播地址（服务端已做归一化与去重）
    func videos(srcId: Int? = nil) async throws -> [VideoItem] {
        let q = srcId.map { "?src=\\($0)" } ?? ""
        let r: VideosResp = try await get("/api/videos\\(q)")
        return r.rows
    }
}
'''
    print('OK   APIExtras 视频模型')
else:
    print('SKIP APIExtras 视频模型')

save(p, s)
print('APIExtras done')

# ===================== EyesView =====================
p = 'Isle/Features/EyesView.swift'
s = load(p)

s = sub(s, "    @State private var sources: [SourceItem] = []",
    "    @State private var videos: [VideoItem] = []", 'Eyes 状态')

s = sub(s, """            } else if sources.isEmpty {
                emptyState""",
    """            } else if videos.isEmpty {
                emptyState""", 'Eyes 空态判断')

s = sub(s, """            Text(sources[min(index, sources.count - 1)].name)
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.white.opacity(0.8))
            Text("该源不是直链视频").font(.system(size: 10.5)).foregroundStyle(Color.white.opacity(0.35))""",
    """            Text(videos[min(index, videos.count - 1)].title ?? "视频")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.white.opacity(0.8))
            Text("这条地址不是可播视频").font(.system(size: 10.5)).foregroundStyle(Color.white.opacity(0.35))""", 'Eyes 非直链文案')

s = sub(s, '''    private func load() async {
        loading = true
        sources = (try? await APIClient.shared.sources(kind: "video")) ?? []
        loading = false
        prepare(0)
    }

    private func step(_ delta: Int) {
        guard !sources.isEmpty else { return }
        let next = (index + delta + sources.count) % sources.count
        prepare(next)
    }

    private func prepare(_ i: Int) {
        guard !sources.isEmpty else { return }
        index = max(0, min(i, sources.count - 1))
        let src = sources[index]
        queuePlayer?.pause()
        looper = nil
        queuePlayer = nil

        guard let url = URL(string: src.url),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else { return }''',
    '''    private func load() async {
        loading = true
        // 不再直接拿源地址当视频播，交给服务端 /api/videos 从源里抽可播 url
        videos = (try? await APIClient.shared.videos()) ?? []
        loading = false
        prepare(0)
    }

    private func step(_ delta: Int) {
        guard !videos.isEmpty else { return }
        let next = (index + delta + videos.count) % videos.count
        prepare(next)
    }

    private func prepare(_ i: Int) {
        guard !videos.isEmpty else { return }
        index = max(0, min(i, videos.count - 1))
        let v = videos[index]
        queuePlayer?.pause()
        looper = nil
        queuePlayer = nil

        guard let url = URL(string: v.url),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else { return }''', 'Eyes 改走视频聚合')

save(p, s)
print('EyesView done')

print('PATCH15 DONE')
