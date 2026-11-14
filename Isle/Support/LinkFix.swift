import Foundation
import Darwin
import CoreImage
import UIKit
import Metal
import OpenGLES

/// 手工 swiftc 链接的进程里，UIKit 的键盘候选栏会走
/// +[CUIShapeEffectStack sharedCIContext] → [CIContext contextWithOptions:nil]，
/// 先试 Metal，MTLCreateSystemDefaultDevice() 为 nil 时退 EAGL，
/// 两条后备路径的私有符号在未链接二进制里为 NULL，调用即 pc=0。
///
/// 分两段：
///   load()   只 dlopen，纯 C 调用，App.init 阶段安全；
///   warmUp() 碰图形栈，必须等 UIApplication 启动完成之后调用。
enum LinkFix {
    private static var loaded = false
    private static var warmed = false

    // 必须常驻：device / context 一旦释放，CoreImage 再次建 context 又会走空指针。
    private static var metalDevice: MTLDevice?
    private static var eaglContext: EAGLContext?

    static func load() {
        guard !loaded else { return }
        loaded = true

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
    }

    /// 在 View 的 task / onAppear 里调用。会再延后一帧，
    /// 保证 runloop 已经跑起来、图形服务可用。
    static func warmUp() {
        guard loaded, !warmed else { return }
        warmed = true

        DispatchQueue.main.async {
            // 1) Metal 路径：拿到 device 并常驻，CIContext 就走 Metal 而不是 EAGL
            metalDevice = MTLCreateSystemDefaultDevice()

            // 2) EAGL 后备：建一个 GL 上下文设为 current，
            //    CI::GLContext 构造时会共享它
            if let ctx = EAGLContext(api: .openGLES2) {
                EAGLContext.setCurrent(ctx)
                eaglContext = ctx
            }

            // 3) CPU 路径预热，保证 CoreImage 初始化链完整
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
}
