# Codex Next Task

Repository: `pokekarten/igentic-iphone`

## Status

Codex is paused for now.

ChatGPT will continue with direct, small GitHub-Connector changes until the core safety path is stable.

## Why Codex is paused

We want to avoid broad agent work before the repository has a stable security-first kernel. Current work should stay very small and reviewable:

1. thread-safe audit logging,
2. approval-state guard,
3. safe stubs for tool and memory components,
4. docs and tests aligned with actual code.

## Next Codex candidate later

When Codex is re-enabled, the first Codex task should be small and based on the current `docs/CHATGPT_NEXT_TASK.md` state. Do not reuse older ZIP-import tasks without review.

## Current active task source

Use:

```text
docs/CHATGPT_NEXT_TASK.md
```

## Stop rules for future Codex use

Codex must stop if a task requires:

- broad repo import,
- ZIP extraction,
- model weights,
- secrets,
- Apple signing credentials,
- real personal data,
- App Store configuration,
- external provider integration.
