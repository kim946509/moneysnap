#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ios_dir="$(cd "${script_dir}/.." && pwd)"
output_dir="${VISUAL_OUTPUT_DIR:-${ios_dir}/build/visual-evidence}"
reference_path="${ios_dir}/VisualReferences/Figma/home-9-2-393x852.png"
manifest_path="${ios_dir}/VisualReferences/manifest.json"
bundle_identifier="com.ansandy.moneysnap"
viewport_width=393
viewport_height=852
destination_id="$(bash "${script_dir}/resolve-simulator.sh")"
derived_data="$(mktemp -d)"
raw_screenshot="${output_dir}/app-native.png"
app_screenshot="${output_dir}/app-393x852.png"
maximum_mean_absolute_error="$(plutil -extract comparison.maximumMeanAbsoluteError raw -o - "${manifest_path}")"
maximum_mismatched_pixel_ratio="$(plutil -extract comparison.maximumMismatchedPixelRatio raw -o - "${manifest_path}")"

cleanup() {
  xcrun simctl shutdown "${destination_id}" >/dev/null 2>&1 || true
  rm -rf "${derived_data}"
}
trap cleanup EXIT

mkdir -p "${output_dir}"
cp "${reference_path}" "${output_dir}/figma-home-9-2-393x852.png"

xcrun simctl boot "${destination_id}" >/dev/null 2>&1 || true
xcrun simctl bootstatus "${destination_id}" -b

xcodebuild \
  -project "${ios_dir}/MoneySnap.xcodeproj" \
  -scheme MoneySnap \
  -configuration Debug \
  -destination "id=${destination_id}" \
  -derivedDataPath "${derived_data}" \
  CODE_SIGNING_ALLOWED=NO \
  build

app_path="${derived_data}/Build/Products/Debug-iphonesimulator/MoneySnap.app"
if [[ ! -d "${app_path}" ]]; then
  echo "Built Simulator app was not found at ${app_path}." >&2
  exit 1
fi

xcrun simctl install "${destination_id}" "${app_path}"
xcrun simctl status_bar "${destination_id}" override \
  --time "9:41" \
  --dataNetwork wifi \
  --wifiMode active \
  --wifiBars 3 \
  --cellularMode active \
  --cellularBars 4 \
  --batteryState charged \
  --batteryLevel 100 >/dev/null 2>&1 || true
xcrun simctl launch --terminate-running-process "${destination_id}" "${bundle_identifier}"
sleep 2
xcrun simctl io "${destination_id}" screenshot --type=png "${raw_screenshot}"

sips -z "${viewport_height}" "${viewport_width}" "${raw_screenshot}" --out "${app_screenshot}" >/dev/null
pixel_width="$(sips -g pixelWidth "${app_screenshot}" | awk '/pixelWidth/ {print $2}')"
pixel_height="$(sips -g pixelHeight "${app_screenshot}" | awk '/pixelHeight/ {print $2}')"
if [[ "${pixel_width}" != "${viewport_width}" || "${pixel_height}" != "${viewport_height}" ]]; then
  echo "Captured app screenshot must be ${viewport_width}x${viewport_height}, got ${pixel_width}x${pixel_height}." >&2
  exit 1
fi

xcrun swift "${script_dir}/visual-diff.swift" \
  --reference "${reference_path}" \
  --actual "${app_screenshot}" \
  --output-dir "${output_dir}" \
  --maximum-mean-absolute-error "${maximum_mean_absolute_error}" \
  --maximum-mismatched-pixel-ratio "${maximum_mismatched_pixel_ratio}"

{
  xcodebuild -version
  echo "Simulator device: ${MONEYSNAP_SIMULATOR_DEVICE:-iPhone 16}"
  echo "Simulator OS: ${MONEYSNAP_SIMULATOR_OS:-18.5}"
  echo "Simulator UDID: ${destination_id}"
  echo "Viewport: ${viewport_width}x${viewport_height}"
  echo "Comparison mode: threshold"
  echo "Maximum mean absolute error: ${maximum_mean_absolute_error}"
  echo "Maximum mismatched pixel ratio: ${maximum_mismatched_pixel_ratio}"
} > "${output_dir}/environment.txt"
