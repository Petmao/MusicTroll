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


p = 'Isle/Features/LibraryView.swift'
s = load(p)

# 1) 删除状态改成 Bool + 独立 ID，避开 alert 的 Binding 时序坑
s = sub(s, '''    @State private var coverPick: CoverPick?
    @State private var deleteTarget: IslePlaylist?''',
    '''    @State private var coverPick: CoverPick?
    @State private var pendingDeleteID: UUID?
    @State private var showDeleteAlert = false''', '删除状态')

s = sub(s, '''        .alert("删除歌单", isPresented: Binding(
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
        }''',
    '''        .alert("删除歌单", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { pendingDeleteID = nil }
            Button("删除", role: .destructive) {
                if let id = pendingDeleteID,
                   let i = store.lists.firstIndex(where: { $0.id == id }) {
                    store.remove(at: IndexSet(integer: i))
                }
                pendingDeleteID = nil
            }
        } message: {
            Text("删除后不可恢复，歌里的收藏不受影响。")
        }''', '删除弹窗改用 Bool')

s = sub(s, '''                            Button(role: .destructive) {
                                deleteTarget = p
                            } label: {
                                Label("删除歌单", systemImage: "trash")
                            }''',
    '''                            Button(role: .destructive) {
                                pendingDeleteID = p.id
                                showDeleteAlert = true
                            } label: {
                                Label("删除歌单", systemImage: "trash")
                            }''', '删除菜单项')

# 2) 收藏列表可点击播放
s = sub(s, '''                VStack(spacing: 8) {
                    ForEach(fav.items) { s in
                        favRow(s.title, s.artist)
                    }
                }''',
    '''                VStack(spacing: 8) {
                    ForEach(Array(fav.items.enumerated()), id: \.element.id) { i, s in
                        favRow(s.title, s.artist, i)
                    }
                }''', '收藏列表带序号')

s = sub(s, '''    private func favRow(_ title: String, _ artist: String) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(covers[0])
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Text(artist).font(.system(size: 10.5)).foregroundStyle(IsleColor.textSub).lineLimit(1)
            }
            Spacer(minLength: 6)
            Button { fav.toggle(title: title, artist: artist) } label: {
                IsleIcon(IsleSymbol.heartFill, scale: .md, tint: IsleColor.pink)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(IsleColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(IsleColor.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }''',
    '''    private func favRow(_ title: String, _ artist: String, _ index: Int) -> some View {
        HStack(spacing: 10) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                Task {
                    await MusicEngine.shared.playQueue(fav.items.map { $0.title }, startAt: index)
                }
            } label: {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(covers[0])
                        .frame(width: 40, height: 40)
                        .overlay(
                            IsleIcon(IsleSymbol.play, scale: .sm,
                                     tint: Color.white.opacity(0.92))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        Text(artist).font(.system(size: 10.5))
                            .foregroundStyle(IsleColor.textSub).lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Image(systemName: "heart.fill")
                .font(.system(size: 13))
                .foregroundStyle(IsleColor.pink)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
                .onTapGesture {
                    fav.toggle(title: title, artist: artist)
                }
        }
        .padding(10)
        .background(IsleColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(IsleColor.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }''', '收藏行可播放')

save(p, s)
print('LibraryView done')
print('PATCH27 DONE')
