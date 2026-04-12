#!/usr/bin/env bash
# libiconv.sh — builds GNU libiconv, a character encoding conversion library.
# Required by: fontconfig (--enable-iconv), libxml2
# https://www.gnu.org/software/libiconv/

# Guard against being sourced more than once
[[ -n "${LIBICONV_SH_LOADED:-}" ]] && return
LIBICONV_SH_LOADED=1

# build_libiconv()
# Downloads, configures, builds, and installs libiconv.
# Version is controlled by LIBICONV_VERSION in versions.conf.
# Skips any step that has already completed successfully.
build_libiconv() {
  local version="${LIBICONV_VERSION:?LIBICONV_VERSION not set in versions.conf}"
  local folder="libiconv-${version}"
  local url="https://ftp.gnu.org/pub/gnu/libiconv/${folder}.tar.gz"

  download_and_unpack_file "$url" "${folder}.tar.gz" "$folder"

  (
    cd "$folder"
    do_configure "./configure" \
      "--prefix=${BUILD_PREFIX}" \
      "--host=${CROSS_PREFIX%-}" \
      "--disable-shared" \
      "--enable-static" \
      "--disable-nls"
    do_make_and_make_install
  )
}
