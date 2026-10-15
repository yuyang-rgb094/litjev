#!/usr/bin/env bash
# LitJev weights fetcher — resumable, retry-friendly, multi-channel.
#
#   bash download_model.sh [DEST]        # DEST defaults to ./model
#
# The old script used `gh release download`, which cannot resume: one dropped
# connection restarted a whole file. This version prefers ModelScope (fast and
# resumable from mainland China), falls back to Hugging Face, and only then to
# the GitHub release.
#
# Environment overrides:
#   LITJEV_SOURCE        modelscope | hf | github   (default: auto)
#   LITJEV_MODELSCOPE_ID <org>/LitJev-v3.1
#   LITJEV_HF_ID         <user>/LitJev-v3.1
#   LITJEV_REPO          yuyang-rgb094/litjev      (GitHub fallback)
#   LITJEV_TAG           v3.1
#   HF_ENDPOINT          https://hf-mirror.com     (mainland mirror)

set -euo pipefail

TAG="${LITJEV_TAG:-v3.1}"
DEST="${1:-./model}"
SOURCE="${LITJEV_SOURCE:-auto}"
MODELSCOPE_ID="${LITJEV_MODELSCOPE_ID:-yuyang094/LitJev-v3.1}"
HF_ID="${LITJEV_HF_ID:-}"
GH_REPO="${LITJEV_REPO:-yuyang-rgb094/litjev}"

mkdir -p "$DEST"

fetch_modelscope() {
  [ -n "$MODELSCOPE_ID" ] || return 1
  python3 -m pip show modelscope >/dev/null 2>&1 \
    || python3 -m pip install -q -U modelscope
  echo "[modelscope] $MODELSCOPE_ID -> $DEST"
  modelscope download --model "$MODELSCOPE_ID" --local_dir "$DEST"
}

fetch_hf() {
  [ -n "$HF_ID" ] || return 1
  python3 -m pip show huggingface_hub >/dev/null 2>&1 \
    || python3 -m pip install -q -U "huggingface_hub[cli]"
  echo "[hf] $HF_ID -> $DEST (endpoint=${HF_ENDPOINT:-https://huggingface.co})"
  hf download "$HF_ID" --local-dir "$DEST"
}

fetch_github() {
  command -v gh >/dev/null 2>&1 || {
    echo "gh CLI is required for the GitHub fallback: https://cli.github.com/" >&2
    return 1
  }
  echo "[github] $GH_REPO@$TAG -> $DEST"
  local i
  for i in 1 2 3 4 5; do
    if gh release download "$TAG" --repo "$GH_REPO" --dir "$DEST" --clobber; then
      break
    fi
    echo "  attempt $i failed; retrying in 30s ..." >&2
    sleep 30
  done

  # GitHub's 2GB asset cap forced the first shard to be split into .part-* files.
  local parts base
  parts="$(ls "$DEST"/model-00001-of-*.safetensors.part-* 2>/dev/null || true)"
  if [ -n "$parts" ]; then
    base="$(printf '%s\n' "$parts" | head -1 | sed 's/\.part-[0-9]*$//')"
    echo "[github] reassembling $(basename "$base") ..."
    cat "$DEST"/model-00001-of-*.safetensors.part-* > "$base"
  fi
}

case "$SOURCE" in
  modelscope) fetch_modelscope ;;
  hf)         fetch_hf ;;
  github)     fetch_github ;;
  auto)
    fetch_modelscope || fetch_hf || fetch_github || {
      echo "All channels failed. Check the repository IDs or your network." >&2
      exit 1
    }
    ;;
  *)
    echo "Unknown LITJEV_SOURCE: $SOURCE" >&2
    exit 1
    ;;
esac

if [ -f "$DEST/SHA256SUMS" ]; then
  echo "[verify] checking SHA256SUMS ..."
  ( cd "$DEST" && { sha256sum -c SHA256SUMS 2>/dev/null || shasum -a 256 -c SHA256SUMS; } )
fi

echo "Done. Model directory is ready at $DEST"
