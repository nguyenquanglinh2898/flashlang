#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR/android"
./gradlew :wear:assembleDebug

echo
echo "Watch debug APK:"
echo "  $ROOT_DIR/build/wear/outputs/apk/debug/flashlang-watch-debug.apk"
