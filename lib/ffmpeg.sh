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
# Skips any step that has already completed successfully.
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

    # Each flag is a separate argument — spaces inside flag values are preserved
    # because do_configure uses "$@" to pass them through to ./configure intact.
    do_configure "./configure" \
      "--prefix=${BUILD_PREFIX}" \
      "--pkg-config=pkg-config" \
      "--pkg-config-flags=--static" \
      "--extra-cflags=-I${BUILD_PREFIX}/include" \
      "--extra-ldflags=-L${BUILD_PREFIX}/lib -static -static-libgcc -static-libstdc++" \
      "--extra-libs=-lpthread" \
      "--cross-prefix=${CROSS_PREFIX}" \
      "--arch=x86_64" \
      "--target-os=mingw32" \
      "--enable-cross-compile" \
      "--disable-shared" \
      "--enable-static" \
      "--disable-debug" \
      "--disable-doc" \
      "--enable-gpl" \
      "--enable-version3" \
      "--enable-libx264" \
      "--enable-libx265" \
      "--enable-nvenc" \
      "--enable-nvdec" \
      "--enable-cuda" \
      "--enable-cuvid" \
      "--enable-cuda-llvm" \
      "--enable-ffnvcodec"

    do_make
    do_make_install
  )
}
