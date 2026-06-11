#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"
flutter build apk --release

echo
echo "Phone APK:"
echo "  $ROOT_DIR/build/app/outputs/apk/release/flashlang-phone-release.apk"
