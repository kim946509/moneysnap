#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ios_dir="$(cd "${script_dir}/.." && pwd)"

destination_id="$(bash "${script_dir}/resolve-simulator.sh")"

if [[ -z "${destination_id}" ]]; then
  echo "No fixed iOS Simulator destination was found." >&2
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
  test
