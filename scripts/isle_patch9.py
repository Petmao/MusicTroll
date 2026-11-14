#!/usr/bin/env python3
import io
import sys


def load(p):
    with io.open(p, encoding='utf-8') as f:
        return f.read()


def save(p, s):
    with io.open(p, 'w', encoding='utf-8') as f:
        f.write(s)


def sub(s, old, new, label):
    if old not in s:
        if new and new in s:
            print('SKIP ' + label)
            return s
        print('MISS ' + label)
        sys.exit(1)
    print('OK   ' + label)
    return s.replace(old, new, 1)


# 注意：本脚本只改源码与 build.sh，不碰 .github/workflows。
# GITHUB_TOKEN 没有 workflows 写权限，改 workflow 会被 remote rejected。

# ---------- build.sh：补 Metal 系框架 ----------
p = 'build.sh'
s = load(p)

s = sub(s, """  -framework CoreImage -framework OpenGLES -framework QuartzCore \\
  -framework CoreGraphics -framework CoreText -framework Foundation""",
    """  -framework CoreImage -framework Metal -framework MetalKit \\
  -framework CoreVideo -framework OpenGLES -framework QuartzCore \\
  -framework CoreGraphics -framework CoreText -framework Foundation""", 'build.sh 链接 Metal')

s = sub(s, 'VERSION="${VERSION:-1.6.0}"', 'VERSION="${VERSION:-1.12.0}"', 'build.sh 默认版本')

save(p, s)
print('build.sh done')

# ---------- LinkFix ----------
p = 'Isle/Support/LinkFix.swift'
s = load(p)

s = sub(s, "import Foundation\nimport Darwin",
    "import Foundation\nimport Darwin\nimport CoreImage\nimport UIKit", 'LinkFix 头文件')

s = sub(s, '''        let paths = [
            "/System/Library/Frameworks/OpenGLES.framework/OpenGLES",
            "/System/Library/Frameworks/CoreImage.framework/CoreImage",
            "/System/Library/Frameworks/QuartzCore.framework/QuartzCore",
            "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics",
            "/System/Library/Frameworks/CoreText.framework/CoreText"
        ]
        for p in paths {
            _ = dlopen(p, RTLD_NOW | RTLD_GLOBAL)
        }''',
    '''        let paths = [
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
                   colorSpace: nil)''', 'LinkFix 补 Metal 与预热')

save(p, s)
print('LinkFix done')

# ---------- CymusicPalette：取色退出 GPU ----------
p = 'Isle/Player/CymusicPalette.swift'
s = load(p)

s = sub(s, 'let ctx = CIContext(options: [.workingColorSpace: NSNull()])',
    '''let ctx = CIContext(options: [.workingColorSpace: NSNull(),
                                      .useSoftwareRenderer: true])''', '取色 CIContext 走 CPU')

save(p, s)
print('CymusicPalette done')

print('PATCH9 DONE')
