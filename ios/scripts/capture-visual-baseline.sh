#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ios_dir="$(cd "${script_dir}/.." && pwd)"
output_dir="${VISUAL_OUTPUT_DIR:-${ios_dir}/build/visual-evidence}"
manifest_path="${ios_dir}/VisualReferences/manifest.json"
bundle_identifier="com.ansandy.moneysnap"
viewport_width=393
viewport_height=852
destination_id="$(bash "${script_dir}/resolve-simulator.sh")"
derived_data="$(mktemp -d)"
maximum_mean_absolute_error="$(plutil -extract comparison.maximumMeanAbsoluteError raw -o - "${manifest_path}")"
maximum_mismatched_pixel_ratio="$(plutil -extract comparison.maximumMismatchedPixelRatio raw -o - "${manifest_path}")"
visual_scenarios=()
visual_failures=()

while IFS= read -r visual_scenario || [[ -n "${visual_scenario}" ]]; do
  if [[ -n "${visual_scenario}" ]]; then
    visual_scenarios+=("${visual_scenario}")
  fi
done < <(
  plutil -extract scenarios json -o - "${manifest_path}" \
    | tr -d '[]" ' \
    | tr ',' '\n'
)

if [[ "${#visual_scenarios[@]}" -eq 0 ]]; then
  echo "Visual manifest contains no scenarios." >&2
  exit 1
fi

cleanup() {
  xcrun simctl shutdown "${destination_id}" >/dev/null 2>&1 || true
  rm -rf "${derived_data}"
}
trap cleanup EXIT

mkdir -p "${output_dir}"

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

capture_scenario() {
  local visual_scenario="$1"
  local scenario_output_dir="${output_dir}/${visual_scenario}"
  local reference_relative_path
  local reference_path
  local figma_node_id
  local source_reference_sha256
  local raw_screenshot="${scenario_output_dir}/app-native.png"
  local app_screenshot="${scenario_output_dir}/app-393x852.png"
  local pixel_width
  local pixel_height
  local visual_diff_crop_arguments=()
  local crop_x
  local crop_y
  local crop_width
  local crop_height

  reference_relative_path="$(plutil -extract "figma.screens.${visual_scenario}.reference" raw -o - "${manifest_path}")" || return 1
  figma_node_id="$(plutil -extract "figma.screens.${visual_scenario}.nodeId" raw -o - "${manifest_path}")" || return 1
  source_reference_sha256="$(plutil -extract "figma.screens.${visual_scenario}.sha256" raw -o - "${manifest_path}")" || return 1
  reference_path="${ios_dir}/${reference_relative_path}"
  mkdir -p "${scenario_output_dir}"
  cp "${reference_path}" "${scenario_output_dir}/figma-${visual_scenario}-reference.png" || return 1

  SIMCTL_CHILD_MONEYSNAP_VISUAL_SCENARIO="${visual_scenario}" \
    xcrun simctl launch --terminate-running-process "${destination_id}" "${bundle_identifier}" || return 1
  sleep 2
  xcrun simctl io "${destination_id}" screenshot --type=png "${raw_screenshot}" || return 1

  sips -z "${viewport_height}" "${viewport_width}" "${raw_screenshot}" --out "${app_screenshot}" >/dev/null || return 1
  pixel_width="$(sips -g pixelWidth "${app_screenshot}" | awk '/pixelWidth/ {print $2}')"
  pixel_height="$(sips -g pixelHeight "${app_screenshot}" | awk '/pixelHeight/ {print $2}')"
  if [[ "${pixel_width}" != "${viewport_width}" || "${pixel_height}" != "${viewport_height}" ]]; then
    echo "Captured app screenshot must be ${viewport_width}x${viewport_height}, got ${pixel_width}x${pixel_height}." >&2
    return 1
  fi

  {
    xcodebuild -version
    echo "Simulator device: ${MONEYSNAP_SIMULATOR_DEVICE:-iPhone 16}"
    echo "Simulator OS: ${MONEYSNAP_SIMULATOR_OS:-18.5}"
    echo "Simulator UDID: ${destination_id}"
    echo "Viewport: ${viewport_width}x${viewport_height}"
    echo "Visual scenario: ${visual_scenario}"
    echo "Figma node ID: ${figma_node_id}"
    echo "Source reference SHA-256: ${source_reference_sha256}"
    echo "Comparison mode: threshold"
    echo "Maximum mean absolute error: ${maximum_mean_absolute_error}"
    echo "Maximum mismatched pixel ratio: ${maximum_mismatched_pixel_ratio}"
  } > "${scenario_output_dir}/environment.txt"

  if crop_x="$(plutil -extract "figma.screens.${visual_scenario}.comparisonCrop.x" raw -o - "${manifest_path}" 2>/dev/null)"; then
    crop_y="$(plutil -extract "figma.screens.${visual_scenario}.comparisonCrop.y" raw -o - "${manifest_path}")" || return 1
    crop_width="$(plutil -extract "figma.screens.${visual_scenario}.comparisonCrop.width" raw -o - "${manifest_path}")" || return 1
    crop_height="$(plutil -extract "figma.screens.${visual_scenario}.comparisonCrop.height" raw -o - "${manifest_path}")" || return 1
    visual_diff_crop_arguments=(
      --crop-x "${crop_x}"
      --crop-y "${crop_y}"
      --crop-width "${crop_width}"
      --crop-height "${crop_height}"
    )
    echo "Comparison crop: x=${crop_x}, y=${crop_y}, width=${crop_width}, height=${crop_height}" \
      >> "${scenario_output_dir}/environment.txt"
  fi

  xcrun swift "${script_dir}/visual-diff.swift" \
    --reference "${reference_path}" \
    --actual "${app_screenshot}" \
    --output-dir "${scenario_output_dir}" \
    --scenario "${visual_scenario}" \
    --figma-node-id "${figma_node_id}" \
    --source-reference-sha256 "${source_reference_sha256}" \
    --maximum-mean-absolute-error "${maximum_mean_absolute_error}" \
    --maximum-mismatched-pixel-ratio "${maximum_mismatched_pixel_ratio}" \
    "${visual_diff_crop_arguments[@]}"
}

for visual_scenario in "${visual_scenarios[@]}"; do
  if ! capture_scenario "${visual_scenario}"; then
    visual_failures+=("${visual_scenario}")
  fi
done

if [[ "${#visual_failures[@]}" -gt 0 ]]; then
  echo "Visual scenarios failed: ${visual_failures[*]}" >&2
  exit 1
fi
