#!/usr/bin/env bash
set -euo pipefail
version="${OPA_VERSION:-1.21.2}"
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) asset=opa_darwin_arm64_static ;;
  Linux-x86_64) asset=opa_linux_amd64_static ;;
  *) echo "Unsupported OPA installer platform" >&2; exit 1 ;;
esac
mkdir -p .tools
base="https://github.com/open-policy-agent/opa/releases/download/v${version}"
curl --fail --location --retry 3 "$base/$asset" --output ".tools/$asset"
curl --fail --location --retry 3 "$base/$asset.sha256" --output ".tools/$asset.sha256"
expected="$(awk '{print $1}' ".tools/$asset.sha256")"
actual="$(shasum -a 256 ".tools/$asset" | awk '{print $1}')"
test "$expected" = "$actual" || { echo "OPA checksum mismatch" >&2; exit 1; }
mv ".tools/$asset" .tools/opa
chmod 0755 .tools/opa
.tools/opa version
