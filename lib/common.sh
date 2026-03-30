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
  local touch_name
  touch_name="$(get_touchfile_name "already_installed_$(pwd)")"

  mkdir -p "$(dirname "$touch_name")"

  if [[ ! -f "$touch_name" ]]; then
    echo "  [make] Installing..."
    # shellcheck disable=SC2086 — intentionally unquoted, flags must be separate arguments
    make install $extra_make_install_options
    touch "$touch_name"   # only reached if make install succeeded
  else
    echo "  [make] Already installed, skipping."
  fi
}

# Convenience wrapper — builds then installs in one call.
# Usage: do_make_and_make_install [extra_options]
do_make_and_make_install() {
  local extra_options="${1:-}"
  do_make "$extra_options"
  do_make_install "$extra_options"
}

# Checks that all required tools are installed before starting the build.
# Exits with a clear error message if anything is missing.
check_prerequisites() {
  local missing=()
  local tools=(
    "make"
    "curl"
    "git"
    "tar"
    "unzip"
    "nproc"
    "pkg-config"
    "${CROSS_PREFIX}gcc"
    "${CROSS_PREFIX}g++"
    "${CROSS_PREFIX}ar"
    "${CROSS_PREFIX}ranlib"
  )

  for tool in "${tools[@]}"; do
    if ! command -v "$tool" &>/dev/null; then  # command -v checks if a tool exists in PATH
      missing+=("$tool")                        # += appends to the array
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Error: the following required tools are missing:"
    for tool in "${missing[@]}"; do
      echo "  - $tool"
    done
    echo ""
    echo "On Ubuntu/WSL, install missing tools with:"
    echo "  sudo apt install -y ${missing[*]}"
    exit 1
  fi

  echo "  [prereqs] All prerequisites found."
}

# Prints a visible section header to the terminal.
# Usage: log_header "zlib 1.3.1"
log_header() {
  local name="$1"
  echo ""
  echo "========================================"
  echo "  Building: $name"
  echo "========================================"
  echo ""
}

# Writes a single line to the summary log with timestamp and status.
# Usage: log_summary "zlib" "SUCCESS"
log_summary() {
  local name="$1"
  local status="$2"
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  local summary_file="$SCRIPT_DIR/logs/summary/build-${BUILD_TIMESTAMP}.log"

  mkdir -p "$(dirname "$summary_file")"
  printf "[%s] %-20s %s\n" "$timestamp" "$name" "$status" >> "$summary_file"
}

# Wraps a library build function with logging and error handling.
# Captures all output to a per-library log file while still showing
# it on the terminal. Records SUCCESS or FAILED in the summary log.
# The build continues even if this library fails.
# Usage: run_library "zlib" build_zlib
run_library() {
  local name="$1"
  local build_fn="$2"
  local lib_log_dir="$SCRIPT_DIR/logs/libraries/$BUILD_TIMESTAMP"
  local lib_log="$lib_log_dir/${name}.log"

  mkdir -p "$lib_log_dir"
  log_header "$name"

  # tee duplicates output — sends it to both the terminal and the log file.
  # The subshell ( ) isolates any directory changes inside the build function.
  # || true prevents set -e from stopping the script if the build fails.
  if ( "$build_fn" 2>&1 | tee "$lib_log" ); then
    log_summary "$name" "SUCCESS"
  else
    log_summary "$name" "FAILED  (see logs/libraries/$BUILD_TIMESTAMP/${name}.log)"
    echo ""
    echo "  *** $name FAILED — continuing with remaining libraries ***"
    echo ""
  fi
}

