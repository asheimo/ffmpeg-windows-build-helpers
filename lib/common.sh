#!/usr/bin/env bash
# common.sh — shared helper functions
# Sourced by build.sh and all lib/*.sh files.
# Do NOT run this script directly.

# Guard against being sourced more than once
[[ -n "${COMMON_SH_LOADED:-}" ]] && return
COMMON_SH_LOADED=1