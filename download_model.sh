#!/usr/bin/env bash
set -euo pipefail

REPO="${LITJEV_REPO:-yuyang-rgb094/litjev}"
TAG="${LITJEV_TAG:-v3.1}"
DEST="${1:-./model}"

command -v gh >/dev/null 2>&1 || {
  echo "gh CLI is required: https://cli.github.com/" >&2
  exit 1
}

mkdir -p "$DEST"
echo "Downloading LitJev $TAG to $DEST ..."
gh release download "$TAG" --repo "$REPO" --dir "$DEST" --clobber

cd "$DEST"
echo "Reassembling the large first safetensors shard ..."
cat model-00001-of-00129.safetensors.part-* > model-00001-of-00129.safetensors

echo "Verifying SHA256 ..."
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum -c SHA256SUMS
else
  shasum -a 256 -c SHA256SUMS
fi

echo "Done. Model directory is ready at $(pwd)"
