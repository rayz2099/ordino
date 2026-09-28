#!/usr/bin/env bash
# 生成发行用的自签代码签名证书。证书指纹写进 TCC 的授权条件，重新生成等于换人，辅助功能会再掉一次。
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
dir="$root/.signing"
cert="$dir/cert.pem"
key="$dir/key.pem"

if [[ -f "$cert" || -f "$key" ]]; then
  echo "signing cert already exists: $dir" >&2
  exit 1
fi

mkdir -p "$dir"
conf="$dir/cert.conf"
cat > "$conf" << 'EOF'
[ req ]
distinguished_name = dn
prompt = no
x509_extensions = codesign_ext

[ dn ]
CN = Ordino Codesign
O = rayz2099

[ codesign_ext ]
extendedKeyUsage = critical,codeSigning
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
EOF

openssl req -x509 -newkey rsa:2048 -sha256 -nodes \
  -keyout "$key" -out "$cert" -days 7300 \
  -config "$conf" -extensions codesign_ext >/dev/null
rm -f "$conf"
chmod 600 "$key" "$cert"
printf '%s\n' "$dir"
