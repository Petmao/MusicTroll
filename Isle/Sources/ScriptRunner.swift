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

enum ScriptError: Error, LocalizedError {
    case syntax(String)
    case noFunction(String)
    case runtime(String)
    case notJS(String)

    var errorDescription: String? {
        switch self {
        case .syntax(let s): return "音源脚本语法错误：\(s)"
        case .noFunction(let f): return "音源脚本缺少函数 \(f)"
        case .runtime(let s): return "音源脚本运行出错：\(s)"
        case .notJS(let s): return "音源地址返回的不是 JS：\(s)"
        }
    }
}

/// 用 JavaScriptCore 跑音源脚本
/// 约定函数：search(keyword) / getUrl(trackJson) / charts()
/// 兼容 CommonJS：module.exports.search、exports.search 也会被自动提升到全局
final class ScriptRunner {
    private let ctx: JSContext
    let name: String
    let preview: String

    init(script: String, name: String) throws {
        self.name = name
        let trimmed = script.trimmingCharacters(in: .whitespacesAndNewlines)
        self.preview = String(trimmed.prefix(120)).replacingOccurrences(of: "\n", with: " ")

        // 预检：拿到的是网页 / JSON 错误而不是脚本
        if trimmed.hasPrefix("<!")
            || trimmed.lowercased().hasPrefix("<html")
            || trimmed.hasPrefix("Cannot ") {
            throw ScriptError.notJS(preview)
        }
        if trimmed.hasPrefix("{") && trimmed.contains("\"error\"") {
            throw ScriptError.notJS(preview)
        }

        guard let context = JSContext() else { throw ScriptError.runtime("JSContext init failed") }
        self.ctx = context

        let httpBlock: @convention(block) (String) -> String = { url in
            HTTP.syncGet(url) ?? ""
        }
        ctx.setObject(httpBlock, forKeyedSubscript: "nativeHttpGet" as NSString)

        // 常见运行环境垫片，避免脚本一上来就 ReferenceError
        ctx.evaluateScript("""
        var window = this; var global = this; var globalThis = this;
        var module = { exports: {} }; var exports = module.exports;
        var console = { log: function(){}, warn: function(){}, error: function(){}, info: function(){} };
        var lx = { env: {}, version: '2.0.0', EVENT_NAMES: { request: 'request', inited: 'inited', updateAlert: 'updateAlert' },
                   request: function(o, cb){ try { cb && cb({ statusCode: 200, body: nativeHttpGet(o.url) }); } catch(e){} },
                   send: function(){}, on: function(){}, utils: {} };
        var __isleExport = null;
        """)

        var thrown: String?
        ctx.exceptionHandler = { _, exc in thrown = exc?.toString() ?? "unknown" }

        ctx.evaluateScript(trimmed)

        // CommonJS 风格：把 module.exports 里的函数提到全局
        ctx.evaluateScript("""
        (function(){
          try {
            var e = (typeof module !== 'undefined' && module.exports) ? module.exports : exports;
            if (e) {
              ['search','getUrl','charts','musicSearch','getMusicUrl'].forEach(function(k){
                if (typeof e[k] === 'function' && typeof this[k] === 'undefined') { this[k] = e[k]; }
              }, this);
            }
          } catch(err) {}
        })();
        """)

        if let t = thrown {
            // 常见于脚本用了 import/export 模块语法，再试一次 CJS 包装
            thrown = nil
            let wrapped = "(function(module, exports, require, console, lx){ " + trimmed + "\n})(module, exports, function(){return {}}, console, lx);"
            ctx.evaluateScript(wrapped)
            if let t2 = thrown {
                throw ScriptError.syntax("\(t2) ｜ 片段：\(preview)")
            }
        }
    }

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
