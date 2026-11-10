#!/bin/bash
# 一条命令出两个包：
#   bash build.sh ipa     → Isle-unsigned.ipa（自己用证书签 / Sideloadly / ESign）
#   bash build.sh tipa    → Isle.tipa（TrollStore 直接装）
#   bash build.sh both    → 两个都出
set -euo pipefail

MODE="${1:-ipa}"
NAME=Isle
DISPLAY="屿声音乐"
BID=com.isle.music
MIN=15.0
ROOT="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
APP="$WORK/Payload/$NAME.app"
mkdir -p "$APP"

cat > "$APP/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>${BID}</string>
  <key>CFBundleExecutable</key><string>${NAME}</string>
  <key>CFBundleName</key><string>${NAME}</string>
  <key>CFBundleDisplayName</key><string>${DISPLAY}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleSignature</key><string>????</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>MinimumOSVersion</key><string>${MIN}</string>
  <key>UILaunchScreen</key><dict/>
  <key>UIBackgroundModes</key><array><string>audio</string></array>
  <key>UIFileSharingEnabled</key><false/>
  <key>NSPhotoLibraryUsageDescription</key><string>选择头像</string>
  <key>NSCameraUsageDescription</key><string>拍摄头像</string>
  <key>NSMicrophoneUsageDescription</key><string>听歌识曲需要麦克风</string>
  <key>NSAppleMusicUsageDescription</key><string>播放本地音乐</string>
  <key>CFBundleIconFiles</key><array><string>Icon-60@2x</string><string>Icon-60@3x</string></array>
  <key>CFBundleIcons</key><dict><key>CFBundlePrimaryIcon</key><dict>
    <key>CFBundleIconFiles</key><array><string>Icon-60@2x</string><string>Icon-60@3x</string></array>
  </dict></dict>
</dict></plist>
PLIST
printf 'APPL????' > "$APP/PkgInfo"

# 图标：渐变底 + 白色音符
python3 - "$APP" <<'PY'
import zlib, struct, sys, os
d = sys.argv[1]; W = H = 512; raw = b''
for y in range(H):
    raw += b'\x00'
    for x in range(W):
        t = (x + y) / (W + H)
        raw += bytes((int(255 - t * 30), int(60 + t * 90), int(120 - t * 60), 255))
def chunk(tag, data):
    return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)
png = (b'\x89PNG\r\n\x1a\n'
       + chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 6, 0, 0, 0))
       + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))
open(os.path.join(d, 'icon1024.png'), 'wb').write(png)
PY
sips -z 120 120 "$APP/icon1024.png" --out "$APP/Icon-60@2x.png" >/dev/null
sips -z 180 180 "$APP/icon1024.png" --out "$APP/Icon-60@3x.png" >/dev/null
rm -f "$APP/icon1024.png"

# 编译
export SDK=$(xcrun --sdk iphoneos --show-sdk-path)
FILES=$(find "$ROOT/Isle" -name '*.swift' | tr '\n' ' ')
echo ">> 编译 $(echo $FILES | wc -w) 个 Swift 文件"
xcrun -sdk iphoneos swiftc \
  -target "arm64-apple-ios${MIN}" -sdk "$SDK" \
  -parse-as-library -O -module-name "$NAME" \
  $FILES -o "$APP/$NAME" \
  -framework UIKit -framework SwiftUI -framework AVFoundation \
  -framework MediaPlayer -framework CryptoKit -framework Security
chmod +x "$APP/$NAME"

cd "$WORK"
rm -f "$ROOT/${NAME}-unsigned.ipa" "$ROOT/${NAME}.tipa"
case "$MODE" in
  ipa)  zip -qry "$ROOT/${NAME}-unsigned.ipa" Payload ; echo "OK -> ${NAME}-unsigned.ipa（未签名）" ;;
  tipa) if command -v ldid >/dev/null 2>&1; then ldid -S"$ROOT/entitlements.plist" "$APP/$NAME"; fi
        zip -qry "$ROOT/${NAME}.tipa" Payload ; echo "OK -> ${NAME}.tipa（TrollStore）" ;;
  both) zip -qry "$ROOT/${NAME}-unsigned.ipa" Payload
        if command -v ldid >/dev/null 2>&1; then ldid -S"$ROOT/entitlements.plist" "$APP/$NAME"; fi
        zip -qry "$ROOT/${NAME}.tipa" Payload ; echo "OK -> ipa + tipa" ;;
  *) echo "用法: bash build.sh ipa|tipa|both" ; exit 1 ;;
esac
cd / && rm -rf "$WORK"
