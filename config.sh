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