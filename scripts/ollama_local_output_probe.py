#!/usr/bin/env python3
"""Opt-in *Mac-only* local Ollama smoke test for synthetic action JSON.

Never prints a raw model response or executes the requested action. This is not
an iOS inference adapter, a production parser, or an evaluation of real data.
"""
from __future__ import annotations

import argparse
import json
import urllib.error
import urllib.request

LOCAL_API = 'http://127.0.0.1:11434/api/generate'
ALLOWED_MODELS = ('qwen3:4b', 'qwen3.5:4b')
PROMPT = 'Return exactly the JSON object {"action":"diagnostics.read","approved":false} and nothing else.'


def classify_generated_text(raw: object) -> str:
    """Fail closed: *one* JSON object, two exact keys, no approvals.

    An LLM cannot grant user approval, and this output is never an executor.
    """
    if not isinstance(raw, str) or len(raw.encode('utf-8')) > 2048:
        return 'invalid_output'
    try:
        parsed = json.loads(raw)
    except (ValueError, TypeError):
        return 'not_strict_json'
    if not isinstance(parsed, dict) or set(parsed) != {'action', 'approved'}:
        return 'invalid_schema'
    if parsed['action'] != 'diagnostics.read' or parsed['approved'] is not False:
        return 'action_or_approval_not_permitted'
    return 'synthetic_preview_only'


def public_evidence(payload: object) -> dict:
    """Return only safe enumerated disposition and numeric timing statistics."""
    if not isinstance(payload, dict) or payload.get('done') is not True:
        return {'disposition': 'invalid_server_result'}
    evidence: dict = {'disposition': classify_generated_text(payload.get('response'))}
    for key in ('total_duration', 'eval_count', 'eval_duration'):
        value = payload.get(key)
        if type(value) is int and 0 <= value <= 10**15:
            evidence[key] = value
    return evidence


def run_synthetic(model: str, timeout: float = 120) -> dict:
    if model not in ALLOWED_MODELS:
        raise ValueError('model not on local opt-in allowlist')
    request = urllib.request.Request(
        LOCAL_API,
        data=json.dumps({
            'model': model,
            'prompt': PROMPT,
            'stream': False,
            'think': False,
            'keep_alive': '0s',
            'options': {'num_predict': 64, 'temperature': 0},
        }).encode('utf-8'),
        headers={'Content-Type': 'application/json'},
    )
    # Only a fixed localhost target, no redirects and no user-provided prompts.
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            return None
    handler = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
    with handler.open(request, timeout=timeout) as response:
        if response.geturl() != LOCAL_API:
            raise ValueError('nonlocal endpoint response refused')
        data = response.read(65537)
    if len(data) > 65536:
        return {'disposition': 'oversized_server_result'}
    try:
        return public_evidence(json.loads(data))
    except (UnicodeError, ValueError):
        return {'disposition': 'invalid_server_result'}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', action='store_true', help='explicit opt-in to actual local inference')
    parser.add_argument('--model', choices=ALLOWED_MODELS, default='qwen3:4b')
    args = parser.parse_args()
    if not args.run:
        print(json.dumps({'disposition': 'skipped_opt_in_required'}))
        return 0
    try:
        evidence = run_synthetic(args.model)
    except (OSError, urllib.error.URLError, ValueError) as exc:
        # Never include provider exception details: those may echo prompt text.
        evidence = {'disposition': 'local_runtime_unavailable'}
    print(json.dumps(evidence, sort_keys=True))
    return 0 if evidence['disposition'] == 'synthetic_preview_only' else 1


if __name__ == '__main__':
    raise SystemExit(main())
