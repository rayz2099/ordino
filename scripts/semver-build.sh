#!/usr/bin/env bash
# 把 VERSION 编成单调递增的 CFBundleVersion，供 Sparkle 比较。
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
version="$(tr -d '[:space:]' < "$root/VERSION")"
IFS=. read -r major minor patch <<< "$version"
printf '%d\n' $((major * 10000 + minor * 100 + patch))
