#!/usr/bin/env bash
set -euo pipefail

: "${APP_PATH:?APP_PATH must point to the built .app bundle}"

BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-org.example.iGenticDiagnostics}"
SCREENSHOT_PATH="${SCREENSHOT_PATH:-${RUNNER_TEMP:-/tmp}/iGenticDiagnostics-launch.png}"

if [[ ! -d "${APP_PATH}" ]]; then
  echo "App bundle not found: ${APP_PATH}" >&2
  exit 1
fi

selector_args=()
if [[ -n "${IOS27_MATCHED_RUNTIME:-}" ]]; then
  selector_args+=(--match-runtime "${IOS27_MATCHED_RUNTIME}")
fi
SIMULATOR_UDID="$(xcrun simctl list devices available -j | python3 "$(dirname "${BASH_SOURCE[0]}")/select_ios27_simulator.py" "${selector_args[@]}")"

cleanup() {
  xcrun simctl terminate "${SIMULATOR_UDID}" "${BUNDLE_IDENTIFIER}" >/dev/null 2>&1 || true
  xcrun simctl shutdown "${SIMULATOR_UDID}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

xcrun simctl boot "${SIMULATOR_UDID}" 2>/dev/null || true
xcrun simctl bootstatus "${SIMULATOR_UDID}" -b
xcrun simctl install "${SIMULATOR_UDID}" "${APP_PATH}"

launch_and_verify() {
  local launch_output
  local pid

  launch_output="$(xcrun simctl launch "${SIMULATOR_UDID}" "${BUNDLE_IDENTIFIER}")"
  echo "${launch_output}"
  pid="$(printf '%s\n' "${launch_output}" | awk '{print $NF}')"

  if [[ ! "${pid}" =~ ^[0-9]+$ ]]; then
    echo "Simulator launch did not return a process identifier" >&2
    exit 1
  fi

  sleep 3
  xcrun simctl terminate "${SIMULATOR_UDID}" "${BUNDLE_IDENTIFIER}"
}

# First launch proves installation and startup. Capture a screenshot while the app is active.
first_launch_output="$(xcrun simctl launch "${SIMULATOR_UDID}" "${BUNDLE_IDENTIFIER}")"
echo "${first_launch_output}"
first_pid="$(printf '%s\n' "${first_launch_output}" | awk '{print $NF}')"
if [[ ! "${first_pid}" =~ ^[0-9]+$ ]]; then
  echo "First simulator launch did not return a process identifier" >&2
  exit 1
fi

sleep 3
xcrun simctl io "${SIMULATOR_UDID}" screenshot "${SCREENSHOT_PATH}"
if [[ ! -s "${SCREENSHOT_PATH}" ]]; then
  echo "Simulator screenshot was not created" >&2
  exit 1
fi

screenshot_bytes="$(stat -f '%z' "${SCREENSHOT_PATH}")"
echo "Captured simulator screenshot (${screenshot_bytes} bytes): ${SCREENSHOT_PATH}"
xcrun simctl terminate "${SIMULATOR_UDID}" "${BUNDLE_IDENTIFIER}"

# A second launch verifies a clean relaunch after termination.
launch_and_verify

echo "Simulator install, launch, screenshot, terminate, and relaunch smoke test passed."
