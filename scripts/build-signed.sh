#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-Release}"
SCHEME="${SCHEME:-NV2ray}"
TEAM_ID="${DEVELOPMENT_TEAM:-}"

cd "$ROOT"

if [[ ! -d "Vendor/Library.framework" || ! -d "Vendor/Libbox.xcframework" ]]; then
  echo "Vendor frameworks are missing. Run scripts/bootstrap-core.sh first." >&2
  exit 1
fi

if [[ ! -f "Vendor/core-version.txt" ]]; then
  echo "Vendor/core-version.txt is missing. Re-run scripts/bootstrap-core.sh to record the core revision." >&2
  exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "XcodeGen is required. Install it with: brew install xcodegen" >&2
  exit 1
fi

xcodegen generate

ARGS=(
  -project NV2ray.xcodeproj
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -destination 'platform=macOS'
  -derivedDataPath .build/DerivedData
)

if [[ -n "$TEAM_ID" ]]; then
  ARGS+=(DEVELOPMENT_TEAM="$TEAM_ID")
fi

xcodebuild "${ARGS[@]}" clean build
