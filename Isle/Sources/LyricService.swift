import Foundation

/// 第三方歌词源：lrclib.net（开放接口，无需 key，返回带时间轴的 LRC）
enum LyricService {

    static func fetch(title: String, artist: String) async -> [LyricLine] {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return [] }

        if let l = await exact(title: t, artist: artist), !l.isEmpty { return l }
        if let l = await search(t), !l.isEmpty { return l }
        return []
    }

    // MARK: - 精确匹配

    private static func exact(title: String, artist: String) async -> [LyricLine]? {
        var comps = URLComponents(string: "https://lrclib.net/api/get")
        comps?.queryItems = [
            URLQueryItem(name: "artist_name", value: artist.isEmpty ? "" : artist),
            URLQueryItem(name: "track_name", value: title)
        ]
        guard let url = comps?.url else { return nil }
        guard let obj = await request(url) else { return nil }
        guard let synced = obj["syncedLyrics"] as? String, !synced.isEmpty else { return nil }
        return LyricParser.parse(synced)
    }

    // MARK: - 搜索兜底

    private static func search(_ title: String) async -> [LyricLine]? {
        var comps = URLComponents(string: "https://lrclib.net/api/search")
        comps?.queryItems = [URLQueryItem(name: "q", value: title)]
        guard let url = comps?.url else { return nil }
        guard let arr = await requestArray(url) else { return nil }

        for item in arr {
            guard let synced = item["syncedLyrics"] as? String, !synced.isEmpty else { continue }
            let lines = LyricParser.parse(synced)
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
        req.setValue("Isle/1.0 (https://github.com/Petmao/MusicTroll)",
                     forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let (data, resp) = try? await URLSession.shared.data(for: req) else { return nil }
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        return data
    }
}
