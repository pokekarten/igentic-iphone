#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
prefix=$(git rev-parse --show-prefix)
sha=$(git rev-parse --short HEAD)
mkdir -p dist
output="dist/Fieldglass-source-$sha.zip"
root=$(git rev-parse --show-toplevel)
git -C "$root" archive --format=zip --prefix=Fieldglass/ -o "$PWD/$output" "HEAD:${prefix%/}"
unzip -p "$output" Fieldglass/plugin/package-lock.json > /dev/null
unzip -p "$output" Fieldglass/project.yml > /dev/null
shasum -a 256 "$output" > "$output.sha256"
echo "$output"
