import Foundation
import Darwin
import CoreImage
import UIKit

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
            "/System/Library/Frameworks/Metal.framework/Metal",
            "/System/Library/Frameworks/MetalKit.framework/MetalKit",
            "/System/Library/Frameworks/CoreVideo.framework/CoreVideo",
            "/System/Library/Frameworks/OpenGLES.framework/OpenGLES",
            "/System/Library/Frameworks/CoreImage.framework/CoreImage",
            "/System/Library/Frameworks/QuartzCore.framework/QuartzCore",
            "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics",
            "/System/Library/Frameworks/CoreText.framework/CoreText",
            "/System/Library/PrivateFrameworks/CoreUI.framework/CoreUI",
            "/System/Library/PrivateFrameworks/TextInputUI.framework/TextInputUI"
        ]
        for p in paths {
            _ = dlopen(p, RTLD_NOW | RTLD_GLOBAL)
        }

        // 键盘候选栏首帧会走 +[CUIShapeEffectStack sharedCIContext]，
        // Metal 后端没就绪时退回 EAGL，符号为 NULL 直接 pc=0。
        let ctx = CIContext(options: [.useSoftwareRenderer: true])
        let blank = CIImage(color: CIColor(red: 0, green: 0, blue: 0))
            .cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
        var px = [UInt8](repeating: 0, count: 4)
        ctx.render(blank,
                   toBitmap: &px,
                   rowBytes: 4,
                   bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                   format: .RGBA8,
                   colorSpace: nil)
    }
}
