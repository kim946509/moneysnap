#!/usr/bin/env bash
set -euo pipefail

device_name="${MONEYSNAP_SIMULATOR_DEVICE:-iPhone 16}"
os_version="${MONEYSNAP_SIMULATOR_OS:-18.5}"
runtime_identifier="com.apple.CoreSimulator.SimRuntime.iOS-${os_version//./-}"
inventory_file="$(mktemp)"

cleanup() {
  rm -f "${inventory_file}"
}
trap cleanup EXIT

xcrun simctl list devices available -j > "${inventory_file}"

python3 - "${inventory_file}" "${runtime_identifier}" "${device_name}" <<'PY'
import json
import sys

inventory_path, runtime_identifier, device_name = sys.argv[1:]
with open(inventory_path, encoding="utf-8") as inventory_file:
    inventory = json.load(inventory_file)

devices = inventory.get("devices", {}).get(runtime_identifier, [])
for device in devices:
    if device.get("name") == device_name and device.get("isAvailable", True):
        print(device["udid"])
        raise SystemExit(0)

available_names = ", ".join(device.get("name", "unknown") for device in devices) or "none"
print(
    f"No available {device_name} Simulator was found for {runtime_identifier}. "
    f"Available devices: {available_names}",
    file=sys.stderr,
)
raise SystemExit(1)
PY
