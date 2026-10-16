#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP="${1:-$PWD/dist/ShareSafe.app}"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" .build/AppIcon.iconset
cp .build/release/ShareSafe "$APP/Contents/MacOS/ShareSafe.new"
mv -f "$APP/Contents/MacOS/ShareSafe.new" "$APP/Contents/MacOS/ShareSafe"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/PrivacyInfo.xcprivacy "$APP/Contents/Resources/PrivacyInfo.xcprivacy"
swift scripts/make-sample.swift "$APP/Contents/Resources/Northstar-Sample.pdf"
swift scripts/make-icon.swift .build/AppIcon-1024.png
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" .build/AppIcon-1024.png --out ".build/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" .build/AppIcon-1024.png --out ".build/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns .build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --options runtime --entitlements Resources/ShareSafe.entitlements --sign - "$APP"
codesign --verify --deep --strict "$APP"
echo "Built $APP"
