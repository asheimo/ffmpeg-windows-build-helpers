#!/usr/bin/env bash
# x265.sh — builds libx265, an H.265/HEVC encoder library.
# Used by: ffmpeg --enable-libx265
# https://bitbucket.org/multicoreware/x265_git
#
# x265 requires a three-pass build to produce a single combined static library:
#   1. 12-bit depth only (libx265_main12.a)
#   2. 10-bit depth only (libx265_main10.a)
#   3. 8-bit depth as primary, linked with 10-bit and 12-bit (libx265.a)
# The final libx265.a contains all three merged via ar -M.
#
# Note: ENABLE_ASSEMBLY=OFF is required for all passes when cross-compiling
# with clang/llvm-mingw. x265's CMakeLists.txt passes -march=i686 to nasm
# for 32-bit compat objects, which clang-as does not support.
# Assembly is disabled to avoid this; the encoder still functions correctly
# via C fallbacks and clang's own auto-vectorization.

# Guard against being sourced more than once
[[ -n "${X265_SH_LOADED:-}" ]] && return
X265_SH_LOADED=1

# build_x265()
# Clones or updates x265 and performs the three-pass build.
# Version is controlled by X265_VERSION in versions.conf.
# Skips any step that has already completed successfully.
build_x265() {
  local version="${X265_VERSION:?X265_VERSION not set in versions.conf}"
  local folder="x265"

  do_git_checkout \
    "https://bitbucket.org/multicoreware/x265_git" \
    "$folder" \
    "$version"

  (
    cd "$folder"

    mkdir -p 12bit 10bit 8bit

    # Pass 1: 12-bit library (no CLI, no public C API — linked into 8-bit later)
    (
      cd 12bit
      do_cmake ../source \
        "-DENABLE_SHARED=0 \
         -DENABLE_CLI=0 \
         -DENABLE_ASSEMBLY=OFF \
         -DHIGH_BIT_DEPTH=1 \
         -DMAIN12=1 \
         -DEXPORT_C_API=0"
      do_make
    )
    cp 12bit/libx265.a 8bit/libx265_main12.a

    # Pass 2: 10-bit library (no CLI, no public C API — linked into 8-bit later)
    (
      cd 10bit
      do_cmake ../source \
        "-DENABLE_SHARED=0 \
         -DENABLE_CLI=0 \
         -DENABLE_ASSEMBLY=OFF \
         -DHIGH_BIT_DEPTH=1 \
         -DENABLE_HDR10_PLUS=1 \
         -DEXPORT_C_API=0"
      do_make
    )
    cp 10bit/libx265.a 8bit/libx265_main10.a

    # Pass 3: 8-bit primary build with 10-bit and 12-bit linked in
    (
      cd 8bit
      local extra_libs
      extra_libs="$(pwd)/libx265_main10.a;$(pwd)/libx265_main12.a"
      do_cmake ../source \
        "-DENABLE_SHARED=0 \
         -DENABLE_CLI=0 \
         -DENABLE_ASSEMBLY=OFF \
         -DEXTRA_LINK_FLAGS=-L. \
         -DLINKED_10BIT=1 \
         -DLINKED_12BIT=1 \
         -DEXTRA_LIB=${extra_libs}"
      do_make

      # Merge all three static libs into one combined libx265.a.
      # Touchfile keyed on version so this is skipped on reruns.
      local ar_touch
      ar_touch="$(get_touchfile_name "already_ar_merged_x265_${version}")"
      mkdir -p "$(dirname "$ar_touch")"

      if [[ ! -f "$ar_touch" ]]; then
        # mv is idempotent: only rename if the original name still exists
        [[ -f libx265.a ]] && mv libx265.a libx265_main.a
        echo "  [ar] Merging 8-bit, 10-bit, and 12-bit into libx265.a..."
        "${CROSS_PREFIX}ar" -M << EOF
CREATE libx265.a
ADDLIB libx265_main.a
ADDLIB libx265_main10.a
ADDLIB libx265_main12.a
SAVE
END
EOF
        touch "$ar_touch"
      else
        echo "  [ar] Already merged, skipping."
      fi

      do_make_install

      # x265.pc lists -lgcc_s -lgcc in Libs.private, which causes ffmpeg to
      # link against the shared GCC runtime. Remove them so the static runtime
      # is used instead.
      sed -i 's/-lgcc_s -lgcc//g' "${BUILD_PREFIX}/lib/pkgconfig/x265.pc"
    )
  )
}
