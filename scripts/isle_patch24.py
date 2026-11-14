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


# ============ 1) AuthStore：到期判定与文案 ============
p = 'Isle/Network/AuthStore.swift'
s = load(p)

s = sub(s, '''    var isLoggedIn: Bool { user != nil }
    var isVIP: Bool { ent.canPlayMusic }
    var isSVIP: Bool { ent.canUseVideo }''',
    '''    var isLoggedIn: Bool { user != nil }

    /// 本地再判一次到期，避免 App 长时间挂着不刷新权限
    var roleExpired: Bool {
        guard let exp = user?.roleExpireAt, exp > 0 else { return false }
        return Date().timeIntervalSince1970 > Double(exp)
    }

    var isVIP: Bool { ent.canPlayMusic && !roleExpired }
    var isSVIP: Bool { ent.canUseVideo && !roleExpired }

    var roleLabel: String {
        if isSVIP { return "SVIP" }
        if isVIP { return "VIP" }
        return "免费"
    }

    var expireText: String {
        guard let exp = user?.roleExpireAt, exp > 0 else {
            return roleLabel == "免费" ? "未开通 · 兑换卡密即可开通" : "永久"
        }
        let d = Date(timeIntervalSince1970: Double(exp))
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        if roleExpired { return "\(f.string(from: d)) 已到期" }
        let days = Int(max(0, d.timeIntervalSinceNow) / 86400)
        return "\(f.string(from: d)) 到期 · 剩 \(days) 天"
    }''', 'AuthStore 到期判定')

save(p, s)
print('AuthStore done')

# ============ 2) RootView：播放器权限 + 会员卡 + 导入提示 ============
p = 'Isle/App/RootView.swift'
s = load(p)

s = sub(s, '''        .fullScreenCover(isPresented: $player.show) {
            CymusicPlayerView()
        }''',
    '''        .fullScreenCover(isPresented: $player.show) {
            if auth.isVIP {
                CymusicPlayerView()
            } else {
                NavigationView {
                    PaywallView(need: "VIP", feature: "在线听歌")
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
        }''', 'Root 播放器权限')

s = sub(s, '''struct MineMemberCard: View {
    let nickname: String
    let onRedeem: () -> Void''',
    '''struct MineMemberCard: View {
    let nickname: String
    let onRedeem: () -> Void

    @EnvironmentObject private var auth: AuthStore''', '会员卡引入 auth')

s = sub(s, '''                    Text("尊享无损 · 无限下载")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(goldText)

                    Text("未开通 · 兑换卡密即可开通")
                        .font(.system(size: 10))
                        .foregroundStyle(gold.opacity(0.68))
                        .padding(.top, 2)''',
    '''                    HStack(spacing: 6) {
                        Text("尊享无损 · 无限下载")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(goldText)

                        Text(auth.roleLabel)
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(Color(red: 0.23, green: 0.15, blue: 0.07))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(goldText))
                    }

                    Text(auth.isVIP || auth.isSVIP ? auth.expireText : "未开通 · 兑换卡密即可开通")
                        .font(.system(size: 10))
                        .foregroundStyle(gold.opacity(0.68))
                        .padding(.top, 2)''', '会员卡到期与徽章')

s = sub(s, '''        store.add("\(platform.title)歌单 \(id.suffix(6))")
        ok = false
        message = "已创建歌单（\(id)），但服务端未开通解析接口，曲目为空"''',
    '''        store.add("\(platform.title)歌单 \(id.suffix(6))")
        ok = false
        message = "服务端返回 0 首：歌单要设为公开，或者后台还没更新到最新版本"''', '导入提示修正')

save(p, s)
print('RootView done')

# ============ 3) LibraryView：删除 + 封面修复 ============
p = 'Isle/Features/LibraryView.swift'
s = load(p)

s = sub(s, '''    @State private var coverTarget: UUID?
    @State private var showCoverPicker = false''',
    '''    @State private var coverPick: CoverPick?
    @State private var deleteTarget: IslePlaylist?''', 'Library 状态替换')

s = sub(s, '''    var body: some View {
        ZStack {''',
    '''    struct CoverPick: Identifiable { let id: UUID }

    var body: some View {
        ZStack {''', 'Library CoverPick')

s = sub(s, '''        .sheet(isPresented: $showCoverPicker) {
            PhotoPicker { data in
                if let id = coverTarget { store.setCover(data, for: id) }
            }
        }''',
    '''        .sheet(item: $coverPick) { pick in
            PhotoPicker { data in store.setCover(data, for: pick.id) }
        }
        .alert("删除歌单", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("取消", role: .cancel) { deleteTarget = nil }
            Button("删除", role: .destructive) {
                if let t = deleteTarget,
                   let i = store.lists.firstIndex(where: { $0.id == t.id }) {
                    store.remove(at: IndexSet(integer: i))
                }
                deleteTarget = nil
            }
        } message: {
            Text("「\(deleteTarget?.name ?? "")」会被移除，歌里的收藏不受影响。")
        }''', 'Library 封面临片与删除确认')

s = sub(s, '''                        .contextMenu {
                            Button {
                                coverTarget = p.id
                                showCoverPicker = true
                            } label: {
                                Label("更换封面", systemImage: "photo")
                            }
                            if p.cover != nil {
                                Button(role: .destructive) {
                                    coverTarget = p.id
                                    if let idx = store.lists.firstIndex(where: { $0.id == p.id }) {
                                        store.lists[idx].cover = nil
                                    }
                                } label: {
                                    Label("恢复默认封面", systemImage: "arrow.counterclockwise")
                                }
                            }
                        }''',
    '''                        .contextMenu {
                            Button {
                                coverPick = CoverPick(id: p.id)
                            } label: {
                                Label("更换封面", systemImage: "photo")
                            }
                            if p.cover != nil {
                                Button {
                                    if let idx = store.lists.firstIndex(where: { $0.id == p.id }) {
                                        store.lists[idx].cover = nil
                                    }
                                } label: {
                                    Label("恢复默认封面", systemImage: "arrow.counterclockwise")
                                }
                            }
                            Button(role: .destructive) {
                                deleteTarget = p
                            } label: {
                                Label("删除歌单", systemImage: "trash")
                            }
                        }''', 'Library 菜单加删除')

save(p, s)
print('LibraryView done')

print('PATCH24 DONE')
