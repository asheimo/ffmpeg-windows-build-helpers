#!/usr/bin/env bash
# fontconfig.sh — builds Fontconfig, a font discovery and configuration library.
# Required by: libass (system font lookup)
# Requires: libiconv, libxml2, freetype
# https://www.freedesktop.org/wiki/Software/fontconfig/

# Guard against being sourced more than once
[[ -n "${FONTCONFIG_SH_LOADED:-}" ]] && return
FONTCONFIG_SH_LOADED=1

# build_fontconfig()
# Downloads, configures, builds, and installs Fontconfig.
# Version is controlled by FONTCONFIG_VERSION in versions.conf.
# Skips any step that has already completed successfully.
#
# We use libxml2 instead of expat for XML parsing (--enable-libxml2)
# since libxml2 is already built as a dependency.
# Documentation and tests are disabled to keep the build lean.
build_fontconfig() {
  local version="${FONTCONFIG_VERSION:?FONTCONFIG_VERSION not set in versions.conf}"
  local folder="fontconfig-${version}"
  local url="https://gitlab.freedesktop.org/api/v4/projects/890/packages/generic/fontconfig/${version}/${folder}.tar.xz"

  download_and_unpack_file "$url" "${folder}.tar.xz" "$folder"

  (
    cd "$folder"
    do_configure "./configure" \
      "--prefix=${BUILD_PREFIX}" \
      "--host=${CROSS_PREFIX%-}" \
      "--disable-shared" \
      "--enable-static" \
      "--enable-iconv" \
      "--enable-libxml2" \
      "--disable-docs" \
      "--with-libiconv-prefix=${BUILD_PREFIX}" \
      "--with-freetype-config=${BUILD_PREFIX}/bin/freetype-config"
    do_make_and_make_install
  )
}
