#!/usr/bin/env bash
# 用同一张自签证书重签发行包。ad-hoc 的 designated requirement 是 cdhash，每个版本都变，TCC 里的辅助功能授权就对不上。
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
app="${1:?app bundle}"
cert="$root/.signing/cert.pem"
key="$root/.signing/key.pem"

if [[ ! -d "$app" ]]; then
  echo "app bundle not found: $app" >&2
  exit 1
fi
if [[ ! -f "$cert" || ! -f "$key" ]]; then
  echo "missing .signing/cert.pem or .signing/key.pem" >&2
  exit 1
fi

work="$root/.derived/signing"
mkdir -p "$work"
kc="$work/release.keychain-db"
kcpass="$(openssl rand -hex 16)"
rm -f "$kc"

old=()
while IFS= read -r line; do
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line#\"}"
  line="${line%\"}"
  if [[ -n "$line" ]]; then
    old+=("$line")
  fi
done < <(security list-keychains -d user)

cleanup() {
  security delete-keychain "$kc" >/dev/null 2>&1 || true
  if ((${#old[@]} > 0)); then
    security list-keychains -d user -s "${old[@]}" >/dev/null
  fi
}
trap cleanup EXIT

security create-keychain -p "$kcpass" "$kc" >/dev/null
security set-keychain-settings -lut 21600 "$kc"
security unlock-keychain -p "$kcpass" "$kc"
security list-keychains -d user -s "$kc" "${old[@]}"
security import "$key" -k "$kc" -A -T /usr/bin/codesign -T /usr/bin/security >/dev/null
security import "$cert" -k "$kc" -A -T /usr/bin/codesign -T /usr/bin/security >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$kcpass" "$kc" >/dev/null

identity=""
while IFS= read -r line; do
  if [[ "$line" =~ ^[[:space:]]*[0-9]+\)\ ([A-F0-9]{40})\  ]]; then
    identity="${BASH_REMATCH[1]}"
    break
  fi
done < <(security find-identity -p codesigning "$kc")
if [[ -z "$identity" ]]; then
  echo "signing identity missing" >&2
  exit 1
fi

# 先签最里面的 Mach-O，再签包。identifier 和 entitlements 必须留住，Sparkle 的安装器靠它们启动。
while IFS= read -r -d '' path; do
  if [[ -L "$path" ]]; then
    continue
  fi
  sign=0
  if [[ -d "$path" ]]; then
    case "$path" in
      *.app|*.framework|*.xpc|*.bundle) sign=1 ;;
    esac
  elif [[ -f "$path" ]]; then
    kind="$(file -b "$path")"
    case "$kind" in
      *Mach-O*) sign=1 ;;
    esac
  fi
  if [[ "$sign" -eq 1 ]]; then
    codesign --force \
      --sign "$identity" \
      --timestamp=none \
      --keychain "$kc" \
      --preserve-metadata=identifier,entitlements,flags \
      "$path"
  fi
done < <(find "$app" -depth -print0)

codesign --verify --deep --strict --verbose=2 "$app"

req="$(codesign -d -r- "$app" 2>&1 | sed -n 's/^#* *designated => //p')"
case "$req" in
  *cdhash*)
    echo "designated requirement still bound to cdhash: $req" >&2
    exit 1
    ;;
  *'identifier "com.rayz2099.ordino"'*) ;;
  *)
    echo "unexpected designated requirement: $req" >&2
    exit 1
    ;;
esac
printf '%s\n' "$req"
