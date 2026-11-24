#!/usr/bin/env python3
"""Zero-dependency, synthetic-only iGentic MCP stdio lab server.

This code MUST NOT import a device driver, open a network listener, discover a
personal device, read files, or act on an iPhone. No real execution backend is
selectable. It supports MCP 2026-07-28 and legacy 2025-11-25 tool calls.
"""
from __future__ import annotations

import json
import sys
from typing import Any

MODERN = "2026-07-28"
LEGACY = "2025-11-25"
SERVER_INFO = {"name": "igentic-iphone-lab", "version": "0.1.0"}
SERVER_META = {"io.modelcontextprotocol/serverInfo": SERVER_INFO}
DEMO_ALIAS = "demo-iphone"
MAX_LINE = 32 * 1024

TOOLS = [
    {
        "name": "iphone_list_devices",
        "description": "Return one fictional device, NEVER a physical iPhone.",
        "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False},
        "annotations": {"readOnlyHint": True, "destructiveHint": False, "openWorldHint": False},
    },
    {
        "name": "iphone_get_capabilities",
        "description": "Return offline fake-device capability limits only.",
        "inputSchema": {
            "type": "object",
            "properties": {"device_alias": {"type": "string", "const": DEMO_ALIAS}},
            "required": ["device_alias"],
            "additionalProperties": False,
        },
        "annotations": {"readOnlyHint": True, "destructiveHint": False, "openWorldHint": False},
    },
    {
        "name": "iphone_observe",
        "description": "Read a fixed synthetic UI marker; does NOT capture any screen.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "device_alias": {"type": "string", "const": DEMO_ALIAS},
                "app": {"type": "string", "const": "igentic-demo"},
            },
            "required": ["device_alias", "app"],
            "additionalProperties": False,
        },
        "annotations": {"readOnlyHint": True, "destructiveHint": False, "openWorldHint": False},
    },
]


def error(request_id: Any, code: int, message: str, data: dict | None = None) -> dict:
    payload = {"code": code, "message": message}
    if data is not None:
        payload["data"] = data
    return {"jsonrpc": "2.0", "id": request_id, "error": payload}


def response(request_id: Any, result: dict, modern: bool) -> dict:
    if modern:
        result = {"resultType": "complete", **result, "_meta": SERVER_META}
    return {"jsonrpc": "2.0", "id": request_id, "result": result}


def tool_result(value: dict) -> dict:
    # Explicitly fake in BOTH machine-readable and legacy text forms.
    return {
        "isError": False,
        "structuredContent": value,
        "content": [{"type": "text", "text": json.dumps(value, sort_keys=True)}],
    }


def tool_call(params: dict) -> dict:
    name = params.get("name")
    args = params.get("arguments", {})
    if not isinstance(args, dict):
        raise ValueError("arguments must be an object")
    if name == "iphone_list_devices":
        if args:
            raise ValueError("unexpected arguments")
        return tool_result({
            "mode": "mock", "real_device": False,
            "devices": [{"device_alias": DEMO_ALIAS, "mode": "mock", "real_device": False}],
        })
    if name in ("iphone_get_capabilities", "iphone_observe"):
        required = {"device_alias"} if name == "iphone_get_capabilities" else {"device_alias", "app"}
        if set(args) != required or args.get("device_alias") != DEMO_ALIAS:
            raise ValueError("exact demo device alias and arguments required")
        if name == "iphone_observe":
            if args.get("app") != "igentic-demo":
                raise ValueError("only the synthetic demo app is supported")
            return tool_result({
                "mode": "mock", "real_device": False, "verified_real_device": False,
                "app": "igentic-demo", "marker": "IGENTIC_DEMO_READY",
                "capture": "fixture_only",
            })
        return tool_result({
            "mode": "mock", "real_device": False, "connected": False,
            "ui_control": False, "real_actions_allowed": False,
            "supported": ["synthetic_fixture_read"],
        })
    raise LookupError("unknown tool")


class LabServer:
    def __init__(self) -> None:
        self.legacy_initialized = False
        self.legacy_ready = False

    def handle(self, msg: Any) -> dict | None:
        if not isinstance(msg, dict) or msg.get("jsonrpc") != "2.0":
            return error(None, -32600, "Invalid request")
        method = msg.get("method")
        ident = msg.get("id")
        if not isinstance(method, str):
            return error(ident if isinstance(ident, (str, int)) else None, -32600, "Invalid request")
        # JSON-RPC notifications must not generate any reply.
        if "id" not in msg:
            if method == "notifications/initialized" and self.legacy_initialized:
                self.legacy_ready = True
            return None
        if isinstance(ident, bool) or not isinstance(ident, (str, int)):
            return error(None, -32600, "Invalid request")
        params = msg.get("params", {})
        if not isinstance(params, dict):
            return error(ident, -32602, "Invalid params")

        if method == "initialize":
            if params.get("protocolVersion") != LEGACY:
                return error(ident, -32022, "Unsupported protocol version", {
                    "supported": [MODERN, LEGACY], "requested": params.get("protocolVersion"),
                })
            self.legacy_initialized = True
            self.legacy_ready = False
            return response(ident, {
                "protocolVersion": LEGACY,
                "capabilities": {"tools": {"listChanged": False}},
                "serverInfo": SERVER_INFO,
                "instructions": "Synthetic device only; there is NO physical iPhone connection.",
            }, False)

        meta = params.get("_meta")
        modern = isinstance(meta, dict) and "io.modelcontextprotocol/protocolVersion" in meta
        if modern:
            version = meta.get("io.modelcontextprotocol/protocolVersion")
            if version != MODERN:
                return error(ident, -32022, "Unsupported protocol version", {
                    "supported": [MODERN, LEGACY], "requested": version,
                })
            if not isinstance(meta.get("io.modelcontextprotocol/clientCapabilities"), dict):
                return error(ident, -32602, "Missing client capabilities")
        elif not self.legacy_ready:
            return error(ident, -32600, "MCP lifecycle not established")

        if method == "server/discover":
            if not modern:
                return error(ident, -32601, "Method not found")
            return response(ident, {
                "supportedVersions": [MODERN, LEGACY],
                "capabilities": {"tools": {"listChanged": False}},
                "instructions": "Synthetic-only read-only lab; never use as evidence of a real device.",
            }, True)
        if method == "ping":
            return response(ident, {}, modern)
        if method == "tools/list":
            if set(params) - {"_meta"}:
                return error(ident, -32602, "Invalid params")
            return response(ident, {"tools": TOOLS}, modern)
        if method == "tools/call":
            try:
                if set(params) - {"_meta", "name", "arguments"} or not isinstance(params.get("name"), str):
                    raise ValueError("unexpected or missing tool parameter")
                return response(ident, tool_call(params), modern)
            except (ValueError, LookupError):
                return error(ident, -32602, "Unknown tool or invalid arguments")
        return error(ident, -32601, "Method not found")


def serve() -> None:
    server = LabServer()
    inp, out = sys.stdin.buffer, sys.stdout.buffer
    while True:
        raw = inp.readline(MAX_LINE + 1)
        if not raw:
            return
        if len(raw) > MAX_LINE:
            # Drain overlong records; never log user content.
            while raw and not raw.endswith(b"\n"):
                raw = inp.readline(MAX_LINE + 1)
            result = error(None, -32700, "Message too large")
        else:
            try:
                obj = json.loads(raw)
                result = server.handle(obj)
            except (UnicodeDecodeError, ValueError, TypeError):
                result = error(None, -32700, "Parse error")
        if result is not None:
            out.write(json.dumps(result, separators=(",", ":"), ensure_ascii=True).encode() + b"\n")
            out.flush()


if __name__ == "__main__":
    serve()
