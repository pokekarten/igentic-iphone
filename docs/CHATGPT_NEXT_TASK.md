# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

## Current operating mode

Codex is paused for now. ChatGPT works directly through the GitHub Connector on small, safe repository changes.

## Current validation status

- PR #23 (RiskScorer metadata integration) is merged.
- PR #21 (GitHub control dashboard layer) is merged.
- Issue #1 remains the primary validation gate.
- Issue #1 now contains local validation evidence showing:
  - `python3 scripts/validate_repo_structure.py` passed.
  - `cd ios && swift test` passed.
  - `cd ios && swift build` passed.
- GitHub Actions evidence exists on recent PR heads, but current-main validation evidence should be explicitly confirmed before Issue #1 is closed.

## Next task

Validation-first only.

1. Inspect the latest available GitHub Actions evidence for the current `main` branch.
2. Confirm whether the validation evidence recorded in Issue #1 corresponds to the current `main` state.
3. If evidence is sufficient, document it and close Issue #1.
4. If evidence is incomplete, leave Issue #1 open and record the exact missing validation artifact.

## Candidate follow-up issues

After Issue #1 is resolved, prefer the smallest scoped open issue:

- Issue #2: glossary for privacy and runtime terms.
- Issue #3: contributor/user FAQ.
- Issue #4: monochrome logo mark.

## Guardrails

- No direct app-runtime behavior changes.
- No networking, persistence, model calls, App Intents, external providers, secrets, or private data.
- No broad rewrites.
- One small validation-oriented step per cycle.
