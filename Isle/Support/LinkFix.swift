import Foundation
import Darwin

/// 用 swiftc 手工链接时，UIKit 的部分渲染路径（键盘候选栏 / SF Symbol 着色 / CIContext）
/// 会走到 CoreImage → OpenGL ES。若二进制未链接这两个框架，内部函数指针为 NULL，
/// 一旦触发就会跳到 0 地址崩溃（EXC_BAD_ACCESS at 0x0）。
/// 这里在启动时显式 dlopen，保证符号已就绪。
enum LinkFix {
    private static var done = false

    static func load() {
        guard !done else { return }
        done = true
        let paths = [
            "/System/Library/Frameworks/OpenGLES.framework/OpenGLES",
            "/System/Library/Frameworks/CoreImage.framework/CoreImage",
            "/System/Library/Frameworks/QuartzCore.framework/QuartzCore",
            "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics",
            "/System/Library/Frameworks/CoreText.framework/CoreText"
        ]
        for p in paths {
            _ = dlopen(p, RTLD_NOW | RTLD_GLOBAL)
        }
    }
}
