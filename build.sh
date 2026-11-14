#!/bin/bash
# bash build.sh ipa|tipa|both        VERSION=1.6.0 可覆盖版本号
set -euo pipefail

MODE="${1:-ipa}"
VERSION="${VERSION:-1.12.0}"
NAME=Isle
DISPLAY="屿声音乐"
BID=com.isle.music
MIN=15.0
ROOT="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
APP="$WORK/Payload/$NAME.app"
mkdir -p "$APP"

python3 - "$WORK" <<'PY'
import zlib, struct, sys, os, math
d = sys.argv[1]; N = 1024
img = bytearray(N * N * 4)
for y in range(N):
    row = y * N * 4; tv = y / (N - 1.0)
    for x in range(N):
        u = x / (N - 1.0) * 0.55 + tv * 0.45
        i = row + x * 4
        img[i] = 255; img[i+1] = int(46 + 124 * u); img[i+2] = int(134 - 74 * u); img[i+3] = 255
def blend(x, y, a):
    if x < 0 or y < 0 or x >= N or y >= N or a <= 0: return
    if a > 1: a = 1.0
    i = (y * N + x) * 4
    img[i]   = int(img[i]   * (1 - a) + 255 * a)
    img[i+1] = int(img[i+1] * (1 - a) + 255 * a)
    img[i+2] = int(img[i+2] * (1 - a) + 255 * a)
for y in range(int(0.85 * N)):
    for x in range(int(0.85 * N)):
        dx = (x - 0.28 * N) / (0.62 * N); dy = (y - 0.22 * N) / (0.62 * N)
        v = dx * dx + dy * dy
        if v < 1: blend(x, y, 0.20 * (1 - v))
def ellipse(cx, cy, rx, ry, ang):
    ca, sa = math.cos(ang), math.sin(ang); R = int(max(rx, ry)) + 2
    for yy in range(int(cy) - R, int(cy) + R):
        for xx in range(int(cx) - R, int(cx) + R):
            dx = xx - cx; dy = yy - cy
            px = dx * ca + dy * sa; py = -dx * sa + dy * ca
            v = (px / rx) ** 2 + (py / ry) ** 2
            if v <= 1.12: blend(xx, yy, min(1.0, max(0.0, (1.12 - v) / 0.12)))
def rect(x0, y0, x1, y1):
    for yy in range(int(y0), int(y1)):
        for xx in range(int(x0), int(x1)): blend(xx, yy, 1.0)
def quad(p1, p2, p3, p4):
    pts = [p1, p2, p3, p4]
    for yy in range(int(min(p[1] for p in pts)), int(max(p[1] for p in pts)) + 1):
        nodes = []
        for k in range(4):
            a = pts[k]; b = pts[(k + 1) % 4]
            if (a[1] <= yy < b[1]) or (b[1] <= yy < a[1]):
                nodes.append(a[0] + (yy - a[1]) * (b[0] - a[0]) / (b[1] - a[1]))
        nodes.sort()
        for k in range(0, len(nodes) - 1, 2):
            for xx in range(int(nodes[k]), int(nodes[k + 1])): blend(xx, yy, 1.0)
ellipse(0.375*N, 0.715*N, 0.108*N, 0.084*N, -0.32)
ellipse(0.615*N, 0.655*N, 0.108*N, 0.084*N, -0.32)
rect(0.452*N, 0.300*N, 0.492*N, 0.730*N)
rect(0.692*N, 0.240*N, 0.732*N, 0.670*N)
quad((0.452*N,0.240*N),(0.732*N,0.240*N),(0.732*N,0.325*N),(0.452*N,0.385*N))
def chunk(t, data):
    return struct.pack('>I', len(data)) + t + data + struct.pack('>I', zlib.crc32(t + data) & 0xffffffff)
raw = bytearray()
for y in range(N):
    raw.append(0); raw += img[y*N*4:(y+1)*N*4]
png = (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', N, N, 8, 6, 0, 0, 0))
       + chunk(b'IDAT', zlib.compress(bytes(raw), 9)) + chunk(b'IEND', b''))
open(os.path.join(d, 'icon1024.png'), 'wb').write(png)
PY

for spec in "40 Icon-20@2x" "60 Icon-20@3x" "58 Icon-29@2x" "87 Icon-29@3x" \
            "80 Icon-40@2x" "120 Icon-40@3x" "120 AppIcon60x60@2x" "180 AppIcon60x60@3x" \
            "120 Icon-60@2x" "180 Icon-60@3x" "152 Icon-76@2x" "167 Icon-83.5@2x"; do
  set -- $spec
  sips -z "$1" "$1" "$WORK/icon1024.png" --out "$APP/$2.png" >/dev/null
done
sips -z 1024 1024 "$WORK/icon1024.png" --out "$APP/Icon-1024.png" >/dev/null

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
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>MinimumOSVersion</key><string>${MIN}</string>
  <key>UILaunchScreen</key><dict/>
  <key>UIBackgroundModes</key><array><string>audio</string></array>
  <key>UIFileSharingEnabled</key><false/>
  <key>NSPhotoLibraryUsageDescription</key><string>选择头像</string>
  <key>NSCameraUsageDescription</key><string>拍摄头像</string>
  <key>NSMicrophoneUsageDescription</key><string>听歌识曲需要麦克风</string>
  <key>NSAppTransportSecurity</key><dict><key>NSAllowsArbitraryLoads</key><true/></dict>
  <key>CFBundleIconFiles</key><array>
    <string>Icon-20@2x</string><string>Icon-20@3x</string>
    <string>Icon-29@2x</string><string>Icon-29@3x</string>
    <string>Icon-40@2x</string><string>Icon-40@3x</string>
    <string>Icon-60@2x</string><string>Icon-60@3x</string>
    <string>Icon-76@2x</string><string>Icon-83.5@2x</string>
    <string>AppIcon60x60@2x</string><string>AppIcon60x60@3x</string>
  </array>
  <key>CFBundleIcons</key><dict>
    <key>CFBundlePrimaryIcon</key><dict>
      <key>CFBundleIconFiles</key><array>
        <string>Icon-60@2x</string><string>Icon-60@3x</string>
        <string>AppIcon60x60@2x</string><string>AppIcon60x60@3x</string>
      </array>
      <key>CFBundleIconName</key><string>AppIcon</string>
    </dict>
  </dict>
</dict></plist>
PLIST
printf 'APPL????' > "$APP/PkgInfo"

export SDK=$(xcrun --sdk iphoneos --show-sdk-path)
FILES=$(find "$ROOT/Isle" -name '*.swift' | tr '\n' ' ')
echo ">> 编译 $(echo $FILES | wc -w) 个 Swift 文件，版本 $VERSION"
xcrun -sdk iphoneos swiftc \
  -target "arm64-apple-ios${MIN}" -sdk "$SDK" \
  -parse-as-library -O -module-name "$NAME" \
  $FILES -o "$APP/$NAME" \
  -framework UIKit -framework SwiftUI -framework AVFoundation -framework CoreMedia \
  -framework MediaPlayer -framework CryptoKit -framework Security -framework JavaScriptCore \
  -framework CoreImage -framework Metal -framework MetalKit \
  -framework CoreVideo -framework OpenGLES -framework QuartzCore \
  -framework CoreGraphics -framework CoreText -framework Foundation
chmod +x "$APP/$NAME"

cd "$WORK"
rm -f "$ROOT/${NAME}-unsigned.ipa" "$ROOT/${NAME}.tipa"
case "$MODE" in
  ipa)  zip -qry "$ROOT/${NAME}-unsigned.ipa" Payload ; echo "OK -> ${NAME}-unsigned.ipa ($VERSION)" ;;
  tipa) if command -v ldid >/dev/null 2>&1; then ldid -S"$ROOT/entitlements.plist" "$APP/$NAME"; fi
        zip -qry "$ROOT/${NAME}.tipa" Payload ; echo "OK -> ${NAME}.tipa ($VERSION)" ;;
  both) zip -qry "$ROOT/${NAME}-unsigned.ipa" Payload
        if command -v ldid >/dev/null 2>&1; then ldid -S"$ROOT/entitlements.plist" "$APP/$NAME"; fi
        zip -qry "$ROOT/${NAME}.tipa" Payload ; echo "OK -> ipa + tipa ($VERSION)" ;;
  *) echo "用法: bash build.sh ipa|tipa|both" ; exit 1 ;;
esac
cd / && rm -rf "$WORK"
