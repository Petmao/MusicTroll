import Foundation
import JavaScriptCore

/// 极简同步 HTTP（脚本内部调用，跑在后台线程）
enum HTTP {
    static func syncGet(_ urlString: String, timeout: TimeInterval = 12) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        let sem = DispatchSemaphore(value: 0)
        var result: String?
        var req = URLRequest(url: url)
        req.timeoutInterval = timeout
        req.setValue("IsleMusic/1.5", forHTTPHeaderField: "User-Agent")
        let task = URLSession.shared.dataTask(with: req) { data, _, _ in
            if let d = data { result = String(data: d, encoding: .utf8) }
            sem.signal()
        }
        task.resume()
        _ = sem.wait(timeout: .now() + timeout + 2)
        return result
    }
}

enum ScriptError: Error {
    case syntax(String)
    case noFunction(String)
    case runtime(String)
}

/// 用 JavaScriptCore 跑一个音源脚本
/// 脚本约定：
///   function search(keyword) -> JSON 数组字符串 [{"title":"","artist":"","url":""}]
///   function getUrl(trackJson) -> 播放地址字符串（可选，若 search 已经返回 url 就不用）
///   function charts() -> JSON 对象字符串 {"抖音热歌":[{...}],"飙升榜":[...]}
/// 脚本里可用 nativeHttpGet(url) 同步发 GET
final class ScriptRunner {
    private let ctx: JSContext
    let name: String

    init(script: String, name: String) throws {
        self.name = name
        guard let context = JSContext() else { throw ScriptError.runtime("JSContext init failed") }
        self.ctx = context

        let httpBlock: @convention(block) (String) -> String = { url in
            HTTP.syncGet(url) ?? ""
        }
        ctx.setObject(httpBlock, forKeyedSubscript: "nativeHttpGet" as NSString)

        var thrown: String?
        ctx.exceptionHandler = { _, exc in
            thrown = exc?.toString() ?? "unknown"
        }
        ctx.evaluateScript(script)
        if let t = thrown { throw ScriptError.syntax(t) }
    }

    /// 调用脚本函数，返回字符串结果
    func call(_ fn: String, _ args: [Any] = []) throws -> String {
        guard let f = ctx.objectForKeyedSubscript(fn), !f.isUndefined, !f.isNull else {
            throw ScriptError.noFunction(fn)
        }
        var thrown: String?
        ctx.exceptionHandler = { _, exc in thrown = exc?.toString() ?? "unknown" }
        let res = f.call(withArguments: args)
        if let t = thrown { throw ScriptError.runtime(t) }
        guard let s = res?.toString(), res?.isUndefined == false else {
            throw ScriptError.runtime("\(fn) 返回空")
        }
        return s
    }
}
