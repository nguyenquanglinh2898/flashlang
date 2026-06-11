#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR/android"
./gradlew :wear:assembleRelease

echo
echo "Watch APK:"
echo "  $ROOT_DIR/build/wear/outputs/apk/release/flashlang-watch-release.apk"
