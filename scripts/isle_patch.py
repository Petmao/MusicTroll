#!/usr/bin/env python3
import io
import re
import sys


def load(path):
    with io.open(path, encoding='utf-8') as f:
        return f.read()


def save(path, text):
    with io.open(path, 'w', encoding='utf-8') as f:
        f.write(text)


def sub(text, old, new, label):
    if old not in text:
        if new and new in text:
            print('SKIP ' + label)
            return text
        print('MISS ' + label)
        sys.exit(1)
    print('OK   ' + label)
    return text.replace(old, new, 1)


# ---------------- RootView ----------------
path = 'Isle/App/RootView.swift'
s = load(path)

s = sub(s, """                content
                if tab != 2 {
                    TabBarView(tab: $tab)
                }""", """                content
                TabBarView(tab: $tab)""", 'root 底栏恒显')

s = sub(s, """        } else if tab == 2 {
            if auth.ent.canPlayMusic {
                PlayerView(onClose: { tab = 0 })
            } else {
                PaywallView(need: \"VIP\", feature: \"在线听歌\")
            }
        } else if tab == 3 {
            if auth.ent.canUseVideo { EyesView() } else { PaywallView(need: \"SVIP\", feature: \"养眼视频\") }
        } else {""", """        } else if tab == 2 {
            if auth.ent.canUseVideo {
                EyesView()
            } else {
                PaywallView(need: \"SVIP\", feature: \"养眼视频\", onClose: { tab = 0 })
            }
        } else {""", 'root content 四档')

NEW_TAB = """struct TabBarView: View {
    @Binding var tab: Int

    var body: some View {
        HStack(spacing: 0) {
            cell(IsleSymbol.home, \"首页\", 0)
            cell(IsleSymbol.search, \"搜索\", 1)
            cell(IsleSymbol.video, \"养眼\", 2)
            cell(IsleSymbol.me, \"我的\", 3)
        }
        .padding(.horizontal, 4)
        .frame(height: 58)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0.07, green: 0.03, blue: 0.06).opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    private func cell(_ symbol: String, _ title: String, _ index: Int) -> some View {
        Button { tab = index } label: {
            VStack(spacing: 3) {
                IsleIcon(symbol,
                         scale: .lg,
                         weight: tab == index ? .semibold : .medium,
                         tint: tab == index ? IsleColor.pinkLight : Color.white.opacity(0.38))
                Text(title)
                    .font(.system(size: 9))
                    .foregroundStyle(tab == index ? IsleColor.pinkLight : Color.white.opacity(0.38))
            }
            .padding(.top, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
    }
}
"""

rx = re.compile(r'struct TabBarView: View \{.*?\n\}\n', re.S)
if not rx.search(s):
    print('MISS root TabBarView')
    sys.exit(1)
s = rx.sub(lambda m: NEW_TAB, s, count=1)
print('OK   root TabBarView')

s = sub(s, """    @EnvironmentObject var auth: AuthStore
    @State private var tab = 0""", """    @EnvironmentObject var auth: AuthStore
    @StateObject private var player = PlayerPresenter.shared
    @State private var tab = 0""", 'root presenter 状态')

s = sub(s, """        .preferredColorScheme(.dark)
    }""", """        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $player.show) {
            CymusicPlayerView()
        }
    }""", 'root fullScreenCover')

s = sub(s, """    private var uid: String {
        let base = abs(nickname.hashValue) % 900000
        return String(base + 100000)
    }""", """    private var uid: String {
        guard let id = auth.user?.id else { return \"------\" }
        return String(format: \"%06d\", id)
    }""", 'root uid')

s = sub(s, """                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint.opacity(0.14))
                        .frame(width: 32, height: 32)
                    IsleIcon(icon, scale: .sm, tint: tint)
                }""", """                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(tint.opacity(0.14))
                        .frame(width: 30, height: 30)
                    IsleIcon(icon, scale: .sm, tint: tint)
                }""", 'root MineSectionRow')

save(path, s)

# ---------------- LoginView ----------------
path = 'Isle/App/LoginView.swift'
s = load(path)

s = sub(s, """            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(Color.white.opacity(0.4))
                .frame(width: 20)""", """            Image(systemName: symbol)
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.4))
                .frame(width: 18)""", 'login 输入行图标')

s = sub(s, """            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 34, height: 34)
                Image(systemName: symbol)
                    .font(.system(size: 15))
                    .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.62))
            }""", """            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 30, height: 30)
                Image(systemName: symbol)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.62))
            }""", 'login 卖点按钮')

s = sub(s, """                Image(systemName: \"exclamationmark.shield\")
                    .font(.system(size: 11))""", """                Image(systemName: \"exclamationmark.shield\")
                    .font(.system(size: 10))""", 'login 免责图标')

save(path, s)

# ---------------- HomeView ----------------
path = 'Isle/Features/HomeView.swift'
s = load(path)

s = sub(s, """                IsleIcon(IsleSymbol.clock, scale: .md, tint: Color.white.opacity(0.88))
                    .frame(width: 34, height: 34)""", """                IsleIcon(IsleSymbol.clock, scale: .md, tint: Color.white.opacity(0.88))
                    .frame(width: 30, height: 30)""", 'home 时钟按钮')

save(path, s)

# ---------------- MusicEngine ----------------
path = 'Isle/Sources/MusicEngine.swift'
s = load(path)

s = sub(s, """            try await playItem(first, keyword: keyword)
        } catch {""", """            try await playItem(first, keyword: keyword)
            PlayerPresenter.shared.present()
        } catch {""", 'engine 弹出播放器')

save(path, s)

print('PATCH DONE')
