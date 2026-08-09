#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ios_dir="$(cd "${script_dir}/.." && pwd)"

destination_id="$({
  xcodebuild \
    -project "${ios_dir}/MoneySnap.xcodeproj" \
    -scheme MoneySnap \
    -showdestinations
} | grep "platform:iOS Simulator" | grep -v "Any iOS Simulator Device" | sed -n 's/.*id:\([^,}]*\).*/\1/p' | head -n 1 | xargs)"

if [[ -z "${destination_id}" ]]; then
  echo "No available iOS Simulator destination was found." >&2
  exit 1
fi

result_bundle_arguments=()
if [[ -n "${RESULT_BUNDLE_PATH:-}" ]]; then
  result_bundle_arguments=(-resultBundlePath "${RESULT_BUNDLE_PATH}")
fi

xcodebuild \
  -project "${ios_dir}/MoneySnap.xcodeproj" \
  -scheme MoneySnap \
  -destination "id=${destination_id}" \
  "${result_bundle_arguments[@]}" \
  CODE_SIGNING_ALLOWED=NO \
  test
