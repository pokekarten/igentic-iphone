# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

## Current operating mode

Codex is paused for now. ChatGPT works directly through the GitHub Connector on small, safe repository changes.

## Current validation status

- Issue #1 acceptance criteria require recorded results for:
  - `python3 scripts/validate_repo_structure.py`
  - `cd ios && swift test`
  - `cd ios && swift build`
- Issue #1 already contains recorded evidence that all three commands passed in a clean validation environment.
- Recent PR-head checks also provided validation evidence before merge.
- Do not create an endless validation loop by treating ChatGPT issue comments, documentation notes, or follow-up bookkeeping commits as new feature validation targets.
- A post-merge Actions run on every latest `main` commit is useful evidence, but it is not required to keep re-opening Issue #1 when the original acceptance criteria are already satisfied.

## Next task

Close Issue #1 as completed with a final comment that records the corrected closure rule:

- The original validation task is complete because the required command results are recorded.
- Future code/runtime changes must still prove validation through PR checks or a new issue.
- Documentation-only, comment-only, or watcher bookkeeping updates must not reset the Phase 0 validation gate.

After Issue #1 is closed, choose the smallest scoped open issue and continue normal progress.

## Candidate follow-up issues

Prefer the smallest scoped open issue:

- Issue #2: glossary for privacy and runtime terms.
- Issue #3: contributor/user FAQ.
- Issue #4: monochrome logo mark.

## Guardrails

- No direct app-runtime behavior changes.
- No networking, persistence, model calls, App Intents, external providers, credentials or private data.
- No broad rewrites.
- One small validation-oriented or documentation-oriented step per cycle.