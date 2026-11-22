#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
prefix=$(git rev-parse --show-prefix)
sha=$(git rev-parse --short HEAD)
mkdir -p dist
output="dist/Fieldglass-source-$sha.zip"
git archive --format=zip --prefix=Fieldglass/ -o "$output" "HEAD:${prefix%/}"
shasum -a 256 "$output" > "$output.sha256"
echo "$output"
