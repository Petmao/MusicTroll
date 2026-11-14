import Foundation
import Darwin
import CoreImage
import UIKit
import Metal
import OpenGLES

/// 手工 swiftc 链接的进程里，UIKit 的键盘候选栏会走
/// +[CUIShapeEffectStack sharedCIContext] → [CIContext contextWithOptions:nil]，
/// 该 API 先试 Metal，MTLCreateSystemDefaultDevice() 为 nil 时退 EAGL，
/// 两条后备路径的私有符号在未链接的二进制里为 NULL，调用即 pc=0。
/// 这里把两条路都提前铺好并常驻持有。
enum LinkFix {
    private static var done = false

    // 必须常驻：device / context 一旦释放，CoreImage 再次建 context 时又会走空指针。
    private static var metalDevice: MTLDevice?
    private static var eaglContext: EAGLContext?

    static func load() {
        guard !done else { return }
        done = true

        let paths = [
            "/System/Library/Frameworks/Metal.framework/Metal",
            "/System/Library/Frameworks/MetalKit.framework/MetalKit",
            "/System/Library/Frameworks/CoreVideo.framework/CoreVideo",
            "/System/Library/Frameworks/OpenGLES.framework/OpenGLES",
            "/System/Library/Frameworks/OpenGLES.framework/libGLESv2.dylib",
            "/System/Library/Frameworks/OpenGLES.framework/libEGL.dylib",
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

        // 1) Metal 路径：拿到 device 并常驻，CIContext 就会走 Metal 而不是 EAGL。
        metalDevice = MTLCreateSystemDefaultDevice()

        // 2) EAGL 后备：建一个 GL 上下文并设为 current，
        //    CI::GLContext 构造时会共享它，不再自己新建。
        if let ctx = EAGLContext(api: .openGLES2) {
            EAGLContext.setCurrent(ctx)
            eaglContext = ctx
        }

        // 3) CPU 路径预热，保证 CoreImage 初始化链跑完一遍。
        let cpu = CIContext(options: [.useSoftwareRenderer: true])
        let blank = CIImage(color: CIColor(red: 0, green: 0, blue: 0))
            .cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
        var px = [UInt8](repeating: 0, count: 4)
        cpu.render(blank,
                   toBitmap: &px,
                   rowBytes: 4,
                   bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                   format: .RGBA8,
                   colorSpace: nil)
    }
}
