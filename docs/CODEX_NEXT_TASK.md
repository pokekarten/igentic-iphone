# Codex Next Task

Repository: `pokekarten/igentic-iphone`

## Status

Codex may be used for bounded, source-backed implementation or validation work when live GitHub shows that no active implementation PR conflicts with the task.

Codex is not a source of truth for current issue, branch, pull-request or check state. Every run must reconcile live GitHub first and must not revive a target from this file merely because the text is older than the repository.

## Current use boundary

The early-kernel tasks previously listed here (thread-safe audit logging, approval-state guard, and initial tool/memory stubs) are completed foundation and are not the next task.

Current work should instead be selected from live, source-backed issues and kept narrow. Suitable task classes include:

1. deterministic repository/security admission work with explicit trust-boundary tests;
2. bounded state/documentation reconciliation when live code and operating documents diverge;
3. host-only model evidence execution using already-frozen benchmark/runner contracts;
4. small product slices that preserve deterministic policy/approval authority and have exact tests.

## Required preflight

Before changing product files, Codex must:

1. read current `main`;
2. check for an existing open implementation PR;
3. read the exact selected issue and its comments;
4. inspect equivalent branches/PRs to avoid duplicate work;
5. record the exact starting SHA;
6. stay inside the issue scope, acceptance criteria and stop rules.

If live GitHub conflicts with this document, live GitHub wins.

## Research execution boundary

Host evidence tasks must preserve their precommitted benchmark/model contracts. Do not repair weak model outputs, select favorable seeds/cases, change decoding after seeing results, or promote host evidence to physical-iPhone evidence.

Apple Foundation Models host execution requires an eligible Apple-Silicon Mac. Qwen host execution does not inherently require a Mac. Gated model work such as FunctionGemma must satisfy the exact upstream license/provenance gate before adapter or training work.

## Validation

Always run the validation required by the selected issue. Baseline repository validation is:

```bash
python3 scripts/validate_repo_structure.py
```

Swift source changes normally also require:

```bash
cd ios && swift test
```

Do not report completion unless the evidence matches the exact branch/head being reported.

## Stop rules

Codex must stop or return the exact blocker if a task would require work outside its issue contract, including:

- a second conflicting implementation PR;
- model weights or gated artifacts without legitimate access;
- secrets, signing credentials or real personal data;
- benchmark/test target leakage or post-result repair;
- physical-device readiness claims without physical-device evidence;
- broad external-provider, persistence, memory-content or side-effect expansion not explicitly authorized by the selected issue.

Keep models advisory. Deterministic policy, approval, schema validation, execution boundaries and audit remain authoritative.
