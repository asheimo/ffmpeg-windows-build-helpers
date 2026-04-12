#!/usr/bin/env bash
# harfbuzz.sh — builds HarfBuzz, a text shaping library.
# Required by: libass (complex script rendering)
# Requires: freetype (first pass, without harfbuzz)
# https://github.com/harfbuzz/harfbuzz
#
# HarfBuzz uses CMake. After this builds successfully, freetype should be
# rebuilt with --with-harfbuzz to enable OpenType layout support. However
# for our use case (subtitle rendering), the first-pass freetype is sufficient.

# Guard against being sourced more than once
[[ -n "${HARFBUZZ_SH_LOADED:-}" ]] && return
HARFBUZZ_SH_LOADED=1

# build_harfbuzz()
# Clones or updates HarfBuzz and builds the static library.
# Version is controlled by HARFBUZZ_VERSION in versions.conf.
# Skips any step that has already completed successfully.
build_harfbuzz() {
  local version="${HARFBUZZ_VERSION:?HARFBUZZ_VERSION not set in versions.conf}"
  local folder="harfbuzz"

  do_git_checkout \
    "https://github.com/harfbuzz/harfbuzz.git" \
    "$folder" \
    "$version"

  (
    cd "$folder"
    mkdir -p build_static
    (
      cd build_static
      do_cmake .. \
        "-DBUILD_SHARED_LIBS=OFF \
         -DHB_HAVE_FREETYPE=ON \
         -DHB_BUILD_TESTS=OFF \
         -DHB_BUILD_UTILS=OFF \
         -DHB_BUILD_SUBSET=OFF \
         -DCMAKE_FIND_ROOT_PATH=${BUILD_PREFIX}"
      do_make_and_make_install
    )
  )
}
