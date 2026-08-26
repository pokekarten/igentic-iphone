# AGENTS.md — iGentic iPhone

Repository: `pokekarten/igentic-iphone`

The project is a privacy-first iPhone AI runtime layer. Security, local-first behavior, policy decisions and auditability remain product requirements. The work model, however, should stay execution-first rather than process-first.

## Progress-first execution default

1. **ChatGPT + live GitHub connector** is the default contributor for repository inspection, source-level edits, tests/docs, PR/review work and task selection.
2. **ChatGPT's Linux environment** is the first execution lane for repository validation, Python tooling, deterministic tests, architecture checks and any Swift/package work that can be established there.
3. **Mac/Codex** is used only for the smallest slice that genuinely requires Xcode/macOS, iOS Simulator/device behavior, Apple frameworks, signing, local model runtime, thermal/battery measurement or another result unavailable in Linux.
4. Other agents may work in parallel only on disjoint tasks after checking live GitHub overlap.

After a Mac/Codex/device result, ownership returns to ChatGPT/GitHub unless another real platform boundary remains.

Do not require `docs/CODEX_NEXT_TASK.md`, a new branch, Draft PR or Codex run merely because code changes. Use those only when delegation/coordination actually helps.

Master prompts are optional task templates, not a scheduler or prerequisite.

## Governance proportional to risk

Do not add approval flows, status files, handoff documents, slot systems, Issues or gates unless they solve a demonstrated problem: real privacy/security risk, write collision, platform-specific execution need or repeated defect.

Prefer implementing, testing and measuring the next product/kernel capability.

Exact byte/runtime identity is required only when a claim genuinely depends on it. Ordinary engineering should optimize correctness, privacy properties, maintainability, user value, test coverage and current model/runtime quality.

## Product and safety boundaries

- Never commit secrets, tokens, private user data, messages, health/financial content or local credentials.
- Do not bypass `PolicyEngine`, `ApprovalManager` or `AuditLog` for actions that the current design requires them to mediate.
- Do not silently enable paid services, signing/account changes or external data flows.
- Device/platform claims must come from an actual observed iPhone/simulator/Mac run when the claim depends on that platform.
- Local-first/privacy claims must remain testable rather than becoming documentation slogans.

## Work selection

Refresh live `main`, relevant PRs/issues and recent commits first. Choose the smallest causal product/technical step that removes a blocker or improves the runtime.

Read only the task-specific architecture/docs needed. Do not require a full roadmap/status review before every bounded change.

Use focused validation appropriate to the slice. Common commands include:

```bash
python scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

Run them where the environment supports them and report honestly when a platform-specific check requires the Mac.

## Parallel work

Parallel agents are useful for clearly separate kernel, policy, research, test or platform tasks. Do not duplicate work and do not create tasks merely to keep agents busy.

## End of run

A useful run leaves working code, a meaningful test, a measured platform result, a resolved design uncertainty or a smaller blocker.

Report briefly:

```text
Done:
Evidence/tests:
Still open:
Next causal action:
```

Use existing GitHub objects when durable coordination is useful; do not create a new status artifact solely for handoff.
