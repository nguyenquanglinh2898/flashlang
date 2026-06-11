#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$ROOT_DIR/scripts/_find_adb.sh"

ADB_BIN="$(find_adb || true)"

if [[ -z "$ADB_BIN" ]]; then
  echo "Could not find adb."
  echo "Expected one of:"
  echo "  adb"
  echo "  $HOME/Android/Sdk/platform-tools/adb"
  exit 1
fi

"$ADB_BIN" devices -l
