"""Synthetic regression tests for the consolidated iOS 27 source contract."""
from __future__ import annotations

import json
import shutil
import tempfile
import unittest
from pathlib import Path

from check_ios27_integration_contract import (
    ROOT, PBX, SCHEME, UI_DIR, EXPECTED_TESTS, check_integration,
)


class CombinedIOS27ContractTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="igentic-contract-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        names = [PBX, SCHEME, "ios/Package.swift", "ios/Sources/iGenticPluginPolicy/main.swift"]
        names += [f"{UI_DIR}/{n}" for n in EXPECTED_TESTS]
        for plugin in ("igentic-iphone-lab", "iphone-connect"):
            names += [f"plugins/{plugin}/plugin.json", f"plugins/{plugin}/mcp.json"]
        for name in names:
            dest = self.root / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, dest)

    def change(self, name, before, after):
        path = self.root / name
        value = path.read_text()
        self.assertIn(before, value)
        path.write_text(value.replace(before, after, 1))

    def test_current_full_integration_structure(self):
        self.assertEqual(check_integration(self.root), [])

    def test_missing_synthetic_ui_test_source_rejected(self):
        self.change(PBX, "\t\t\t\tB30000000000000000000001 /* DiagnosticsUITests.swift in Sources */",
                    "\t\t\t\tB30000000000000000000001 /* MissingSyntheticUITest.swift in Sources */")
        self.assertTrue(any("DiagnosticsUITests.swift" in x for x in check_integration(self.root)))

    def test_missing_app_intent_system_test_rejected(self):
        self.change(PBX, "\t\t\t\tB20000000000000000000001 /* iGenticAppIntentsTests.swift in Sources */",
                    "\t\t\t\tB20000000000000000000001 /* LegacyTest.swift in Sources */")
        self.assertTrue(any("iGenticAppIntentsTests.swift" in x for x in check_integration(self.root)))

    def test_ui_method_cannot_disappear_behind_valid_xcode_references(self):
        self.change(f"{UI_DIR}/DiagnosticsUITests.swift",
                    "testLaunchExploreAndSyntheticApprovalCancel",
                    "renamedTestNotRecognized")
        self.assertTrue(any("UI test method missing" in x for x in check_integration(self.root)))

    def test_old_deployment_version_rejected(self):
        self.change(PBX, "IPHONEOS_DEPLOYMENT_TARGET = 27.0;",
                    "IPHONEOS_DEPLOYMENT_TARGET = 17.0;")
        self.assertTrue(any("deployment" in x for x in check_integration(self.root)))

    def test_scheme_must_reference_actual_test_target(self):
        self.change(SCHEME, 'BlueprintIdentifier = "B20000000000000000000006"',
                    'BlueprintIdentifier = "B30000000000000000000006"')
        self.assertTrue(any("scheme" in x for x in check_integration(self.root)))

    def test_policy_bridge_must_not_enable_write_actions(self):
        p = self.root / "ios/Sources/iGenticPluginPolicy/main.swift"
        p.write_text(p.read_text() + '\n// unauthorized case "create-reminder" marker\n')
        self.assertTrue(any("persistent write" in x for x in check_integration(self.root)))

    def test_policy_bridge_must_stay_in_package(self):
        self.change("ios/Package.swift",
                    '.executableTarget(name: "iGenticPluginPolicy", dependencies: ["AgentCore"])',
                    '.executableTarget(name: "iGenticPluginPolicy", dependencies: [])')
        self.assertTrue(any("AgentCore" in x for x in check_integration(self.root)))

    def test_plugins_must_have_unique_identity(self):
        p = self.root / "plugins/iphone-connect/plugin.json"
        x = json.loads(p.read_text())
        x["name"] = "igentic-iphone-lab"
        p.write_text(json.dumps(x))
        self.assertTrue(any("distinct identities" in x for x in check_integration(self.root)))

    def test_plugins_cannot_switch_to_network_listeners(self):
        p = self.root / "plugins/iphone-connect/mcp.json"
        x = json.loads(p.read_text())
        x["mcpServers"]["iphone"]["type"] = "http"
        x["mcpServers"]["iphone"]["url"] = "http://localhost:8080"
        p.write_text(json.dumps(x))
        self.assertTrue(any("stdio" in x for x in check_integration(self.root)))


if __name__ == "__main__":
    unittest.main()
