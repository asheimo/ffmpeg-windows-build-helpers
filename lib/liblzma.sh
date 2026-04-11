#!/usr/bin/env bash
# liblzma.sh — builds liblzma (from the xz-utils package).
# Used by: ffmpeg (lzma/xz demuxer support) and libxml2.
# https://tukaani.org/xz/

# Guard against being sourced more than once
[[ -n "${LIBLZMA_SH_LOADED:-}" ]] && return
LIBLZMA_SH_LOADED=1

# build_liblzma()
# Downloads, configures, builds, and installs liblzma from the xz source tree.
# Version is controlled by LIBLZMA_VERSION in versions.conf.
# Skips any step that has already completed successfully.
#
# We disable all the xz command-line tools and extras — we only need
# the library itself for ffmpeg to link against.
build_liblzma() {
  local version="${LIBLZMA_VERSION:?LIBLZMA_VERSION not set in versions.conf}"
  local folder="xz-${version}"
  local url="https://github.com/tukaani-project/xz/releases/download/v${version}/${folder}.tar.xz"

  download_and_unpack_file "$url" "${folder}.tar.xz" "$folder"

  (
    cd "$folder"
    do_configure "./configure" \
      "--prefix=$BUILD_PREFIX" \
      "--host=${CROSS_PREFIX%-}" \
      "--disable-shared" \
      "--enable-static" \
      "--disable-xz" \
      "--disable-xzdec" \
      "--disable-lzmadec" \
      "--disable-lzmainfo" \
      "--disable-scripts" \
      "--disable-doc" \
      "--disable-nls"
    do_make_and_make_install
  )
}
