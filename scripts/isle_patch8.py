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

# ---------- LinkFix：补 dlopen 与 CIContext 预热 ----------
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
        // 这里先把 CoreImage 的 CPU 路径完整跑一遍，保证符号表就位。
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

# ---------- 取色 CIContext 退出 GPU ----------
p = 'Isle/Player/CymusicPalette.swift'
s = load(p)

s = sub(s, 'let ctx = CIContext(options: [.workingColorSpace: NSNull()])',
    '''let ctx = CIContext(options: [.workingColorSpace: NSNull(),
                                      .useSoftwareRenderer: true])''', '取色 CIContext 走 CPU')

save(p, s)
print('CymusicPalette done')

# ---------- 版本号 ----------
p = '.github/workflows/build.yml'
s = load(p)

s = sub(s, 'run: VERSION=1.11.0 bash build.sh both',
    'run: VERSION=1.12.0 bash build.sh both', 'workflow 版本号')

s = sub(s, 'tag_name: v1.11.0', 'tag_name: v1.12.0', 'workflow tag')

s = sub(s, 'name: 屿声音乐 v1.11.0（品牌区 + 版本号可见）',
    'name: 屿声音乐 v1.12.0（键盘候选栏崩溃修复）', 'workflow release 标题')

save(p, s)
print('build.yml done')

print('PATCH8 DONE')
