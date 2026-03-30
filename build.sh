#!/usr/bin/env bash
# build.sh — main entry point
# Usage: ./build.sh [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/versions.conf"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/lib/common.sh"

echo "ffmpeg-build: starting"
echo "  Target:   $COMPILER_FLAVOR"
echo "  Non-free: $NON_FREE"
echo "  License:  $LICENSE"