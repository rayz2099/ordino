#!/usr/bin/env bash
# 本地与 CI 共用：打 Release 包并做成可拖进 Applications 的 DMG。
# 不用 Developer ID：发行证书和公证不在这条流水线里，Apple Development 也不能发给别人的机器。
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

if ! command -v create-dmg >/dev/null; then
  echo "create-dmg is required: brew install create-dmg" >&2
  exit 1
fi

version="$(tr -d '[:space:]' < VERSION)"
build="$(bash scripts/semver-build.sh)"
dest="$root/dist"
app="$root/.derived/Build/Products/Release/Ordino.app"
stage="$root/.derived/dmg-stage"
dmg="$dest/Ordino-$version.dmg"

rm -rf "$dest" "$stage"
mkdir -p "$dest" "$stage"

xcodegen generate
xcodebuild \
  -project Ordino.xcodeproj \
  -scheme Ordino \
  -configuration Release \
  -derivedDataPath .derived \
  -destination 'generic/platform=macOS' \
  MARKETING_VERSION="$version" \
  CURRENT_PROJECT_VERSION="$build" \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES \
  DEVELOPMENT_TEAM= \
  build

ditto "$app" "$stage/Ordino.app"

# 窗口里放 App 和 Applications，打开镜像就能拖进去，不再靠 zip 解压。
create-dmg \
  --volname "Ordino" \
  --volicon "$root/Resources/AppIcon.icns" \
  --window-pos 200 120 \
  --window-size 540 360 \
  --icon-size 128 \
  --icon "Ordino.app" 120 140 \
  --hide-extension "Ordino.app" \
  --app-drop-link 400 140 \
  "$dmg" \
  "$stage"

printf '%s\n' "$dmg"
