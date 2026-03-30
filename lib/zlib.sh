#!/usr/bin/env bash
# zlib.sh — builds zlib, a general-purpose compression library.
# Used by: ffmpeg, libpng, and many others.
# https://github.com/madler/zlib

# Guard against being sourced more than once
[[ -n "${ZLIB_SH_LOADED:-}" ]] && return
ZLIB_SH_LOADED=1

# build_zlib()
# Downloads, configures, builds, and installs zlib.
# Version is controlled by ZLIB_VERSION in versions.conf.
# Skips any step that has already completed successfully.
build_zlib() {
  local version="${ZLIB_VERSION:?ZLIB_VERSION not set in versions.conf}"  # :? means exit with error if unset
  local url="https://github.com/madler/zlib/archive/${version}.tar.gz"
  local folder="zlib-${version#v}"

  download_and_unpack_file "$url" "${folder}.tar.gz" "$folder"

  (
    cd "$folder"
    do_configure "--prefix=$BUILD_PREFIX --static" "./configure"
    do_make_and_make_install
  )
}