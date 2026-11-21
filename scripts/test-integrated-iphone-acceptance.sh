#!/usr/bin/env bash
# Integrated acceptance of PR #380 with the stacked proposal/model/probe branch.
# All merging and build artifacts stay inside a new temporary clone.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
remote="$(git -C "$root" remote get-url origin)"
work="$(mktemp -d /tmp/igentic-integration.XXXXXXXX)"
cleanup() {
  if [[ -n "$work" && -d "$work" && "$work" == *igentic-integration.* ]]; then
    rm -rf -- "$work"
  fi
}
trap cleanup EXIT

echo 'INTEGRATED_ACCEPTANCE=starting'
git clone -q --single-branch --branch test/opt-in-local-foundation-model-probe-20261121 "$remote" "$work/repo"
cd "$work/repo"
git fetch -q origin feat/read-only-diagnostics-app-intent-20261121
git merge-base HEAD FETCH_HEAD >/dev/null
if ! git -c user.name='iGentic Integration Check' \
  -c user.email='integration-test@localhost' \
  merge --no-edit FETCH_HEAD >"$work/merge.log" 2>&1; then
  echo 'INTEGRATED_MERGE=failed'
  cat "$work/merge.log"
  exit 1
fi
echo 'INTEGRATED_MERGE=success'

cd ios
if ! swift test --jobs 2 --scratch-path "$work/scratch" >"$work/swift-tests.log" 2>&1; then
  echo 'INTEGRATED_SWIFT_TESTS=failed'
  tail -n 25 "$work/swift-tests.log"
  exit 1
fi
echo 'INTEGRATED_SWIFT_TESTS=passed'
grep -E 'Executed [0-9]+ tests, with 0 failures' "$work/swift-tests.log" | tail -n 1 || true

IGENTIC_RUN_LOCAL_MODEL_PROBE=0 swift run --jobs 2 --scratch-path "$work/scratch" AppleOnDeviceProposalProbe >"$work/optout.log" 2>&1
grep -q '^LOCAL_MODEL_PROBE=skipped (explicit opt-in required)$' "$work/optout.log"
echo 'INTEGRATED_DEFAULT_MODEL_INFERENCE=skipped'

if [[ "${IGENTIC_RUN_LOCAL_MODEL_PROBE:-0}" == "1" ]]; then
  if ! IGENTIC_RUN_LOCAL_MODEL_PROBE=1 swift run --jobs 2 \
    --scratch-path "$work/scratch" AppleOnDeviceProposalProbe >"$work/optin.log" 2>&1; then
    echo 'INTEGRATED_LOCAL_MODEL_PROBE=failed'
    tail -n 15 "$work/optin.log"
    exit 1
  fi
  echo 'INTEGRATED_LOCAL_MODEL_PROBE=completed'
  grep '^LOCAL_MODEL_' "$work/optin.log" || true
fi

if [[ "${IGENTIC_RUN_SIGNED_SIMULATOR_TEST:-0}" == "1" ]]; then
  command -v xcodebuild >/dev/null
  command -v xcrun >/dev/null
  # On a fresh install, AppIntents metadata may not yet be registered.
  # Build/sign first, install and launch the actual app once, then dispatch
  # the system test. Do not turn off code signing for AppIntentsTesting.
  xcode_args=(
    -project ../app/iGenticDiagnostics/iGenticDiagnostics.xcodeproj
    -scheme iGenticDiagnostics -configuration Debug
    -destination "${IGENTIC_SIMULATOR_DESTINATION:-platform=iOS Simulator,name=iPhone Air,OS=27.2}"
    -derivedDataPath "$work/derived"
    -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1
    -only-testing:iGenticDiagnosticsUITests/iGenticAppIntentsTests
  )
  if ! xcodebuild "${xcode_args[@]}" build-for-testing >"$work/ios-build-for-testing.log" 2>&1; then
    echo 'INTEGRATED_SIGNED_APPINTENTS_BUILD=failed'
    tail -n 25 "$work/ios-build-for-testing.log"
    exit 1
  fi
  app_path="$work/derived/Build/Products/Debug-iphonesimulator/iGenticDiagnostics.app"
  if ! xcrun simctl install booted "$app_path"; then
    echo 'INTEGRATED_APP_INSTALL=failed'
    exit 1
  fi
  echo 'INTEGRATED_APP_INSTALL=passed'
  if ! xcrun simctl launch booted org.example.iGenticDiagnostics; then
    echo 'INTEGRATED_APP_LAUNCH=failed'
    exit 1
  fi
  echo 'INTEGRATED_APP_LAUNCH=passed'
  xcrun simctl terminate booted org.example.iGenticDiagnostics >/dev/null 2>&1 || true
  # Give App Intents' asynchronous metadata registration a short window.
  sleep 2
  if ! xcodebuild "${xcode_args[@]}" test-without-building >"$work/ios-system-test.log" 2>&1; then
    echo 'INTEGRATED_SIGNED_APPINTENTS_TEST=failed'
    grep -E 'error:|Testing failed:|Test crashed|\*\* TEST' "$work/ios-system-test.log" | tail -n 12 || true
    exit 1
  fi
  if ! grep -Eq '\*\* TEST( EXECUTE)? SUCCEEDED \*\*' "$work/ios-system-test.log" || \
     ! grep -q 'testReadOnlyDiagnosticsIntentRunsThroughSystem.*passed' "$work/ios-system-test.log"; then
    echo 'INTEGRATED_SIGNED_APPINTENTS_TEST=no-success-marker'
    tail -n 28 "$work/ios-system-test.log"
    exit 1
  fi
  echo 'INTEGRATED_SIGNED_APPINTENTS_TEST=passed'
fi
echo 'INTEGRATED_ACCEPTANCE=passed'
