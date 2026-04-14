#!/usr/bin/env bash
# config.sh — your build preferences
# Edit this file to control what gets built.
# Do NOT add logic here — only variable assignments.

# Target architecture: win32, win64, or multi
COMPILER_FLAVOR="win64"

# Include non-free libraries (fdk-aac, decklink)?
# Resulting binary may not be redistributable.
NON_FREE="n"

# Include GPL libraries (x264, x265)?
LICENSE="gpl"

# Optional component switches
BUILD_FFMPEG="y"
BUILD_MP4BOX="n"
BUILD_MPLAYER="n"

# How many previous build log folders to keep under logs/libraries/.
# Older folders beyond this count are deleted at the start of each run.
LOG_RETENTION=5

# Where the llvm-mingw cross-compiler toolchain is installed.
# build.sh prepends this to PATH after the toolchain is downloaded.
CROSS_COMPILER_DIR="$SCRIPT_DIR/cross_compilers"

# Where compiled libraries are installed for the cross-compiler to find them.
BUILD_PREFIX="$SCRIPT_DIR/sandbox/mingw-w64-x86_64"

# Where library sources are cloned/extracted and built.
# Kept separate from the repo root to avoid clutter.
BUILD_DIR="$SCRIPT_DIR/build"

# Prefix for all cross-compiler tools.
# llvm-mingw provides wrappers using the standard mingw-w64 naming convention
# so this value is unchanged from a gcc-based toolchain.
# e.g. ${CROSS_PREFIX}gcc — x86_64-w64-mingw32-gcc (symlinks to clang)
CROSS_PREFIX="x86_64-w64-mingw32-"
