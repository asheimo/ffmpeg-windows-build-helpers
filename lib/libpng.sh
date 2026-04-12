#!/usr/bin/env bash
# libpng.sh — builds libpng, a PNG image library.
# Required by: freetype (PNG embedded bitmap support)
# https://github.com/pnggroup/libpng

# Guard against being sourced more than once
[[ -n "${LIBPNG_SH_LOADED:-}" ]] && return
LIBPNG_SH_LOADED=1

# build_libpng()
# Clones or updates libpng and builds the static library.
# Version is controlled by LIBPNG_VERSION in versions.conf.
# Skips any step that has already completed successfully.
build_libpng() {
  local version="${LIBPNG_VERSION:?LIBPNG_VERSION not set in versions.conf}"
  local folder="libpng"

  do_git_checkout \
    "https://github.com/pnggroup/libpng.git" \
    "$folder" \
    "$version"

  (
    cd "$folder"
    # autogen.sh is required when building from git
    if [[ ! -f configure ]]; then
      autoreconf -fi
    fi
    do_configure "./configure" \
      "--prefix=${BUILD_PREFIX}" \
      "--host=${CROSS_PREFIX%-}" \
      "--disable-shared" \
      "--enable-static"
    do_make_and_make_install
  )
}
