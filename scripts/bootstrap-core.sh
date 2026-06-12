#!/bin/bash
set -euo pipefail

UPSTREAM="${1:-../sing-box-for-apple}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/Vendor"
BUILD="$ROOT/.build/core-frameworks"

if [[ ! -d "$UPSTREAM" ]]; then
  echo "Usage: $0 /path/to/sing-box-for-apple" >&2
  exit 1
fi

if [[ ! -d "$UPSTREAM/Libbox.xcframework" ]]; then
  echo "Libbox.xcframework is missing in the upstream checkout." >&2
  echo "Build the Apple libbox framework using the upstream sing-box-for-apple development setup first." >&2
  exit 1
fi

rm -rf "$VENDOR/Libbox.xcframework" "$VENDOR/Library.framework" "$BUILD"
mkdir -p "$VENDOR" "$BUILD"
cp -R "$UPSTREAM/Libbox.xcframework" "$VENDOR/Libbox.xcframework"

xcodebuild \
  -project "$UPSTREAM/sing-box.xcodeproj" \
  -target Library \
  -configuration Release \
  -sdk macosx \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  CONFIGURATION_BUILD_DIR="$BUILD"

cp -R "$BUILD/Library.framework" "$VENDOR/Library.framework"

if command -v xcodegen >/dev/null 2>&1; then
  cd "$ROOT"
  xcodegen generate
else
  echo "Core frameworks installed. Install XcodeGen and run: xcodegen generate"
fi
