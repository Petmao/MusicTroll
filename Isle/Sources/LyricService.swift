import Foundation

/// 歌词源：lrclib.net 优先，网易云兜底。标题会先剥掉 “-《…》”“（Live）” 这类后缀再匹配。
enum LyricService {

    static func fetch(title: String, artist: String) async -> [LyricLine] {
        let clean = normalize(title)
        guard !clean.isEmpty else { return [] }
        let cleanArtist = normalizeArtist(artist)

        if let l = await lrclibExact(title: clean, artist: cleanArtist), l.count >= 2 { return l }
        if let l = await lrclibSearch(clean), l.count >= 2 { return l }
        if let l = await netease(clean, artist: cleanArtist), l.count >= 2 { return l }
        if let l = await netease(clean, artist: ""), l.count >= 2 { return l }
        return []
    }

    // MARK: - 文本清洗

    private static func normalize(_ s: String) -> String {
        var t = s
        for sep in ["-《", "《", "（", "(", "【", "["] {
            if let r = t.range(of: sep) { t = String(t[..<r.lowerBound]) }
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeArtist(_ s: String) -> String {
        var t = s
        for sep in ["&", "/", "、", " feat", " ft."] {
            if let r = t.range(of: sep) { t = String(t[..<r.lowerBound]) }
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - lrclib

    private static func lrclibExact(title: String, artist: String) async -> [LyricLine]? {
        var comps = URLComponents(string: "https://lrclib.net/api/get")
        comps?.queryItems = [
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "track_name", value: title)
        ]
        guard let url = comps?.url, let obj = await request(url) else { return nil }
        guard let synced = obj["syncedLyrics"] as? String, !synced.isEmpty else { return nil }
        return LyricParser.parse(synced)
    }

    private static func lrclibSearch(_ title: String) async -> [LyricLine]? {
        var comps = URLComponents(string: "https://lrclib.net/api/search")
        comps?.queryItems = [URLQueryItem(name: "q", value: title)]
        guard let url = comps?.url, let arr = await requestArray(url) else { return nil }
        for item in arr {
            guard let synced = item["syncedLyrics"] as? String, !synced.isEmpty else { continue }
            let lines = LyricParser.parse(synced)
            if lines.count >= 4 { return lines }
        }
        return nil
    }

    // MARK: - 网易云兜底

    private static func netease(_ title: String, artist: String) async -> [LyricLine]? {
        var keyword = title
        if !artist.isEmpty { keyword += " " + artist }
        guard let q = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let su = URL(string: "https://music.163.com/api/search/get/web?s=\(q)&type=1&limit=5&offset=0"),
              let obj = await request(su),
              let result = obj["result"] as? [String: Any],
              let songs = result["songs"] as? [[String: Any]] else { return nil }

        for s in songs {
            guard let sid = s["id"] as? Int else { continue }
            guard let lu = URL(string: "https://music.163.com/api/song/lyric?id=\(sid)&lv=1&kv=1&tv=-1"),
                  let lobj = await request(lu),
                  let lrc = lobj["lrc"] as? [String: Any],
                  let text = lrc["lyric"] as? String else { continue }
            let lines = LyricParser.parse(text)
            if lines.count >= 4 { return lines }
        }
        return nil
    }

    // MARK: - 网络

    private static func request(_ url: URL) async -> [String: Any]? {
        guard let data = await raw(url) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func requestArray(_ url: URL) async -> [[String: Any]]? {
        guard let data = await raw(url) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]]
    }

    private static func raw(_ url: URL) async -> Data? {
        var req = URLRequest(url: url, timeoutInterval: 12)
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
                     forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if url.host?.contains("163.com") == true {
            req.setValue("https://music.163.com/", forHTTPHeaderField: "Referer")
        }
        guard let (data, resp) = try? await URLSession.shared.data(for: req) else { return nil }
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        return data
    }
}
