#!/usr/bin/env bash
# toolchain.sh — downloads and installs the llvm-mingw cross-compiler toolchain.
# llvm-mingw is a Clang/LLD based mingw-w64 toolchain that provides standard
# mingw-w64 tool names (x86_64-w64-mingw32-gcc, etc.) as wrappers around clang.
# https://github.com/mstorsjo/llvm-mingw

# Guard against being sourced more than once
[[ -n "${TOOLCHAIN_SH_LOADED:-}" ]] && return
TOOLCHAIN_SH_LOADED=1

# build_toolchain()
# Downloads and extracts the llvm-mingw prebuilt toolchain if not already present.
# Version is controlled by LLVM_MINGW_VERSION in versions.conf.
# Skips download and extraction if already completed successfully.
#
# The toolchain is extracted to:
#   cross_compilers/llvm-mingw-{VERSION}-ucrt-ubuntu-22.04-x86_64/
# After this function returns, build.sh prepends its bin/ to PATH so all
# subsequent library builds use it automatically.
build_toolchain() {
  local version="${LLVM_MINGW_VERSION:?LLVM_MINGW_VERSION not set in versions.conf}"
  local filename="llvm-mingw-${version}-ucrt-ubuntu-22.04-x86_64.tar.xz"
  local url="https://github.com/mstorsjo/llvm-mingw/releases/download/${version}/${filename}"
  local extract_dir="${CROSS_COMPILER_DIR}/llvm-mingw-${version}-ucrt-ubuntu-22.04-x86_64"
  local downloads_dir="$SCRIPT_DIR/downloads"
  local touch_name
  touch_name="$(get_touchfile_name "already_installed_llvm_mingw_${version}")"

  mkdir -p "$CROSS_COMPILER_DIR"
  mkdir -p "$downloads_dir"
  mkdir -p "$(dirname "$touch_name")"

  if [[ ! -f "$touch_name" ]]; then
    if [[ ! -f "$downloads_dir/$filename" ]]; then
      echo "  [download] Downloading llvm-mingw ${version}..."
      curl "$url" -L --retry 5 -o "$downloads_dir/$filename" -C -
    else
      echo "  [download] Already have ${filename}, skipping."
    fi

    echo "  [extract] Extracting llvm-mingw ${version}..."
    tar -xf "$downloads_dir/$filename" -C "$CROSS_COMPILER_DIR"
    touch "$touch_name"
  else
    echo "  [toolchain] Already installed llvm-mingw ${version}, skipping."
  fi
}

# get_toolchain_bin_dir()
# Returns the path to the llvm-mingw bin directory for the current version.
# Used by build.sh to prepend to PATH after the toolchain is installed.
get_toolchain_bin_dir() {
  local version="${LLVM_MINGW_VERSION:?LLVM_MINGW_VERSION not set in versions.conf}"
  echo "${CROSS_COMPILER_DIR}/llvm-mingw-${version}-ucrt-ubuntu-22.04-x86_64/bin"
}
