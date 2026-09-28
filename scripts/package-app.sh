#!/usr/bin/env bash
# 本地与 CI 共用：打 Release 包并 zip，不在这里签名 appcast。
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
version="$(tr -d '[:space:]' < VERSION)"
build="$(bash scripts/semver-build.sh)"
dest="$root/dist"
app="$root/.derived/Build/Products/Release/Ordino.app"
zip="$dest/Ordino-$version.zip"

rm -rf "$dest"
mkdir -p "$dest"

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

ditto -c -k --keepParent "$app" "$zip"
printf '%s\n' "$zip"
