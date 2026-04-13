#!/usr/bin/env bash
# ffmpeg.sh — cross-compiles ffmpeg for Windows (x86_64) with NVENC/NVDEC,
# libx264, and libx265. Produces a fully static ffmpeg.exe (no MinGW DLLs).
# https://ffmpeg.org

# Guard against being sourced more than once
[[ -n "${FFMPEG_SH_LOADED:-}" ]] && return
FFMPEG_SH_LOADED=1

# build_ffmpeg()
# Clones or updates ffmpeg and builds it against the libraries in BUILD_PREFIX.
# Version is controlled by FFMPEG_VERSION in versions.conf.
# Always runs configure, make, and install — no touchfiles — so any change to
# flags or dependencies is always picked up without manual cleanup.
build_ffmpeg() {
  local version="${FFMPEG_VERSION:?FFMPEG_VERSION not set in versions.conf}"
  local folder="ffmpeg"

  do_git_checkout \
    "https://github.com/FFmpeg/FFmpeg.git" \
    "$folder" \
    "$version"

  (
    cd "$folder"

    # pkg-config must find .pc files from our sandbox prefix.
    export PKG_CONFIG_PATH="${BUILD_PREFIX}/lib/pkgconfig"

    echo "  [configure] Running ./configure..."
    # Build the configure flags array conditionally based on feature selections
    local ffmpeg_flags=(
      "--prefix=${BUILD_PREFIX}"
      "--pkg-config=pkg-config"
      "--pkg-config-flags=--static"
      "--extra-cflags=-I${BUILD_PREFIX}/include"
      "--extra-ldflags=-L${BUILD_PREFIX}/lib -static -static-libgcc -static-libstdc++"
      "--extra-libs=-lpthread"
      "--cross-prefix=${CROSS_PREFIX}"
      "--arch=x86_64"
      "--target-os=mingw32"
      "--enable-cross-compile"
      "--disable-shared"
      "--enable-static"
      "--disable-debug"
      "--disable-doc"
      "--disable-autodetect"
      "--enable-gpl"
      "--enable-version3"
      "--enable-libx264"
      "--enable-libx265"
      "--enable-nvenc"
      "--enable-nvdec"
      "--enable-cuda"
      "--enable-cuvid"
      "--enable-cuda-llvm"
      "--enable-ffnvcodec"
    )

    # Subtitle rendering flags — only when feature is enabled
    if [[ "${FEATURE_SUBTITLES:-n}" == "y" ]]; then
      ffmpeg_flags+=(
        "--enable-libass"
        "--enable-fontconfig"
      )
    fi

    "./configure" "${ffmpeg_flags[@]}"

    echo "  [make] Building with $(nproc) jobs..."
    make -j"$(nproc)"

    echo "  [make] Installing..."
    make install
  )
}
