# 自签安装指南（Isle-unsigned.ipa）

`bash build.sh ipa` 产物是**未签名**的 IPA，用你自己的证书签掉才能装。
包信息：Bundle ID `com.isle.music`，最低 iOS 15.0，arm64。

---

## 一、Windows / 通用：Sideloadly

1. 装 [Sideloadly](https://sideloadly.io) 和 iTunes（Windows 需要）
2. 手机连电脑，Sideloadly 里选设备 → 拖入 `Isle-unsigned.ipa`
3. Apple ID 填你自己的（免费账号即可）
4. 点 Start，输入密码（有二次验证就填专用密码）
5. 装完去 `设置 → 通用 → VPN与设备管理` 信任开发者

免费 Apple ID：**7 天有效期**，到期用 Sideloadly 重新装一次（保留数据）。
付费开发者账号（$99/年）：1 年。

## 二、手机上直接签：ESign / 轻松签 / 全能签

1. 准备好 `.p12` 证书 + `.mobileprovision` 描述文件（买共享证书或自己的开发者证书）
2. ESign → 签名 → 导入 IPA → 选证书 → 签名
3. 签完直接安装

注意：**描述文件里的 Bundle ID 要么是通配符 `com.isle.*`，要么正好是 `com.isle.music`**；不匹配会报 `Provisioning profile doesn't match`。

## 三、macOS 命令行签名

```bash
unzip Isle-unsigned.ipa -d tmp
# 用你的证书签（证书名用 security find-identity -v -p codesigning 查）
codesign -f -s "Apple Development: you@example.com (XXXXXXXX)" \
  --entitlements entitlements-dev.plist tmp/Payload/Isle.app
# 打包
cd tmp && zip -qry ../Isle-signed.ipa Payload && cd ..
```

`entitlements-dev.plist`（自签专用，**不要**用仓库里给 TrollStore 的 `entitlements.plist`）：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
  <key>application-identifier</key><string>TEAMID.com.isle.music</string>
  <key>com.apple.developer.team-identifier</key><string>TEAMID</string>
  <key>get-task-allow</key><true/>
  <key>keychain-access-groups</key><array><string>TEAMID.*</string></array>
</dict></plist>
```

## 四、AltStore / SideStore

装好 AltStore 后，把 IPA 传到手机「文件」，AltStore → My Apps → `+` → 选 IPA。
AltStore 会自动 7 天刷新（手机和电脑同一 WiFi 时）。

---

## 五、自签会失去什么

| 能力 | 自签 | TrollStore |
|---|---|---|
| 后台播放 | ✅ | ✅ |
| Keychain（登录态、设备密钥） | ✅ | ✅ |
| 7 天过期 | 免费证书会过期 | 永不过期 |
| 沙盒外文件访问 | ❌ | ✅（`no-sandbox`） |
| 推送通知 | ❌（免费证书无 aps-environment） | ✅ |
| 设备数 | 免费证书限 3 台 | 不限 |

所以：**养眼/听歌/会员这些都正常**，只是「直接扫 iTunes 同步的音乐库」这类越权功能只有巨魔版能做。

---

## 六、常见报错

| 报错 | 原因 | 处理 |
|---|---|---|
| `Unable to install` | 证书和 Bundle ID 不匹配 | 描述文件改通配符或完全匹配 |
| 启动闪退 | 缺 `get-task-allow` | 用上面的 dev entitlements 重签 |
| 提示不可信开发者 | 没信任证书 | 设置 → 通用 → VPN与设备管理 → 信任 |
| 登录后立刻掉线 | 设备密钥写入 Keychain 失败 | 确认签名带 `keychain-access-groups` |
| 打开就白屏 | 服务器不可达 | 先在 Safari 开 `https://ys.irepo.cn/api/health` |

---

## 七、要改 Bundle ID？

改 `build.sh` 顶部 `BID=com.isle.music` 为你自己的（比如 `com.yourname.isle`），然后重新构建。
注意：换 Bundle ID 等于换一个 App，已装版本的数据不会继承。
