import Foundation

/// 服务端下发的音源 / 视频源
struct SourceItem: Codable, Identifiable {
    let id: Int
    let name: String
    let url: String
    let note: String?
    let lastStatus: String?
    let lastMs: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, url, note
        case lastStatus = "last_status"
        case lastMs = "last_ms"
    }

    var healthy: Bool? {
        guard let s = lastStatus, !s.isEmpty else { return nil }
        return s == "ok"
    }
}

struct SourcesResp: Codable {
    let kind: String
    let rows: [SourceItem]
}

extension APIClient {
    /// kind = music（需 VIP）/ video（需 SVIP）
    func sources(kind: String) async throws -> [SourceItem] {
        let r: SourcesResp = try await get("/api/sources?kind=\(kind)")
        return r.rows
    }
}
