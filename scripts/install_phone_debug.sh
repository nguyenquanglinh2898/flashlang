#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERIAL="${1:-}"
APK_PATH="$ROOT_DIR/build/app/outputs/apk/debug/flashlang-phone-debug.apk"

source "$ROOT_DIR/scripts/_find_adb.sh"

ADB_BIN="$(find_adb || true)"

if [[ -z "$ADB_BIN" ]]; then
  echo "Could not find adb."
  echo "Expected one of:"
  echo "  adb"
  echo "  $HOME/Android/Sdk/platform-tools/adb"
  exit 1
fi

bash "$ROOT_DIR/scripts/build_phone_debug.sh"

if [[ -n "$SERIAL" ]]; then
  "$ADB_BIN" -s "$SERIAL" install -r "$APK_PATH"
else
  "$ADB_BIN" install -r "$APK_PATH"
fi

echo
echo "Installed phone debug APK:"
echo "  $APK_PATH"
