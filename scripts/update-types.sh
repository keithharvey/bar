#!/usr/bin/env zsh
set -euo pipefail

# Root of the project (script is in scripts/)
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TYPESDIR="$ROOT/vendor/types"

mkdir -p "$TYPESDIR"

fetch_repo() {
  local url="$1"
  local dest="$2"
  if [ -d "$dest/.git" ]; then
    echo "Updating $url in $dest"
    git -C "$dest" pull --ff-only
  else
    echo "Cloning $url into $dest"
    rm -rf "$dest"
    git clone --depth=1 "$url" "$dest"
  fi
  # Strip .git so vendored code isn’t treated as a sub-repo
  rm -rf "$dest/.git"
}

fetch_repo https://github.com/LuaCATS/busted "$TYPESDIR/busted"
fetch_repo https://github.com/LuaCATS/luassert "$TYPESDIR/luassert"

echo "✅ Updated type definitions in $TYPESDIR"
