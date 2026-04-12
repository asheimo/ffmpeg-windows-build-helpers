#!/usr/bin/env bash
# freetype.sh — builds FreeType, a font rendering library.
# Required by: harfbuzz, libass, fontconfig
# https://freetype.org
#
# Note: FreeType and HarfBuzz have a circular dependency — FreeType can use
# HarfBuzz for OpenType layout, and HarfBuzz uses FreeType for font access.
# We build FreeType without HarfBuzz first (--without-harfbuzz), then build
# HarfBuzz, then rebuild FreeType with HarfBuzz support.
# This first pass uses --without-harfbuzz.

# Guard against being sourced more than once
[[ -n "${FREETYPE_SH_LOADED:-}" ]] && return
FREETYPE_SH_LOADED=1

# build_freetype()
# Downloads, configures, builds, and installs FreeType.
# Version is controlled by FREETYPE_VERSION in versions.conf.
# Skips any step that has already completed successfully.
#
# Pass --without-harfbuzz on first build to break the circular dependency.
# After harfbuzz is built, call build_freetype again to rebuild with HarfBuzz.
build_freetype() {
  local version="${FREETYPE_VERSION:?FREETYPE_VERSION not set in versions.conf}"
  local folder="freetype-${version}"
  local url="https://downloads.sourceforge.net/project/freetype/freetype2/${version}/${folder}.tar.xz"

  download_and_unpack_file "$url" "${folder}.tar.xz" "$folder"

  (
    cd "$folder"
    do_configure "./configure" \
      "--prefix=${BUILD_PREFIX}" \
      "--host=${CROSS_PREFIX%-}" \
      "--disable-shared" \
      "--enable-static" \
      "--with-zlib" \
      "--with-bzip2" \
      "--with-png" \
      "--without-harfbuzz"
    do_make_and_make_install
  )
}
