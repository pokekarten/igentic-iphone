#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
sim_id="${1:?Pass the UUID of an available iOS simulator}"
output=$(mktemp -d)
echo "Results: $output"
link=$(node plugin/scripts/acceptance-client.mjs prepare)
xcodegen generate
TEST_RUNNER_FIELDGLASS_LINK="$link" xcodebuild -scheme Fieldglass -destination "platform=iOS Simulator,id=$sim_id" -parallel-testing-enabled NO -skip-testing:FieldglassUITests/WorkbenchDriver -skip-testing:FieldglassUITests/SimulatorSystemTests -derivedDataPath "${FIELDGLASS_DERIVED_DATA:-$output/build}" -resultBundlePath "$output/test.xcresult" test
xcrun xcresulttool export attachments --path "$output/test.xcresult" --output-path "$output/receipts" --filter 'fieldglass-*'
python3 - "$output/receipts" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
for case in json.loads((root/'manifest.json').read_text()):
    for item in case['attachments']:
        for name in ('before','after'):
            if item.get('suggestedHumanReadableName','').startswith('fieldglass-'+name+'_'):
                (root/(name+'.json')).write_bytes((root/item['exportedFileName']).read_bytes())
PY
node plugin/scripts/acceptance-client.mjs compare "$link" "$output/receipts/before.json" "$output/receipts/after.json"
FIELDGLASS_SMOKE_TARGET="$sim_id" node plugin/scripts/acceptance-client.mjs submit
