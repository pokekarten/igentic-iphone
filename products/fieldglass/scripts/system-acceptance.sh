#!/bin/bash
set -euo pipefail
umask 077
cd "$(dirname "$0")/.."
output=$(mktemp -d)
build_dir=${FIELDGLASS_DERIVED_DATA:-$output/build}
sim_id="${1:-}"
created=0

if [[ -z "$sim_id" ]]; then
    model=${2:-com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro}
    runtime=${3:-com.apple.CoreSimulator.SimRuntime.iOS-27-2}
    sim_id=$(xcrun simctl create "Fieldglass $(basename "$output")" "$model" "$runtime")
    created=1
fi

cleanup() {
    if [[ "$created" == 1 ]]; then
        xcrun simctl shutdown "$sim_id" >/dev/null 2>&1 || true
        xcrun simctl delete "$sim_id" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

destination="platform=iOS Simulator,id=$sim_id"
flags=(-scheme Fieldglass -destination "$destination" -parallel-testing-enabled NO -derivedDataPath "$build_dir")
echo "Test results: $output"
if ! xcrun simctl list devices booted | rg -q "$sim_id"; then xcrun simctl boot "$sim_id"; fi
xcodegen generate
xcodebuild "${flags[@]}" build-for-testing
xcrun simctl bootstatus "$sim_id" -b
xcrun simctl ui "$sim_id" appearance dark
xcrun simctl install "$sim_id" "$build_dir/Build/Products/Debug-iphonesimulator/Fieldglass.app"

container_dir=$(xcrun simctl get_app_container "$sim_id" org.fieldglass.workbench data)
mkdir -p "$container_dir/Documents"
say -v Anna -o "$container_dir/Documents/Fieldglass-Probe.aiff" 'Der Komet leuchtet am Himmel.'
swift scripts/simulator-photo.swift "$output/Fieldglass-Komet.png"
xcrun simctl addmedia "$sim_id" "$output/Fieldglass-Komet.png"

TEST_RUNNER_FIELDGLASS_SYSTEM_FIXTURES=1 xcodebuild "${flags[@]}" \
    -resultBundlePath "$output/system.xcresult" \
    -only-testing:FieldglassUITests/SimulatorSystemTests \
    -skip-testing:FieldglassUITests/SimulatorSystemTests/testReminderPermissionDenied test-without-building

xcrun simctl privacy "$sim_id" revoke reminders org.fieldglass.workbench
TEST_RUNNER_FIELDGLASS_SYSTEM_FIXTURES=1 xcodebuild "${flags[@]}" \
    -resultBundlePath "$output/denied.xcresult" \
    -only-testing:FieldglassUITests/SimulatorSystemTests/testReminderPermissionDenied test-without-building
