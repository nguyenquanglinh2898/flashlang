#!/usr/bin/env bash

find_adb() {
  if command -v adb >/dev/null 2>&1; then
    command -v adb
    return 0
  fi

  local candidates=(
    "$HOME/Android/Sdk/platform-tools/adb"
    "${ANDROID_SDK_ROOT:-}/platform-tools/adb"
    "${ANDROID_HOME:-}/platform-tools/adb"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}
