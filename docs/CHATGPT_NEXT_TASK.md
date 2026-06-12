# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

## Current operating mode

Codex is paused for now. ChatGPT works directly through the GitHub Connector on small, safe repository changes.

## Current validation status

- PR #23 (RiskScorer metadata integration) is merged.
- PR #21 (GitHub control dashboard layer) is merged.
- Issue #1 remains the primary validation gate.
- Issue #1 now contains local validation evidence showing:
  - repo-structure validation passed.
  - Swift tests passed.
  - Swift build passed.
- GitHub Actions evidence exists on recent PR heads, but current-main validation evidence should be explicitly confirmed before Issue #1 is closed.
- Branch `chatgpt/ci-case-coverage` adds PR Change Scope and documents the CI case matrix so future PRs show which validation path applies.

## Next task

Validation-first only.

1. Open and review the CI case coverage PR.
2. Confirm that these checks run and pass on the PR head:
   - PR Change Scope
   - Pull Request Quality
   - Repo Audit
   - Docs Consistency
   - Workflow Lint
   - Phase 0 CI Validation
3. If the PR checks are green and the scope is clean, merge it.
4. After merge, inspect the latest available GitHub Actions evidence for the current `main` branch.
5. Confirm whether the validation evidence recorded in Issue #1 corresponds to the current `main` state.
6. If evidence is sufficient, document it and close Issue #1.
7. If evidence is incomplete, leave Issue #1 open and record the exact missing validation artifact.

## Candidate follow-up issues

After Issue #1 is resolved, prefer the smallest scoped open issue:

- Issue #2: glossary for privacy and runtime terms.
- Issue #3: contributor/user FAQ.
- Issue #4: monochrome logo mark.

## Guardrails

- No direct app-runtime behavior changes.
- No networking, persistence, model calls, App Intents, external providers, credentials or private data.
- No broad rewrites.
- One small validation-oriented step per cycle.
