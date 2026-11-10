# MusicTroll

巨魔（TrollStore）用的本地音乐播放器，一条命令产出 `MusicTroll.tipa`。

## 一键构建

macOS（装了 Xcode / 命令行工具）：

```bash
bash build_tipa.sh
```

输出：当前目录下的 `MusicTroll.tipa`。

没有 Mac：本仓库带 Actions 工作流，推送代码或手动 Run 一次，在本次 run 的 Artifacts 里下载 `MusicTroll-tipa`，解包就是 `.tipa`。

## 安装

1. 把 `MusicTroll.tipa` 存进「文件」App
2. 点它 → 分享 → TrollStore；或在 TrollStore 里 `+` → Install IPA/tipa File
3. 打开「音乐」，右上 `+` 从文件导入 mp3 / flac；也可以直接在 文件 → 我的 iPhone → 音乐 里丢歌

支持 mp3 / m4a / aac / wav / aiff / caf / flac / opus / alac，后台播放、锁屏与控制中心切歌内置。

## 可改的地方

- `build_tipa.sh` 顶部：`NAME` / `BID` / `MIN`（BundleID 要唯一）
- 想扫 iTunes 同步的 `/var/mobile/Media/iTunes_Control/Music`：在 `entitlements.plist` 加 `com.apple.private.security.no-sandbox`
- 想加播放列表 / 倍速 / EQ：改 `src/` 下的 Swift 文件

## 说明

entitlements 里的 `platform-application` 是让 TrollStore 直接伪签名安装的关键；普通签名链不认这套，所以产物用 `.tipa` 后缀。
