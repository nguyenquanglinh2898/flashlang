#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"
flutter build apk --debug

echo
echo "Phone debug APK:"
echo "  $ROOT_DIR/build/app/outputs/apk/debug/flashlang-phone-debug.apk"
