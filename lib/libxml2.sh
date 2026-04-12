#!/usr/bin/env bash
# libxml2.sh — builds libxml2, an XML parsing library.
# Required by: fontconfig (--enable-libxml2, replaces expat)
# https://gitlab.gnome.org/GNOME/libxml2

# Guard against being sourced more than once
[[ -n "${LIBXML2_SH_LOADED:-}" ]] && return
LIBXML2_SH_LOADED=1

# build_libxml2()
# Clones or updates libxml2 and builds the static library.
# Version is controlled by LIBXML2_VERSION in versions.conf.
# Skips any step that has already completed successfully.
#
# We disable everything we don't need — we only want XML parsing for fontconfig.
build_libxml2() {
  local version="${LIBXML2_VERSION:?LIBXML2_VERSION not set in versions.conf}"
  local folder="libxml2"

  do_git_checkout \
    "https://gitlab.gnome.org/GNOME/libxml2.git" \
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
      "--without-python" \
      "--without-http" \
      "--without-ftp" \
      "--with-iconv=${BUILD_PREFIX}" \
      "--with-zlib=${BUILD_PREFIX}" \
      "--without-lzma"
    do_make_and_make_install
  )
}
