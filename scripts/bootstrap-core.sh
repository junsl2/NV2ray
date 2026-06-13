#!/bin/bash
set -euo pipefail

EXPECTED_UPSTREAM_COMMIT="${EXPECTED_UPSTREAM_COMMIT:-ff32522661f0f065a09aa41127ad40227be7fb41}"
UPSTREAM="${1:-../sing-box-for-apple}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/Vendor"
BUILD="$ROOT/.build/core-frameworks"

if [[ ! -d "$UPSTREAM" ]]; then
  echo "Usage: $0 /path/to/sing-box-for-apple" >&2
  exit 1
fi

if [[ ! -d "$UPSTREAM/.git" ]]; then
  echo "The upstream path must be a git checkout so the tested revision can be verified." >&2
  exit 1
fi

CURRENT_COMMIT="$(git -C "$UPSTREAM" rev-parse HEAD)"
if [[ "$CURRENT_COMMIT" != "$EXPECTED_UPSTREAM_COMMIT" && "${ALLOW_UNTESTED_CORE:-0}" != "1" ]]; then
  echo "Unsupported sing-box-for-apple revision: $CURRENT_COMMIT" >&2
  echo "Expected: $EXPECTED_UPSTREAM_COMMIT" >&2
  echo "Set ALLOW_UNTESTED_CORE=1 to override explicitly." >&2
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
cat > "$VENDOR/core-version.txt" <<EOF
sing-box-for-apple=$CURRENT_COMMIT
expected=$EXPECTED_UPSTREAM_COMMIT
built_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

if command -v xcodegen >/dev/null 2>&1; then
  cd "$ROOT"
  xcodegen generate
else
  echo "Core frameworks installed. Install XcodeGen and run: xcodegen generate"
fi
