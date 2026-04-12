#!/usr/bin/env bash
# libass.sh — builds libass, a portable ASS/SSA subtitle renderer.
# Used by: ffmpeg --enable-libass
# Requires: freetype, fribidi, harfbuzz, fontconfig, libiconv
# https://github.com/libass/libass

# Guard against being sourced more than once
[[ -n "${LIBASS_SH_LOADED:-}" ]] && return
LIBASS_SH_LOADED=1

# build_libass()
# Clones or updates libass and builds the static library.
# Version is controlled by LIBASS_VERSION in versions.conf.
# Skips any step that has already completed successfully.
build_libass() {
  local version="${LIBASS_VERSION:?LIBASS_VERSION not set in versions.conf}"
  local folder="libass"

  do_git_checkout \
    "https://github.com/libass/libass.git" \
    "$folder" \
    "$version"

  (
    cd "$folder"
    if [[ ! -f configure ]]; then
      autoreconf -fi
    fi
    do_configure "./configure" \
      "--prefix=${BUILD_PREFIX}" \
      "--host=${CROSS_PREFIX%-}" \
      "--disable-shared" \
      "--enable-static" \
      "--disable-asm"
    do_make_and_make_install
  )
}
