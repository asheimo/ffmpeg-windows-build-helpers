#!/usr/bin/env bash
# bzip2.sh — builds bzip2, a block-sorting file compressor library.
# Used by: ffmpeg (bzlib demuxer support), freetype, and others.
# https://sourceware.org/bzip2/

# Guard against being sourced more than once
[[ -n "${BZIP2_SH_LOADED:-}" ]] && return
BZIP2_SH_LOADED=1

# build_bzip2()
# Downloads, patches, builds, and installs bzip2.
# Version is controlled by BZIP2_VERSION in versions.conf.
# Skips any step that has already completed successfully.
#
# bzip2 does not use ./configure — it uses a plain Makefile.
# We pass CC/AR/RANLIB on the make command line so the cross-compiler
# is used. The patch fixes two things:
#   1. Changes CC/AR/RANLIB to use ?= so our env vars take precedence.
#   2. Removes the WINAPI calling convention that breaks static linking.
# Installation is manual (no 'make install' target for the static lib).
build_bzip2() {
  local version="${BZIP2_VERSION:?BZIP2_VERSION not set in versions.conf}"
  local folder="bzip2-${version}"
  local url="https://sourceware.org/pub/bzip2/${folder}.tar.gz"

  download_and_unpack_file "$url" "${folder}.tar.gz" "$folder"

  (
    cd "$folder"

    do_apply_patch "$SCRIPT_DIR/patches/bzip2-1.0.8_brokenstuff.diff"

    local touch_name
    touch_name="$(get_touchfile_name "already_installed_bzip2_$(pwd)")"

    if [[ ! -f "$touch_name" ]]; then
      echo "  [make] Building libbz2.a..."
      # shellcheck disable=SC2086 — CC/AR/RANLIB passed explicitly; no quotes so make splits them
      make -j"$(nproc)" libbz2.a \
        CC="${CROSS_PREFIX}gcc" \
        AR="${CROSS_PREFIX}ar" \
        RANLIB="${CROSS_PREFIX}ranlib"

      echo "  [make] Installing..."
      install -m644 bzlib.h "$BUILD_PREFIX/include/bzlib.h"
      install -m644 libbz2.a "$BUILD_PREFIX/lib/libbz2.a"

      mkdir -p "$(dirname "$touch_name")"
      touch "$touch_name"
    else
      echo "  [make] Already built and installed, skipping."
    fi
  )
}
