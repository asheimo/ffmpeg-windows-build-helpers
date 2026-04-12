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
source "$SCRIPT_DIR/lib/toolchain.sh"
source "$SCRIPT_DIR/lib/zlib.sh"
source "$SCRIPT_DIR/lib/bzip2.sh"
source "$SCRIPT_DIR/lib/liblzma.sh"
source "$SCRIPT_DIR/lib/libiconv.sh"
source "$SCRIPT_DIR/lib/libpng.sh"
source "$SCRIPT_DIR/lib/freetype.sh"
source "$SCRIPT_DIR/lib/fribidi.sh"
source "$SCRIPT_DIR/lib/harfbuzz.sh"
source "$SCRIPT_DIR/lib/libxml2.sh"
source "$SCRIPT_DIR/lib/fontconfig.sh"
source "$SCRIPT_DIR/lib/libass.sh"
source "$SCRIPT_DIR/lib/nv-codec-headers.sh"
source "$SCRIPT_DIR/lib/x264.sh"
source "$SCRIPT_DIR/lib/x265.sh"
source "$SCRIPT_DIR/lib/ffmpeg.sh"

echo "ffmpeg-build: starting"
echo "  Target:   $COMPILER_FLAVOR"
echo "  Non-free: $NON_FREE"
echo "  License:  $LICENSE"
echo ""

# Create required directories
mkdir -p "$SCRIPT_DIR/logs/touched"
mkdir -p "$SCRIPT_DIR/downloads"
mkdir -p "$BUILD_PREFIX"
mkdir -p "$BUILD_DIR"

# Verify host prerequisites are present before starting
check_prerequisites

# Install the llvm-mingw cross-compiler toolchain first.
# This must run before PATH is updated and before any library builds.
echo "========================================"
echo "  Toolchain: llvm-mingw"
echo "========================================"
echo ""
build_toolchain

# Prepend llvm-mingw bin to PATH so all subsequent builds use it.
# This replaces the Ubuntu-packaged mingw-w64 toolchain entirely.
TOOLCHAIN_BIN="$(get_toolchain_bin_dir)"
export PATH="${TOOLCHAIN_BIN}:${PATH}"

# Export cross-compiler tools so all library builds use the right compiler.
export CC="${CROSS_PREFIX}gcc"
export CXX="${CROSS_PREFIX}g++"
export AR="${CROSS_PREFIX}ar"
export RANLIB="${CROSS_PREFIX}ranlib"
export LD="${CROSS_PREFIX}ld"
export STRIP="${CROSS_PREFIX}strip"
export WINDRES="${CROSS_PREFIX}windres"

# Build dependencies in order — each group depends on the previous
run_library "zlib"             build_zlib
run_library "bzip2"            build_bzip2
run_library "liblzma"          build_liblzma

# Subtitle rendering stack (order matters)
run_library "libiconv"         build_libiconv
run_library "libpng"           build_libpng
run_library "freetype"         build_freetype
run_library "fribidi"          build_fribidi
run_library "harfbuzz"         build_harfbuzz
run_library "libxml2"          build_libxml2
run_library "fontconfig"       build_fontconfig
run_library "libass"           build_libass

# Video codec dependencies
run_library "nv-codec-headers" build_nv_codec_headers
run_library "x264"             build_x264
run_library "x265"             build_x265

# FFmpeg
run_library "ffmpeg"           build_ffmpeg
