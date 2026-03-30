#!/usr/bin/env bash
# build.sh — main entry point
# Usage: ./build.sh [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/versions.conf"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/lib/common.sh"

echo "ffmpeg-build: starting"
echo "  Target:   $COMPILER_FLAVOR"
echo "  Non-free: $NON_FREE"
echo "  License:  $LICENSE"
```

Two things worth understanding here:

**`SCRIPT_DIR`** — This resolves the directory where `build.sh` lives, regardless of where you call it from. Without this, running `./build.sh` from a different directory would cause all the relative `source` paths to break.

**`"${BASH_SOURCE[0]}"`** — This is the correct way to get the current script's path in Bash. `$0` looks similar but behaves differently when a script is sourced rather than executed.

---

Once you've created all five, commit them with a message like:
```
Add project skeleton (build.sh, config.sh, versions.conf, lib/common.sh)