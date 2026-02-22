#!/bin/bash
# KeyCounter ビルドスクリプト
# 使い方:
#   ./build.sh          # App Bundle のみ作成
#   ./build.sh --run    # ビルド後に即時起動
#   ./build.sh --dmg    # DMG を作成（配布用）
set -e

APP="KeyCounter.app"
DMG="KeyCounter.dmg"
VERSION=$(date +"%Y%m%d")

echo "=== KeyCounter ビルド ==="
swift build -c release 2>&1

echo ""
echo "=== App Bundle 作成 ==="
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp .build/release/KeyCounter "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"

echo "✅ $APP を作成しました"

# --dmg オプションで DMG を作成
if [[ "$1" == "--dmg" ]]; then
    echo ""
    echo "=== DMG 作成 ==="

    # ステージングディレクトリ（DMGの中身）
    STAGING=$(mktemp -d)
    cp -r "$APP" "$STAGING/"
    # /Applications へのシンボリックリンク（ドラッグ&ドロップ用）
    ln -s /Applications "$STAGING/Applications"

    rm -f "$DMG"
    hdiutil create \
        -volname "KeyCounter" \
        -srcfolder "$STAGING" \
        -ov \
        -format UDZO \
        -o "$DMG"

    rm -rf "$STAGING"

    echo "✅ $DMG を作成しました"
    echo "保存先: $(pwd)/$DMG"
    echo ""
    echo "配布手順:"
    echo "  1. $DMG をユーザーに渡す"
    echo "  2. DMG をダブルクリックしてマウント"
    echo "  3. KeyCounter.app を Applications フォルダにドラッグ"
    echo "  4. /Applications/KeyCounter.app を起動"

# --run オプションで即時起動
elif [[ "$1" == "--run" ]]; then
    echo ""
    echo "=== 起動 ==="
    open "$APP"

else
    echo ""
    echo "保存先: $(pwd)/$APP"
    echo "起動するには:  open $APP"
    echo "DMG を作るには: ./build.sh --dmg"
fi
