#!/bin/bash
set -euo pipefail

NAME=MusicTroll
BID=com.troll.musictroll
MIN=14.0

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="${ROOT}/${NAME}.tipa"
WORK="$(mktemp -d)"
APP="${WORK}/Payload/${NAME}.app"
mkdir -p "$APP"

cat > "${APP}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>${BID}</string>
  <key>CFBundleExecutable</key><string>${NAME}</string>
  <key>CFBundleName</key><string>${NAME}</string>
  <key>CFBundleDisplayName</key><string>音乐</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleSignature</key><string>????</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>MinimumOSVersion</key><string>${MIN}</string>
  <key>UIBackgroundModes</key><array><string>audio</string></array>
  <key>UIFileSharingEnabled</key><true/>
  <key>LSSupportsOpeningDocumentsInPlace</key><true/>
  <key>UILaunchScreen</key><dict/>
  <key>CFBundleIconFiles</key><array><string>Icon-60@2x</string><string>Icon-60@3x</string></array>
  <key>CFBundleIcons</key><dict><key>CFBundlePrimaryIcon</key><dict>
    <key>CFBundleIconFiles</key><array><string>Icon-60@2x</string><string>Icon-60@3x</string></array>
  </dict></dict>
  <key>NSAppleMusicUsageDescription</key><string>播放本地音乐</string>
</dict></plist>
PLIST

printf 'APPL????' > "${APP}/PkgInfo"

python3 - "$APP" <<'PY'
import zlib, struct, sys, os
d = sys.argv[1]
W = H = 512
raw = b''
for y in range(H):
    raw += b'\x00'
    for x in range(W):
        raw += bytes((40 + x * 200 // W, 90, 255 - y * 180 // H, 255))
def chunk(t, data):
    return struct.pack('>I', len(data)) + t + data + struct.pack('>I', zlib.crc32(t + data) & 0xffffffff)
png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
open(os.path.join(d, 'icon1024.png'), 'wb').write(png)
PY

sips -z 120 120 "${APP}/icon1024.png" --out "${APP}/Icon-60@2x.png" >/dev/null
sips -z 180 180 "${APP}/icon1024.png" --out "${APP}/Icon-60@3x.png" >/dev/null
rm -f "${APP}/icon1024.png"

SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
xcrun -sdk iphoneos swiftc -target "arm64-apple-ios${MIN}" -sdk "$SDK" \
  -parse-as-library -O -module-name "$NAME" \
  "${ROOT}"/src/*.swift -o "${APP}/${NAME}" \
  -framework UIKit -framework SwiftUI -framework AVFoundation -framework MediaPlayer

if command -v ldid >/dev/null 2>&1; then
  ldid -S"${ROOT}/entitlements.plist" "${APP}/${NAME}"
fi
chmod +x "${APP}/${NAME}"

cd "$WORK"
rm -f "$OUT"
zip -qry "$OUT" Payload
cd /
rm -rf "$WORK"
echo "OK -> $OUT"
