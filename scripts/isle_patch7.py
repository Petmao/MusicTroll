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


p = 'Isle/Design/IsleBrandMark.swift'
s = load(p)

s = sub(s, """struct IsleBrandMark: View {
    @State private var flow = false
    @State private var float = false
    @State private var flick = false""",
    """struct IsleBrandMark: View {
    @State private var float = false""", '品牌区状态收敛')

s = sub(s, '''    private var nameText: some View {
        let base = Text("屿声音乐")
            .font(.system(size: 36, weight: .black))
            .tracking(2)

        return base
            .overlay {
                GeometryReader { geo in
                    LinearGradient(colors: rainbow, startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width * 3)
                        .offset(x: flow ? -geo.size.width * 2 : 0)
                        .animation(.linear(duration: 7).repeatForever(autoreverses: false), value: flow)
                }
                .mask(base)
            }
            .opacity(flick ? 1.0 : 0.45)
            .animation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true), value: flick)
    }''',
    '''    /// 静态渐变标题。
    /// 原来的 GeometryReader + Text mask + repeatForever 扫光会让这一层
    /// 永远处于离屏重绘状态，键盘弹出触发重排时叠加 Text mask，
    /// 主线程被拖满后进程被系统杀掉（表现为点输入框闪退）。
    private var nameText: some View {
        Text("屿声音乐")
            .font(.system(size: 36, weight: .black))
            .tracking(2)
            .foregroundStyle(
                LinearGradient(colors: rainbow,
                               startPoint: .leading,
                               endPoint: .trailing)
            )
    }''', '品牌区标题改静态渐变')

s = sub(s, ".onAppear { flow = true; float = true; flick = true }",
    ".onAppear { float = true }", '品牌区 onAppear')

save(p, s)
print('IsleBrandMark done')
print('PATCH7 DONE')
