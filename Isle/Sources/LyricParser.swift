import Foundation

struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    let time: TimeInterval
    let text: String
}

/// LRC 解析：支持 [mm:ss.xx] / [mm:ss.xxx] 多标签、去元信息行
enum LyricParser {

    static func parse(_ raw: String) -> [LyricLine] {
        var out: [LyricLine] = []
        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
                             .replacingOccurrences(of: "\r", with: "\n")

        for rawLine in normalized.components(separatedBy: "\n") {
            var rest = rawLine.trimmingCharacters(in: .whitespaces)
            guard !rest.isEmpty else { continue }

            var stamps: [TimeInterval] = []
            while rest.hasPrefix("["), let close = rest.firstIndex(of: "]") {
                let tag = String(rest[rest.index(after: rest.startIndex)..<close])
                rest = String(rest[rest.index(after: close)...])
                    .trimmingCharacters(in: .whitespaces)

                if let t = seconds(from: tag) {
                    stamps.append(t)
                }
                // 非时间标签（ar/ti/al/by/offset）直接丢弃
            }

            guard !rest.isEmpty else { continue }
            for t in stamps {
                out.append(LyricLine(time: t, text: rest))
            }
        }

        return out.sorted { $0.time < $1.time }
    }

    static func currentIndex(_ lines: [LyricLine], at t: TimeInterval) -> Int {
        guard !lines.isEmpty else { return 0 }
        var idx = 0
        for (i, l) in lines.enumerated() {
            if l.time <= t + 0.15 { idx = i } else { break }
        }
        return idx
    }

    private static func seconds(from tag: String) -> TimeInterval? {
        let parts = tag.components(separatedBy: ":")
        guard parts.count >= 2, parts.count <= 3 else { return nil }

        guard let m = Double(parts[0]) else { return nil }
        let secPart = parts[1].replacingOccurrences(of: ",", with: ".")
        guard let s = Double(secPart) else { return nil }

        var value = m * 60 + s
        if parts.count == 3 {
            let fracPart = parts[2]
            guard let frac = Double(fracPart) else { return nil }
            value += frac / pow(10.0, Double(fracPart.count))
        }
        return value > 0 ? value : nil
    }
}
