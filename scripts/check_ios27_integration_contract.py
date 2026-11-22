#!/usr/bin/env python3
"""Fail-closed structural admission for the consolidated iOS 27 review stack.

This is a source-composition check, not an app UI test or a phone permission
audit. All referenced artifacts must be present on the SAME checked-out head.
"""
from __future__ import annotations

import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PBX = "app/iGenticDiagnostics/iGenticDiagnostics.xcodeproj/project.pbxproj"
SCHEME = "app/iGenticDiagnostics/iGenticDiagnostics.xcodeproj/xcshareddata/xcschemes/iGenticDiagnostics.xcscheme"
UI_DIR = "app/iGenticDiagnostics/iGenticDiagnosticsUITests"
EXPECTED_TESTS = ("iGenticAppIntentsTests.swift", "DiagnosticsUITests.swift")
OBJECT_RE = re.compile(
    r"(?ms)^\t\t([A-F0-9]{24}) /\* ([^*\n]+) \*/ = \{(.*?)^\t\t\};"
)


def _section(source: str, name: str) -> str:
    left, right = f"/* Begin {name} section */", f"/* End {name} section */"
    if source.count(left) != 1 or source.count(right) != 1:
        raise ValueError(f"missing or repeated {name} section")
    return source.split(left, 1)[1].split(right, 1)[0]


def _objects(source: str, name: str) -> dict[str, tuple[str, str]]:
    return {identifier: (comment, body) for identifier, comment, body in OBJECT_RE.findall(
        _section(source, name)
    )}


def check_integration(root: Path = ROOT) -> list[str]:
    errors: list[str] = []

    def read(path: str) -> str:
        try:
            return (root / path).read_text(encoding="utf-8")
        except (OSError, UnicodeError):
            errors.append(f"required file missing/unreadable: {path}")
            return ""

    pbx = read(PBX)
    scheme_text = read(SCHEME)
    manifest = read("ios/Package.swift")
    source_texts = {name: read(f"{UI_DIR}/{name}") for name in EXPECTED_TESTS}
    expected_methods = {
        "iGenticAppIntentsTests.swift": "testReadOnlyDiagnosticsIntentRunsThroughSystem",
        "DiagnosticsUITests.swift": "testLaunchExploreAndSyntheticApprovalCancel",
    }
    for source_name, method in expected_methods.items():
        if not re.search(r"\bfunc\s+" + re.escape(method) + r"\s*\(", source_texts[source_name]):
            errors.append(f"UI test method missing from {source_name}: {method}")

    if pbx:
        minimums = re.findall(r"\bIPHONEOS_DEPLOYMENT_TARGET\s*=\s*([^;]+);", pbx)
        if not minimums or any(x.strip() != "27.0" for x in minimums):
            errors.append("all Xcode deployment configurations must be iOS 27.0")
        try:
            targets = _objects(pbx, "PBXNativeTarget")
            matches = [(identifier, body) for identifier, (_, body) in targets.items()
                       if re.search(r"\bname = iGenticDiagnosticsUITests;", body)]
            if len(matches) != 1:
                errors.append("expected exactly one combined iGenticDiagnosticsUITests native target")
            else:
                target_id, target_body = matches[0]
                if 'productType = "com.apple.product-type.bundle.ui-testing";' not in target_body:
                    errors.append("combined target must be a UI testing bundle")
                build_phase_ids = re.findall(r"\b([A-F0-9]{24}) /\* Sources \*/", target_body)
                if len(build_phase_ids) != 1:
                    errors.append("combined UI target requires exactly one Sources build phase")
                else:
                    sources = _objects(pbx, "PBXSourcesBuildPhase")
                    source_object = sources.get(build_phase_ids[0])
                    if source_object is None:
                        errors.append("combined UI test Sources build phase is missing")
                    else:
                        body = source_object[1]
                        for source in EXPECTED_TESTS:
                            if body.count(f"/* {source} in Sources */") != 1:
                                errors.append(f"combined UI target must compile {source} exactly once")
                if scheme_text:
                    try:
                        scheme = ET.fromstring(scheme_text)
                        test_refs = scheme.findall("./TestAction/Testables/TestableReference")
                        refs = [x.find("BuildableReference") for x in test_refs]
                        if len(refs) != 1 or refs[0] is None or refs[0].get("BlueprintIdentifier") != target_id:
                            errors.append("shared Xcode scheme must test exactly the combined UI target")
                        elif test_refs[0].get("skipped") != "NO":
                            errors.append("combined Xcode scheme must enable UI tests")
                    except ET.ParseError:
                        errors.append("Xcode shared scheme XML is malformed")
        except ValueError as e:
            errors.append(str(e))

    if '.iOS("27.0")' not in manifest:
        errors.append("Swift package must require iOS 27.0")
    if '.executable(name: "iGenticPluginPolicy", targets: ["iGenticPluginPolicy"])' not in manifest:
        errors.append("Swift policy bridge executable missing from package")
    if '.executableTarget(name: "iGenticPluginPolicy", dependencies: ["AgentCore"])' not in manifest:
        errors.append("Swift policy bridge must depend on AgentCore")
    workflow = read(".github/workflows/ios-app-wrapper.yml")
    acceptance_requirements = (
        "Execute both iOS 27 system-level UI acceptance tests",
        "select_ios27_simulator.py",
        "-only-testing:iGenticDiagnosticsUITests/DiagnosticsUITests",
        "-only-testing:iGenticDiagnosticsUITests/iGenticAppIntentsTests",
        "CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-",
        "-parallel-testing-enabled NO",
    )
    for requirement in acceptance_requirements:
        if requirement not in workflow:
            errors.append(f"iOS App Wrapper must execute both simulator system tests: {requirement}")
    if "platform=iOS Simulator,id=" not in workflow:
        errors.append("system tests must target a selected iOS simulator, not a physical phone")
    policy = read("ios/Sources/iGenticPluginPolicy/main.swift")
    if "PolicyEngine().decide(" not in policy or "requestedDelegationTarget: .localDevice" not in policy:
        errors.append("Swift policy bridge must invoke AgentCore local-device policy")
    if any(needle in policy for needle in ['case "send-message"', 'case "create-reminder"']):
        errors.append("Swift plugin policy must not grant persistent write actions")

    names: list[str] = []
    servers: list[str] = []
    for package in ("igentic-iphone-lab", "iphone-connect"):
        prefix = f"plugins/{package}"
        for name in ("plugin.json", "mcp.json"):
            path = prefix + "/" + name
            try:
                data = json.loads(read(path))
                if name == "plugin.json":
                    names.append(data["name"])
                else:
                    mcp = data["mcpServers"]
                    if len(mcp) != 1:
                        errors.append(f"{path} must declare exactly one MCP server")
                    for server_id, server in mcp.items():
                        servers.append(server_id)
                        if server.get("type") != "stdio" or "url" in server or "http" in server:
                            errors.append(f"{path} must use local stdio only")
            except (ValueError, KeyError, TypeError):
                errors.append(f"invalid plugin contract JSON: {path}")
    if len(names) != 2 or len(set(names)) != 2:
        errors.append("mock and physical plugins must have distinct identities")
    if len(servers) != 2 or len(set(servers)) != 2:
        errors.append("mock and physical MCP server keys must be distinct")

    return errors


if __name__ == "__main__":
    failures = check_integration()
    if failures:
        print("iOS 27 combined integration contract failed:\n- " + "\n- ".join(failures), file=sys.stderr)
        sys.exit(1)
    print("Combined iOS 27 integration contract verified (structure only).")
