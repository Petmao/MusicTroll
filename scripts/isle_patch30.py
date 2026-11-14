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


# ============ 1) MusicEngine：加权限门禁与停播 ============
p = 'Isle/Sources/MusicEngine.swift'
s = load(p)

s = sub(s, '''    @Published var shuffleOn = false
    @Published var volume: Float = 1.0''',
    '''    @Published var shuffleOn = false
    @Published var volume: Float = 1.0

    /// 由 AuthStore 注入：返回 false 时一律不取地址、不出声
    var gate: (() -> Bool)?''', 'engine gate 字段')

s = sub(s, '''    func loadQueueItem(present: Bool) async {
        guard queueIndex >= 0, queueIndex < queue.count else { return }
        let kw = queue[queueIndex]''',
    '''    func loadQueueItem(present: Bool) async {
        guard queueIndex >= 0, queueIndex < queue.count else { return }

        // 权限门禁：非 VIP 连地址都不去取，更不会出声
        if let gate, !gate() {
            halt()
            return
        }

        let kw = queue[queueIndex]''', 'engine 加载门禁')

s = sub(s, '''    func playItem(_ item: [String: Any], keyword: String) async throws {
        endGuard = false''',
    '''    func playItem(_ item: [String: Any], keyword: String) async throws {
        if let gate, !gate() { halt(); return }
        endGuard = false''', 'engine 播放门禁')

s = sub(s, '''    func setVolume(_ v: Float) {''',
    '''    /// 立刻停声并清空播放态，用于降级、到期、未授权
    func halt() {
        player?.pause()
        AudioFX.shared.pause()
        isPlaying = false
        progress = 0
        status = "需要 VIP"
    }

    func setVolume(_ v: Float) {''', 'engine halt')

save(p, s)
print('MusicEngine done')

# ============ 2) AuthStore：注入门禁 ============
p = 'Isle/Network/AuthStore.swift'
s = load(p)

s = sub(s, '''    @Published var loading = false
    @Published var error: String?''',
    '''    @Published var loading = false
    @Published var error: String?

    init() {
        // 引擎侧的权限门禁：非 VIP 时连播放地址都不取
        MusicEngine.shared.gate = { [weak self] in
            guard let self else { return false }
            return self.isVIP
        }
    }''', 'AuthStore 注入门禁')

save(p, s)
print('AuthStore done')

# ============ 3) RootView：降级即时停播 ============
p = 'Isle/App/RootView.swift'
s = load(p)

s = sub(s, '''        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $player.show) {''',
    '''        .preferredColorScheme(.dark)
        .onChange(of: auth.isVIP) { vip in
            if !vip { MusicEngine.shared.halt() }
        }
        .fullScreenCover(isPresented: $player.show) {''', 'Root 降级停播')

save(p, s)
print('RootView done')
print('PATCH30 DONE')
