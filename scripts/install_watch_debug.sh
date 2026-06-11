#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERIAL="${1:-}"
APK_PATH="$ROOT_DIR/build/wear/outputs/apk/debug/flashlang-watch-debug.apk"
PACKAGE_NAME="com.example.flash_lang"
ACTIVITY_NAME="com.example.flash_lang.wear.MainActivity"
LEGACY_PACKAGE_NAME="com.example.flash_lang.wear"

source "$ROOT_DIR/scripts/_find_adb.sh"

ADB_BIN="$(find_adb || true)"

if [[ -z "$ADB_BIN" ]]; then
  echo "Could not find adb."
  echo "Expected one of:"
  echo "  adb"
  echo "  $HOME/Android/Sdk/platform-tools/adb"
  exit 1
fi

find_watch_serial() {
  local serial
  local characteristics
  local model
  local manufacturer
  local device_line
  local device_lines=()

  mapfile -t device_lines < <("$ADB_BIN" devices -l | awk 'NR > 1 && $2 == "device" { print $0 }')

  for device_line in "${device_lines[@]}"; do
    serial="$(awk '{print $1}' <<<"$device_line")"
    [[ -z "$serial" ]] && continue

    characteristics="$("$ADB_BIN" -s "$serial" shell getprop ro.build.characteristics 2>/dev/null | tr -d '\r')"
    model="$("$ADB_BIN" -s "$serial" shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
    manufacturer="$("$ADB_BIN" -s "$serial" shell getprop ro.product.manufacturer 2>/dev/null | tr -d '\r')"

    if [[ "$characteristics" == *watch* ]]; then
      printf '%s\n' "$serial"
      return 0
    fi

    if [[ "$device_line" == *"model:sdk_gwear_"* ]] || [[ "$model" == *"Watch"* ]] || [[ "$manufacturer" == *"samsung"* && "$model" == *"SM-R"* ]]; then
      printf '%s\n' "$serial"
      return 0
    fi
  done

  return 1
}

bash "$ROOT_DIR/scripts/build_watch_debug.sh"

if [[ -n "$SERIAL" ]]; then
  "$ADB_BIN" -s "$SERIAL" uninstall "$LEGACY_PACKAGE_NAME" >/dev/null 2>&1 || true
  "$ADB_BIN" -s "$SERIAL" install -r "$APK_PATH"
  "$ADB_BIN" -s "$SERIAL" shell am start -n "$PACKAGE_NAME/$ACTIVITY_NAME"
else
  SERIAL="$(find_watch_serial || true)"
  if [[ -z "$SERIAL" ]]; then
    echo "Could not find a connected Wear OS watch automatically."
    echo "If needed, connect the watch with ADB first, then rerun this command."
    exit 1
  fi

  "$ADB_BIN" -s "$SERIAL" uninstall "$LEGACY_PACKAGE_NAME" >/dev/null 2>&1 || true
  "$ADB_BIN" -s "$SERIAL" install -r "$APK_PATH"
  "$ADB_BIN" -s "$SERIAL" shell am start -n "$PACKAGE_NAME/$ACTIVITY_NAME"
fi

echo
echo "Installed watch debug APK:"
echo "  $APK_PATH"
echo "Target device:"
echo "  $SERIAL"
