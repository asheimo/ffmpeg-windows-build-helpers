#!/usr/bin/env bash
# nv-codec-headers.sh — installs NVIDIA codec API headers (ffnvcodec).
# Required by ffmpeg to enable NVENC/NVDEC hardware acceleration.
# No compilation — this is a headers-only install.
# https://github.com/FFmpeg/nv-codec-headers

# Guard against being sourced more than once
[[ -n "${NV_CODEC_HEADERS_SH_LOADED:-}" ]] && return
NV_CODEC_HEADERS_SH_LOADED=1

# build_nv_codec_headers()
# Clones or updates the nv-codec-headers repo and installs the headers.
# Version is controlled by NV_CODEC_HEADERS_VERSION in versions.conf.
# Skips install if already completed successfully.
build_nv_codec_headers() {
  local version="${NV_CODEC_HEADERS_VERSION:?NV_CODEC_HEADERS_VERSION not set in versions.conf}"
  local folder="nv-codec-headers"

  do_git_checkout \
    "https://github.com/FFmpeg/nv-codec-headers.git" \
    "$folder" \
    "$version"

  (
    cd "$folder"

    local touch_name
    touch_name="$(get_touchfile_name "already_installed_nv_codec_headers_${version}")"

    if [[ ! -f "$touch_name" ]]; then
      echo "  [make] Installing headers..."
      make install PREFIX="$BUILD_PREFIX"
      mkdir -p "$(dirname "$touch_name")"
      touch "$touch_name"
    else
      echo "  [make] Already installed, skipping."
    fi
  )
}
