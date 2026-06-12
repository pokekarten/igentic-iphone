# Sparsamkeit

This project uses Codex carefully. The goal is not to maximize agent activity; the goal is to keep every change reviewable, cheap and safe.

## Default Codex context

Codex should normally read only:

```text
AGENTS.md
PROJECT_STATE.md
docs/CODEX_NEXT_TASK.md
one task-specific doc
the allowlisted files for the task
```

Do not ask Codex to read or rewrite the whole repo unless the task is explicitly a repo audit.

## Task size rules

Prefer:

- one branch per task,
- one Draft PR per task,
- 3-5 changed files,
- under 250 changed lines,
- tests before feature expansion,
- docs updates only when they clarify state or next work.

Avoid:

- broad refactors,
- speculative framework imports,
- model weights,
- generated files,
- large binary assets,
- long multi-feature prompts,
- adding dependencies before policy/tests exist.

## ChatGPT responsibilities

ChatGPT should use the GitHub Connector for:

- reading actual repo files,
- checking PR diffs,
- checking changed filenames,
- reviewing validation output,
- writing focused comments,
- preparing the next small task.

ChatGPT should not assume a PR is correct because Codex says it is correct.

## Codex responsibilities

Codex should:

- obey the allowlist,
- stop on ambiguity,
- create Draft PRs,
- report validation output,
- avoid touching files not named in the task,
- never commit secrets, build artifacts, model weights or ZIP archives.

## iPhone testing responsibilities

Real device testing should be used only when the claim depends on device behavior:

- App Intents,
- permissions,
- background behavior,
- thermal behavior,
- battery behavior,
- local model runtime performance,
- offline behavior.
