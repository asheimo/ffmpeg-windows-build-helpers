#!/usr/bin/env bash
# build.sh — main entry point
# Usage: ./build.sh [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load menu/settings handling first — parse_args reads/writes build.cfg
# and sets FEATURE_* flags before any build logic runs.
source "$SCRIPT_DIR/lib/menu.sh"
parse_args "$@"

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
source "$SCRIPT_DIR/lib/npp-libs.sh"
source "$SCRIPT_DIR/lib/x264.sh"
source "$SCRIPT_DIR/lib/x265.sh"
source "$SCRIPT_DIR/lib/ffmpeg.sh"

echo "ffmpeg-build: starting"
echo "  Target:   $COMPILER_FLAVOR"
echo "  License:  $LICENSE"
echo ""

# Check for WSL binfmt_misc interop — if enabled, Windows .exe files are
# automatically executed by Windows rather than treated as build artifacts.
# This causes freetype's apinames.exe to fail when writing to Linux paths.
# Must be disabled before building.
# WSL2 uses WSLInterop-late; older versions use WSLInterop.
WSL_INTEROP_FILE=""
for f in /proc/sys/fs/binfmt_misc/WSLInterop-late /proc/sys/fs/binfmt_misc/WSLInterop; do
  if [[ -f "$f" ]]; then
    WSL_INTEROP_FILE="$f"
    break
  fi
done

if [[ -n "$WSL_INTEROP_FILE" ]] && grep -q "^enabled" "$WSL_INTEROP_FILE" 2>/dev/null; then
  echo "Error: WSL binfmt_misc interop is enabled. This will cause freetype to fail."
  echo ""
  echo "Disable it by running:"
  echo "  sudo bash -c 'echo 0 > ${WSL_INTEROP_FILE}'"
  echo ""
  echo "Then re-run this script."
  exit 1
fi

# Create required directories
mkdir -p "$SCRIPT_DIR/logs/touched"
mkdir -p "$SCRIPT_DIR/logs/libraries"
mkdir -p "$SCRIPT_DIR/downloads"
mkdir -p "$BUILD_PREFIX"
mkdir -p "$BUILD_DIR"

# Prune old log folders, keeping only the most recent LOG_RETENTION runs.
mapfile -t _old_logs < <(ls -1dt "$SCRIPT_DIR/logs/libraries"/*/ 2>/dev/null | tail -n +"$((LOG_RETENTION + 1))")
for _log_dir in "${_old_logs[@]}"; do
  rm -rf "$_log_dir"
done
unset _old_logs _log_dir

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

# Export PKG_CONFIG_PATH so all library builds can find .pc files from the
# sandbox prefix. Set once here so it's inherited by all run_library calls
# rather than relying on subshell export which doesn't survive the tee pipe.
export PKG_CONFIG_PATH="${BUILD_PREFIX}/lib/pkgconfig"

# Export CPPFLAGS and LDFLAGS so all library builds can find headers and
# static libraries from the sandbox prefix via direct linker/compiler checks,
# not just pkg-config. Required for libraries that use -lz, -lbz2 etc. directly.
export CPPFLAGS="-I${BUILD_PREFIX}/include"
export LDFLAGS="-L${BUILD_PREFIX}/lib"

# Build dependencies in order — each group depends on the previous
run_library "zlib"             build_zlib
run_library "bzip2"            build_bzip2
run_library "liblzma"          build_liblzma

# Subtitle rendering stack (order matters) — only built when subtitles enabled
if [[ "${FEATURE_SUBTITLES}" == "y" ]]; then
  run_library "libiconv"         build_libiconv
  run_library "libpng"           build_libpng
  run_library "freetype"         build_freetype
  run_library "harfbuzz"         build_harfbuzz
  run_library "fribidi"          build_fribidi
  run_library "libxml2"          build_libxml2
  run_library "fontconfig"       build_fontconfig
  run_library "libass"           build_libass
fi

# Video codec dependencies
run_library "nv-codec-headers" build_nv_codec_headers
if [[ "${FEATURE_NVIDIA_FILTERS}" == "y" ]]; then
  run_library "npp-libs"         build_npp_libs
fi
run_library "x264"             build_x264
run_library "x265"             build_x265

# Verify all ffmpeg dependencies built successfully before attempting the ffmpeg build.
# Checks each library's build folder for any .pc or .a file at the root level.
# If none found the library failed to install and ffmpeg configure will fail anyway.
check_ffmpeg_dependencies() {
  local missing=()

  # Base required folders — always checked
  local required_folders=(
    "zlib-1.3.1"
    "bzip2-1.0.8"
    "xz-5.6.3"
    "nv-codec-headers"
    "x264"
    "x265"
  )

  # NVIDIA GPU filters — npp-libs produces no .pc or .a files of its own
  # (headers and import libs are installed directly to BUILD_PREFIX, not via make install)
  # so it is excluded from the folder check. Instead verify via touchfile.
  if [[ "${FEATURE_NVIDIA_FILTERS}" == "y" ]]; then
    local npp_touch
    npp_touch="$(ls "$SCRIPT_DIR/logs/touched/already_installed_npp_libs_"* 2>/dev/null | head -1)"
    if [[ -z "$npp_touch" ]]; then
      missing+=("npp-libs")
    fi
  fi

  # Subtitle rendering stack — only checked when feature is enabled
  if [[ "${FEATURE_SUBTITLES}" == "y" ]]; then
    required_folders+=(
      "libiconv-1.17"
      "libpng"
      "freetype-2.13.3"
      "fribidi-1.0.16"
      "harfbuzz"
      "libxml2"
      "fontconfig-2.17.1"
      "libass"
    )
  fi

  for folder in "${required_folders[@]}"; do
    local found
    found=$(find "${BUILD_DIR}/${folder}" \( -name "*.pc" -o -name "*.a" \) 2>/dev/null | head -1)
    if [[ -z "$found" ]]; then
      missing+=("$folder")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo ""
    echo "ERROR: The following required libraries did not build successfully:"
    for folder in "${missing[@]}"; do
      echo "  - $folder"
    done
    echo ""
    echo "Check logs/libraries/ for details. Fix the above before retrying."
    exit 1
  fi

  echo "  [deps] All ffmpeg dependencies present."
}

check_ffmpeg_dependencies
run_library "ffmpeg"       build_ffmpeg

echo ""
echo "========================================"
echo "  Build complete"
echo "========================================"
echo ""

# Copy ffmpeg.exe and ffprobe.exe to release folder
mkdir -p "$SCRIPT_DIR/release"
cp "${BUILD_PREFIX}/bin/ffmpeg.exe" "$SCRIPT_DIR/release/" 2>/dev/null || true
cp "${BUILD_PREFIX}/bin/ffprobe.exe" "$SCRIPT_DIR/release/" 2>/dev/null || true

RELEASE_WIN_PATH="$(echo "$SCRIPT_DIR/release/ffmpeg.exe" | sed 's|/mnt/c/|C:\\|; s|/|\\|g')"
echo "  To verify: \"${RELEASE_WIN_PATH}\" -version"
echo ""
