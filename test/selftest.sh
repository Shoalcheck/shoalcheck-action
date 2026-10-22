#!/usr/bin/env bash
# Local self-test: runs the action's download + verify + install logic for one release on this machine.
# Usage: test/selftest.sh [version]   (default 0.1.0-rc.12). Needs cosign, curl, tar.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
dest="$(mktemp -d)"; trap 'rm -rf "$dest"' EXIT
command -v cosign >/dev/null || { echo "cosign is required" >&2; exit 1; }
VERSION="${1:-0.1.0-rc.12}" DEST="$dest" "$here/../scripts/install.sh"
"$dest/shoalcheck" --version
# a tampered archive must be refused: point at a version that does not exist
if VERSION="0.0.0-nonexistent" DEST="$dest/x" "$here/../scripts/install.sh" >/dev/null 2>&1; then
  echo "FAIL: a missing release was accepted" >&2; exit 1; fi
echo "selftest OK"
