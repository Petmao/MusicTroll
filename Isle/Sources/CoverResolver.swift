import Foundation

/// 专辑封面解析：先用搜索接口自带的 cover，空则回退网易云。
/// 链路：search/get/web 取 song id → song/detail 取 album.picUrl → 加 ?param=600y600
/// 已验证：夜航星 → https://p1.music.126.net/EIJc2Wt5AEsIHCFcVxm6pg==/109951165033567317.jpg
enum CoverResolver {
    private static var cache: [String: String] = [:]

    static func albumArt(title: String, artist: String) async -> String? {
        let clean = normalize(title)
        guard !clean.isEmpty else { return nil }
        let key = clean + "|" + artist
        if let hit = cache[key] { return hit }

        var queries = [clean]
        if !artist.isEmpty { queries.append(clean + " " + artist) }

        for q in queries {
            if let url = await lookup(q) {
                cache[key] = url
                return url
            }
        }
        return nil
    }

    private static func normalize(_ s: String) -> String {
        var t = s
        for sep in ["-《", "《", "（", "(", "【", "["] {
            if let r = t.range(of: sep) { t = String(t[..<r.lowerBound]) }
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func request(_ url: URL) async -> Data? {
        var req = URLRequest(url: url, timeoutInterval: 12)
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)",
                     forHTTPHeaderField: "User-Agent")
        req.setValue("https://music.163.com/", forHTTPHeaderField: "Referer")
        guard let (data, _) = try? await URLSession.shared.data(for: req) else { return nil }
        return data
    }

    private static func lookup(_ keyword: String) async -> String? {
        guard let q = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let u = URL(string: "https://music.163.com/api/search/get/web?s=\(q)&type=1&limit=1&offset=0"),
              let data = await request(u),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = obj["result"] as? [String: Any],
              let songs = result["songs"] as? [[String: Any]],
              let first = songs.first,
              let sid = first["id"] as? Int else { return nil }

        guard let du = URL(string: "https://music.163.com/api/song/detail?ids=%5B\(sid)%5D"),
              let d2 = await request(du),
              let o2 = try? JSONSerialization.jsonObject(with: d2) as? [String: Any],
              let arr = o2["songs"] as? [[String: Any]],
              let s0 = arr.first,
              let album = s0["album"] as? [String: Any],
              let pic = album["picUrl"] as? String,
              !pic.isEmpty else { return nil }

        return pic + "?param=600y600"
    }
}
