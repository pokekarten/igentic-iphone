# Open Source Issue Plan

This plan turns the public repository into a contributor-friendly backlog.

## Near-term public issues

1. Validate current main
   - Goal: prove repo structure validation, Swift tests and Swift build.
   - Source: `docs/VALIDATION.md`.

2. Configure branch protection
   - Goal: make PR plus checks the normal path into `main`.
   - Source: `docs/PUBLIC_REPO_SETUP.md`.

3. Convert good-first backlog
   - Goal: create a small set of real issues from `docs/community/GOOD_FIRST_ISSUES.md`.
   - Source: community docs.

4. Add PolicyEngine edge-case tests
   - Goal: strengthen safety behavior without changing runtime scope.
   - Source: current Phase 1 safety stubs.

5. Integrate RiskScorer as metadata
   - Goal: expose risk score in policy metadata without loosening approval or blocking behavior.
   - Source: current `RiskScorer` and `PolicyEngine`.

## Issue quality bar

Every public issue should include:

- goal,
- context,
- allowed scope,
- forbidden scope,
- validation target,
- definition of done.

## Contributor-friendly labels

Recommended labels:

- `good first issue`
- `help wanted`
- `documentation`
- `validation`
- `ci`
- `swift`
- `safety`
- `privacy`
- `community`
- `design`

## Rule

Do not create broad vague issues. Prefer small issues that a contributor can finish in one PR.
