#!/usr/bin/env bash
# clean.sh — removes all build output, downloaded sources, and logs.
# Leaves only source code, scripts, patches, and versions.conf.
# Run this before a fresh build to start from a clean slate.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "This will permanently delete the following directories:"
echo ""
echo "  sandbox/         (compiled libraries and ffmpeg.exe)"
echo "  build/           (library source trees)"
echo "  downloads/       (downloaded tarballs and archives)"
echo "  logs/            (build logs and touchfiles)"
echo "  cross_compilers/ (llvm-mingw toolchain)"
echo ""
echo "A full rebuild from scratch will be required afterwards."
echo ""
read -r -p "Type 'yes' to continue: " confirm1
if [[ "$confirm1" != "yes" ]]; then
  echo "Aborted."
  exit 0
fi

echo ""
echo "This cannot be undone."
echo ""
read -r -p "Type 'YES' to confirm: " confirm2
if [[ "$confirm2" != "YES" ]]; then
  echo "Aborted."
  exit 0
fi

echo ""
echo "Cleaning all build output..."

rm -rf "$SCRIPT_DIR/sandbox"
echo "  removed: sandbox/"

rm -rf "$SCRIPT_DIR/build"
echo "  removed: build/"

rm -rf "$SCRIPT_DIR/downloads"
echo "  removed: downloads/"

rm -rf "$SCRIPT_DIR/logs"
echo "  removed: logs/"

rm -rf "$SCRIPT_DIR/cross_compilers"
echo "  removed: cross_compilers/"

echo ""
echo "Done. Ready for a clean build."
