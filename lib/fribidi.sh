#!/usr/bin/env bash
# fribidi.sh — builds GNU FriBidi, a Unicode bidirectional text algorithm library.
# Required by: libass (right-to-left text support)
# https://github.com/fribidi/fribidi

# Guard against being sourced more than once
[[ -n "${FRIBIDI_SH_LOADED:-}" ]] && return
FRIBIDI_SH_LOADED=1

# build_fribidi()
# Downloads, configures, builds, and installs FriBidi.
# Version is controlled by FRIBIDI_VERSION in versions.conf.
# Skips any step that has already completed successfully.
build_fribidi() {
  local version="${FRIBIDI_VERSION:?FRIBIDI_VERSION not set in versions.conf}"
  local folder="fribidi-${version}"
  local url="https://github.com/fribidi/fribidi/releases/download/v${version}/${folder}.tar.xz"

  download_and_unpack_file "$url" "${folder}.tar.xz" "$folder"

  (
    cd "$folder"
    do_configure "./configure" \
      "--prefix=${BUILD_PREFIX}" \
      "--host=${CROSS_PREFIX%-}" \
      "--disable-shared" \
      "--enable-static" \
      "--disable-debug" \
      "--disable-deprecated" \
      "--disable-docs"
    do_make_and_make_install
  )
}
