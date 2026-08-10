#!/bin/sh
set -eu

REPOSITORY_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/../.." && pwd)}"
PROJECT_PATH="$REPOSITORY_ROOT/ios/MoneySnap.xcodeproj"

if [ ! -d "$PROJECT_PATH" ]; then
  echo "MoneySnap.xcodeproj is missing at $PROJECT_PATH" >&2
  exit 1
fi

xcodebuild -version
xcodebuild -list -project "$PROJECT_PATH"

echo "Money Snap Xcode Cloud post-clone validation: OK"
