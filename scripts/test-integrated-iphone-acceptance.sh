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
  if ! xcodebuild -project ../app/iGenticDiagnostics/iGenticDiagnostics.xcodeproj \
    -scheme iGenticDiagnostics -configuration Debug \
    -destination "${IGENTIC_SIMULATOR_DESTINATION:-platform=iOS Simulator,name=iPhone Air,OS=27.2}" \
    -derivedDataPath "$work/derived" \
    -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 \
    -only-testing:iGenticDiagnosticsUITests/iGenticAppIntentsTests \
    test >"$work/ios-system-test.log" 2>&1; then
    echo 'INTEGRATED_SIGNED_APPINTENTS_TEST=failed'
    tail -n 30 "$work/ios-system-test.log"
    exit 1
  fi
  grep -q '\*\* TEST SUCCEEDED \*\*' "$work/ios-system-test.log"
  echo 'INTEGRATED_SIGNED_APPINTENTS_TEST=passed'
fi
echo 'INTEGRATED_ACCEPTANCE=passed'
