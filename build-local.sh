#!/bin/bash
# 本地构建：不依赖 GitHub Actions
# 用法：bash build-local.sh both
#   需要 macOS + Xcode（命令行工具已装）
set -e

MODE="${1:-both}"
APP_NAME="Isle"
BUILD_DIR="build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo ">> 检查 Xcode"
xcodebuild -version

SDK=$(xcrun --sdk iphoneos --show-sdk-path)
MIN_IOS="14.0"

# 收集所有 Swift 文件
FILES=$(find Isle -name '*.swift' | tr '\n' ' ')
echo ">> 编译 $(echo $FILES | wc -w | tr -d ' ') 个 Swift 文件"

APP="$BUILD_DIR/Payload/$APP_NAME.app"
mkdir -p "$APP"

xcrun -sdk iphoneos swiftc \
  -target arm64-apple-ios${MIN_IOS} \
  -sdk "$SDK" \
  -parse-as-library \
  -O \
  -framework SwiftUI -framework UIKit -framework AVFoundation \
  -framework JavaScriptCore -framework Security -framework Combine \
  -o "$APP/$APP_NAME" \
  $FILES

cp Isle/Info.plist "$APP/Info.plist" 2>/dev/null || true
cp -R Isle/Assets.xcassets "$APP/" 2>/dev/null || true

if command -v ldid >/dev/null 2>&1; then
  echo ">> ldid 伪签名"
  ldid -S "$APP/$APP_NAME"
else
  echo "!! 未安装 ldid，跳过伪签名（brew install ldid）"
fi

echo ">> 打包 ipa"
cd "$BUILD_DIR"
zip -qry "../Isle-unsigned.ipa" Payload
cd ..

echo "✅ 完成：$(pwd)/Isle-unsigned.ipa"
ls -lh Isle-unsigned.ipa

if [ "$MODE" = "both" ]; then
  cp Isle-unsigned.ipa Isle.tipa 2>/dev/null || true
  echo "✅ 同时产出 Isle.tipa"
fi
