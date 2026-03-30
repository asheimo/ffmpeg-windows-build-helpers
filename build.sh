#!/usr/bin/env bash
# build.sh — main entry point
# Usage: ./build.sh [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Timestamp for this run — used to name log files uniquely
BUILD_TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
export BUILD_TIMESTAMP

# Load configuration, version pins, and helper functions
source "$SCRIPT_DIR/versions.conf"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/zlib.sh"

# Export cross-compiler tools so all library builds use the right compiler.
# These are environment variables, so they're inherited by every subprocess
# that build.sh spawns — no need to pass them to each library individually.
export CC="${CROSS_PREFIX}gcc"
export CXX="${CROSS_PREFIX}g++"
export AR="${CROSS_PREFIX}ar"
export RANLIB="${CROSS_PREFIX}ranlib"
export LD="${CROSS_PREFIX}ld"
export STRIP="${CROSS_PREFIX}strip"
export WINDRES="${CROSS_PREFIX}windres"

echo "ffmpeg-build: starting"
echo "  Target:   $COMPILER_FLAVOR"
echo "  Non-free: $NON_FREE"
echo "  License:  $LICENSE"
echo ""

# Create required directories
mkdir -p "$SCRIPT_DIR/logs/touched"
mkdir -p "$SCRIPT_DIR/downloads"
mkdir -p "$BUILD_PREFIX"

# Verify all required tools are present before starting
check_prerequisites

# Build dependencies
run_library "zlib" build_zlib