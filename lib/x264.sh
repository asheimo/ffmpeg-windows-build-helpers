#!/usr/bin/env bash
# x264.sh — builds libx264, an H.264/AVC encoder library.
# Used by: ffmpeg --enable-libx264
# https://code.videolan.org/videolan/x264

# Guard against being sourced more than once
[[ -n "${X264_SH_LOADED:-}" ]] && return
X264_SH_LOADED=1

# build_x264()
# Clones or updates x264 from the stable branch and builds the static library.
# Version is controlled by X264_VERSION in versions.conf.
# Skips any step that has already completed successfully.
#
# x264 uses its own handwritten ./configure script (not autoconf).
# Key flags:
#   --host            — target triplet for cross-compilation
#   --cross-prefix    — prefix for cross-compiler tools (e.g. x86_64-w64-mingw32-)
#   --enable-static   — build static library only (no DLL)
#   --disable-lavf    — disable libavformat integration (not needed for our build)
#   --disable-cli     — skip building x264.exe, we only need the library
#   --bit-depth=all   — support both 8-bit and 10-bit encoding
#   --enable-strip    — strip debug symbols from the library
build_x264() {
  local version="${X264_VERSION:?X264_VERSION not set in versions.conf}"
  local folder="x264"

  do_git_checkout \
    "https://code.videolan.org/videolan/x264.git" \
    "$folder" \
    "$version"

  (
    cd "$folder"
    do_configure "./configure" \
      "--host=${CROSS_PREFIX%-}" \
      "--cross-prefix=${CROSS_PREFIX}" \
      "--prefix=$BUILD_PREFIX" \
      "--enable-static" \
      "--disable-lavf" \
      "--disable-cli" \
      "--bit-depth=all" \
      "--enable-strip"
    do_make_and_make_install
  )
}
