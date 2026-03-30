#!/usr/bin/env bash
# common.sh — shared helper functions
# Sourced by build.sh and all lib/*.sh files.
# Do NOT run this script directly.

# Guard against being sourced more than once
[[ -n "${COMMON_SH_LOADED:-}" ]] && return
COMMON_SH_LOADED=1

# Returns the path to a touchfile for a given step name.
# Touchfiles are empty files that record a build step completed successfully.
# Usage: touch "$(get_touchfile_name zlib_configure)"
get_touchfile_name() {
  local name="$1"
  echo "$SCRIPT_DIR/logs/touched/$name"
}

# Clones a git repo or fetches updates if it already exists,
# then checks out the specified branch, tag, or commit.
# Usage: do_git_checkout <url> [folder_name] [branch/tag/commit]
do_git_checkout() {
  local url="$1"
  local name="${2:-$(basename "$url" .git)}" # derive folder name from URL if not provided
  local branch="${3:-}"                       # empty string fallback required by set -u

  if [[ ! -d "$name" ]]; then
    echo "  [git] Cloning $name..."
    git clone "$url" "$name"
  else
    echo "  [git] Fetching updates for $name..."
    ( cd "$name" && git fetch ) # subshell avoids pushd/popd — auto-returns on failure
  fi

  if [[ -n "$branch" ]]; then
    echo "  [git] Checking out $branch..."
    ( cd "$name" && git checkout "$branch" -- ) # -- prevents ambiguity between branch and filename
  fi
}

# Downloads a tarball or zip archive and extracts it.
# Skips download if the archive already exists locally.
# Skips extraction if the destination directory already exists.
# Usage: download_and_unpack_file <url> [output_filename] [extract_dir]
download_and_unpack_file() {
  local url="$1"
  local output_name="${2:-$(basename "$url")}"        # derive filename from URL if not provided
  local archive_dir="${3:-${output_name%.tar.*}}"     # strip .tar.gz / .tar.xz / .tar.bz2 etc.
  archive_dir="${archive_dir%.zip}"                   # strip .zip if present
  local downloads_dir="$SCRIPT_DIR/downloads"

  mkdir -p "$downloads_dir"

  if [[ ! -f "$downloads_dir/$output_name" ]]; then
    echo "  [download] Downloading $output_name..."
    curl "$url" -L --retry 5 -o "$downloads_dir/$output_name" -C - # -L follow redirects, -C - resume partial
  else
    echo "  [download] Already have $output_name, skipping."
  fi

  if [[ -d "$archive_dir" ]]; then
    echo "  [download] Already unpacked $archive_dir, skipping."
    return
  fi

  echo "  [download] Unpacking $output_name..."
  tar -xf "$downloads_dir/$output_name" || unzip "$downloads_dir/$output_name"
}

# Runs ./configure with the given options, skipping if already done.
# Uses a touchfile to track whether configuration succeeded.
# Usage: do_configure [options] [configure_script_name]
do_configure() {
  local configure_options="${1:-}"
  local configure_name="${2:-./configure}"
  local touch_name
  touch_name="$(get_touchfile_name "already_configured_${configure_name}")"

  mkdir -p "$(dirname "$touch_name")"

  if [[ ! -f "$touch_name" ]]; then
    echo "  [configure] Running $configure_name..."
    # shellcheck disable=SC2086 — intentionally unquoted, flags must be separate arguments
    "$configure_name" $configure_options
    touch "$touch_name"
  else
    echo "  [configure] Already configured, skipping."
  fi
}

# Runs make with parallel jobs based on available CPU cores.
# Skips if already completed successfully.
# Usage: do_make [extra_make_options]
do_make() {
  local extra_make_options="${1:-}"
  local cpu_count
  cpu_count="$(nproc)"                                # nproc prints available CPU core count
  local touch_name
  touch_name="$(get_touchfile_name "already_made_$(pwd)")"

  mkdir -p "$(dirname "$touch_name")"

  if [[ ! -f "$touch_name" ]]; then
    echo "  [make] Building with $cpu_count jobs..."
    # shellcheck disable=SC2086 — intentionally unquoted, flags must be separate arguments
    make -j"$cpu_count" $extra_make_options
    touch "$touch_name"
  else
    echo "  [make] Already built, skipping."
  fi
}

# Runs make install to copy compiled files into the system prefix.
# Usage: do_make_install [extra_options]
do_make_install() {
  local extra_make_install_options="${1:-}"

  echo "  [make] Installing..."
  # shellcheck disable=SC2086 — intentionally unquoted, flags must be separate arguments
  make install $extra_make_install_options
}

# Convenience wrapper — builds then installs in one call.
# Usage: do_make_and_make_install [extra_options]
do_make_and_make_install() {
  local extra_options="${1:-}"
  do_make "$extra_options"
  do_make_install "$extra_options"
}