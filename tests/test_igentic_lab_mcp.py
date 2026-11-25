"""Offline MCP regression tests: no device or network access."""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import unittest


ROOT = Path(__file__).resolve().parents[1]
PLUGIN = ROOT / "plugins" / "igentic-iphone-lab"
spec = importlib.util.spec_from_file_location("igentic_lab_mcp", PLUGIN / "server.py")
assert spec and spec.loader
lab = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lab)


def modern(method: str, params: dict | None = None, ident=1) -> dict:
    p = dict(params or {})
    p["_meta"] = {
        "io.modelcontextprotocol/protocolVersion": lab.MODERN,
        "io.modelcontextprotocol/clientCapabilities": {},
        "io.modelcontextprotocol/clientInfo": {"name": "fixture", "version": "0"},
    }
    return {"jsonrpc": "2.0", "id": ident, "method": method, "params": p}


def call(tool: str, arguments: dict | None = None) -> dict:
    return modern("tools/call", {"name": tool, "arguments": arguments or {}})


class LabMCPTests(unittest.TestCase):
    def setUp(self):
        self.server = lab.LabServer()

    def test_discover_requires_no_handshake(self):
        reply = self.server.handle(modern("server/discover"))
        self.assertEqual(reply["result"]["resultType"], "complete")
        self.assertIn(lab.MODERN, reply["result"]["supportedVersions"])
        self.assertEqual(reply["result"]["_meta"]["io.modelcontextprotocol/serverInfo"]["name"], "igentic-iphone-lab")

    def test_modern_tool_listing_has_only_three_read_only_tools(self):
        tools = self.server.handle(modern("tools/list"))["result"]["tools"]
        self.assertEqual([x["name"] for x in tools], [
            "iphone_list_devices", "iphone_get_capabilities", "iphone_observe"
        ])
        self.assertTrue(all(x["annotations"]["readOnlyHint"] for x in tools))
        self.assertTrue(all(x["inputSchema"]["additionalProperties"] is False for x in tools))

    def test_list_does_not_claim_a_physical_phone(self):
        result = self.server.handle(call("iphone_list_devices"))["result"]
        self.assertEqual(result["structuredContent"]["devices"][0]["mode"], "mock")
        self.assertFalse(result["structuredContent"]["devices"][0]["real_device"])
        self.assertNotIn("udid", str(result).lower())

    def test_capabilities_are_explicitly_not_physical(self):
        result = self.server.handle(call("iphone_get_capabilities", {
            "device_alias": "demo-iphone"
        }))["result"]
        self.assertFalse(result["structuredContent"]["connected"])
        self.assertFalse(result["structuredContent"]["real_actions_allowed"])
        self.assertFalse(result["structuredContent"]["ui_control"])

    def test_observe_is_synthetic_not_screen_capture(self):
        result = self.server.handle(call("iphone_observe", {
            "device_alias": "demo-iphone", "app": "igentic-demo"
        }))["result"]["structuredContent"]
        self.assertEqual(result["marker"], "IGENTIC_DEMO_READY")
        self.assertEqual(result["capture"], "fixture_only")
        self.assertFalse(result["verified_real_device"])

    def test_legacy_requires_handshake_then_ack(self):
        before = self.server.handle({
            "jsonrpc": "2.0", "id": 1, "method": "tools/list", "params": {}
        })
        self.assertIn("error", before)
        init = self.server.handle({
            "jsonrpc": "2.0", "id": 2, "method": "initialize",
            "params": {"protocolVersion": lab.LEGACY, "capabilities": {},
                       "clientInfo": {"name": "legacy", "version": "0"}}
        })
        self.assertEqual(init["result"]["protocolVersion"], lab.LEGACY)
        self.assertIsNone(self.server.handle({
            "jsonrpc": "2.0", "method": "notifications/initialized"
        }))
        after = self.server.handle({
            "jsonrpc": "2.0", "id": 3, "method": "tools/list", "params": {}
        })
        self.assertIn("tools", after["result"])
        self.assertNotIn("resultType", after["result"])

    def test_unknown_tool_and_action_rejected(self):
        for name in ("iphone_tap", "iphone_execute_action", "shell", "iphone_remove_app"):
            with self.subTest(name=name):
                self.assertEqual(self.server.handle(call(name))["error"]["code"], -32602)

    def test_any_non_demo_alias_rejected(self):
        r = self.server.handle(call("iphone_get_capabilities", {"device_alias": "unknown-device"}))
        self.assertEqual(r["error"]["code"], -32602)
        self.assertNotIn("unknown-device", json.dumps(r))

    def test_extra_arguments_and_unexpected_keys_rejected(self):
        samples = [
            call("iphone_list_devices", {"allow_real": True}),
            call("iphone_get_capabilities", {"device_alias": "demo-iphone", "approved": True}),
            call("iphone_observe", {"device_alias": "demo-iphone", "app": "com.apple.Preferences"}),
            modern("tools/list", {"limit": 100}),
            modern("tools/call", {"name": "iphone_list_devices", "arguments": {}, "approved": True}),
        ]
        for payload in samples:
            with self.subTest(payload=payload["method"]):
                self.assertEqual(self.server.handle(payload)["error"]["code"], -32602)

    def test_malformed_arguments_fail_closed(self):
        for arguments in (None, [], "device", 17):
            if arguments is None:
                p = modern("tools/call", {"name": "iphone_get_capabilities", "arguments": None})
            else:
                p = modern("tools/call", {"name": "iphone_get_capabilities", "arguments": arguments})
            self.assertEqual(self.server.handle(p)["error"]["code"], -32602)

    def test_wrong_modern_protocol_rejected(self):
        request = modern("tools/list")
        request["params"]["_meta"]["io.modelcontextprotocol/protocolVersion"] = "2099-01-01"
        reply = self.server.handle(request)
        self.assertEqual(reply["error"]["code"], -32022)
        self.assertIn(lab.MODERN, reply["error"]["data"]["supported"])

    def test_modern_request_must_contain_capabilities(self):
        request = modern("tools/list")
        del request["params"]["_meta"]["io.modelcontextprotocol/clientCapabilities"]
        self.assertEqual(self.server.handle(request)["error"]["code"], -32602)

    def test_modern_tool_calls_without_initialize_work(self):
        self.assertIn("result", self.server.handle(call("iphone_list_devices")))

    def test_notifications_never_get_replies(self):
        self.assertIsNone(self.server.handle({
            "jsonrpc": "2.0", "method": "notifications/initialized"
        }))
        self.assertIsNone(self.server.handle({
            "jsonrpc": "2.0", "method": "notifications/custom", "params": {"unexpected": True}
        }))

    def test_invalid_input_and_unknown_method(self):
        self.assertEqual(self.server.handle([])["error"]["code"], -32600)
        self.assertEqual(self.server.handle({"jsonrpc": "1.0", "id": 7, "method": "ping"})["error"]["code"], -32600)
        self.assertEqual(self.server.handle(modern("iphone/execute"))["error"]["code"], -32601)
        self.assertEqual(self.server.handle(modern("ping"))["result"]["resultType"], "complete")

    def test_manifest_is_local_stdio_no_network_and_no_write(self):
        p = json.loads((PLUGIN / "plugin.json").read_text())
        cfg = json.loads((PLUGIN / "mcp.json").read_text())
        self.assertEqual(p["name"], "igentic-iphone-lab")
        server = cfg["mcpServers"]["igentic-demo"]
        self.assertEqual(server["type"], "stdio")
        self.assertEqual(server["command"], "python3")
        self.assertNotIn("url", server)
        self.assertNotIn("token", json.dumps(cfg).lower())

    def test_full_stdio_modern_session(self):
        requests = [
            modern("server/discover", ident="s1"),
            modern("tools/list", ident="s2"),
            call("iphone_get_capabilities", {"device_alias": "demo-iphone"}),
            modern("tools/call", {"name": "iphone_execute_action", "arguments": {}}),
        ]
        fixture = b"".join((json.dumps(x) + "\n").encode() for x in requests)
        proc = subprocess.run(
            [sys.executable, str(PLUGIN / "server.py")],
            input=fixture, capture_output=True, timeout=5, check=True,
        )
        self.assertFalse(proc.stderr)
        results = [json.loads(line) for line in proc.stdout.splitlines()]
        self.assertEqual(len(results), 4)
        self.assertEqual(results[0]["result"]["resultType"], "complete")
        self.assertEqual(results[1]["result"]["tools"][0]["name"], "iphone_list_devices")
        self.assertFalse(results[2]["result"]["structuredContent"]["real_device"])
        self.assertEqual(results[3]["error"]["code"], -32602)

    def test_invalid_line_and_later_valid_request(self):
        fixture = b"{not-json}\n" + json.dumps(modern("ping")).encode() + b"\n"
        proc = subprocess.run(
            [sys.executable, str(PLUGIN / "server.py")],
            input=fixture, capture_output=True, timeout=5, check=True,
        )
        results = [json.loads(line) for line in proc.stdout.splitlines()]
        self.assertEqual(results[0]["error"]["code"], -32700)
        self.assertIn("result", results[1])

    def test_overlong_line_rejected_and_recovery(self):
        fixture = b"x" * (lab.MAX_LINE + 2) + b"\n" + json.dumps(modern("ping")).encode() + b"\n"
        proc = subprocess.run(
            [sys.executable, str(PLUGIN / "server.py")],
            input=fixture, capture_output=True, timeout=5, check=True,
        )
        results = [json.loads(line) for line in proc.stdout.splitlines()]
        self.assertEqual(results[0]["error"]["message"], "Message too large")
        self.assertIn("result", results[1])


if __name__ == "__main__":
    unittest.main()
