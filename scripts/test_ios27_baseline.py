"""Regression tests for the committed iOS 27 deployment and toolchain gate."""
from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from validate_ios27_baseline import validate_ios27_baseline  # noqa: E402


class IOS27BaselineTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.files = {
            "ios/Package.swift": '// swift-tools-version: 6.2\nlet minimum = .iOS("27.0")\n',
            "app/iGenticDiagnostics/iGenticDiagnostics.xcodeproj/project.pbxproj":
                "IPHONEOS_DEPLOYMENT_TARGET = 27.0;\n" * 4,
            ".github/workflows/ci-phase-0-validation.yml":
                "runs-on: xcode-27\ncontainer: swift:6.2\n",
            ".github/workflows/ios-app-wrapper.yml": "runs-on: xcode-27\n",
            ".github/workflows/swift.yml": "runs-on: xcode-27\n",
            ".github/workflows/codeql-advanced.yml": "runs-on: xcode-27\n",
            "scripts/smoke-ios-simulator.sh": "python3 scripts/select_ios27_simulator.py\n",
        }
        for path, content in self.files.items():
            target = self.root / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content, encoding="utf-8")

    def corrupt(self, path: str, old: str, new: str) -> None:
        target = self.root / path
        content = target.read_text(encoding="utf-8")
        self.assertIn(old, content)
        target.write_text(content.replace(old, new, 1), encoding="utf-8")

    def test_all_ios27_requirements_pass(self):
        self.assertEqual(validate_ios27_baseline(self.root), [])

    def test_pre27_package_deployment_is_rejected(self):
        self.corrupt("ios/Package.swift", '"27.0"', '".v17"')
        self.assertTrue(validate_ios27_baseline(self.root))

    def test_mixed_xcode_target_versions_fail(self):
        self.corrupt(
            "app/iGenticDiagnostics/iGenticDiagnostics.xcodeproj/project.pbxproj",
            "27.0", "26.0",
        )
        self.assertTrue(validate_ios27_baseline(self.root))

    def test_old_codeql_runner_fails(self):
        self.corrupt(".github/workflows/codeql-advanced.yml", "xcode-27", "macos-15")
        errors = validate_ios27_baseline(self.root)
        self.assertTrue(any("codeql" in error for error in errors))

    def test_old_linux_swift_fails(self):
        self.corrupt(".github/workflows/ci-phase-0-validation.yml", "swift:6.2", "swift:6.0")
        self.assertTrue(validate_ios27_baseline(self.root))

    def test_missing_versioned_simulator_selector_fails(self):
        self.corrupt("scripts/smoke-ios-simulator.sh", "select_ios27_simulator.py", "fallback.py")
        self.assertTrue(validate_ios27_baseline(self.root))


if __name__ == "__main__":
    unittest.main()
