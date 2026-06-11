#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERIAL="${1:-}"

bash "$ROOT_DIR/scripts/install_watch_debug.sh" "$SERIAL"

echo
echo "Watch app is installed and launched."
echo "Use this instead of flutter run for the watch."
