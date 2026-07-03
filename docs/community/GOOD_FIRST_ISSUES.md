# Good First Issues

Last updated: 2026-06-27

This file lists safe starter tasks for new contributors. It is intentionally written as a backlog that can be converted into GitHub issues.

Status legend: `OPEN` means available for issue selection; `COMPLETED` means a canonical artifact already exists. Only source-verified completed entries are annotated below; unannotated entries are[...]

## Rules for all starter tasks

- Keep the change small.
- Use synthetic data only.
- Do not add external services.
- Do not add real model weights.
- Do not add persistence unless the task explicitly says so.
- Explain privacy impact in the PR.
- Update docs or tests when behavior changes.
- Before creating an issue from an `OPEN` entry, verify current repository files and open/closed issues and PRs.

## Documentation tasks

### 1. Add a glossary

**Status: COMPLETED — canonical artifact:** [`docs/GLOSSARY.md`](../GLOSSARY.md)

**Goal:** Create the project glossary at docs/GLOSSARY.md explaining project terms.

Include:

- Local Only
- Trusted Devices
- External AI
- Approval Gated
- Controlled Delegation
- Audit Log
- Data Classification
- Action Risk
- Synthetic Data

**Validation:** Manual docs review.

### 2. Improve architecture diagram text

**Goal:** Make the README architecture easier for first-time visitors.

Scope:

- README architecture section only,
- no runtime behavior change.

**Validation:** Manual docs review.

### 3. Add a FAQ

**Status: COMPLETED — canonical artifact:** [`docs/FAQ.md`](../FAQ.md)

**Goal:** Create docs/FAQ.md for common early questions.

Questions:

- Is this a finished app?
- Does it send my data to external AI?
- Why GitHub-first?
- Can I contribute without Swift?
- Why are model weights not committed?

**Validation:** Manual docs review.

## Design tasks

### 4. Refine the logo mark SVG

**Goal:** Improve `assets/brand/logo-mark.svg` while keeping the same concept.

Must keep:

- `i` identity,
- open `G` control ring,
- no Apple logo or iPhone outline,
- title and desc tags for accessibility.

**Validation:** Manual SVG review.

### 5. Create a monochrome logo SVG

**Goal:** Add `assets/brand/logo-mark-monochrome.svg`.

Requirements:

- one color,
- readable at small sizes,
- no gradients,
- title and desc tags.

**Validation:** Manual SVG review.

### 6. Create an Instagram carousel template

**Goal:** Add `assets/social/instagram-carousel-template.svg` or a markdown brief in `docs/community/`.

Content should follow `docs/community/SOCIAL_MEDIA_PLAYBOOK.md`.

**Validation:** Manual review.

## Test and validation tasks

### 7. Extend repo structure validation

**Goal:** Improve `scripts/validate_repo_structure.py`.

Ideas:

- require community docs,
- require brand docs,
- require SVG title/desc tags,
- warn on empty markdown files,
- keep checks dependency-free.

**Validation:** Run the repo-structure validation command.

### 8. Add policy edge-case tests

**Status: COMPLETED — canonical artifact:** [`ios/Tests/AgentCoreTests/PolicyEngineEdgeCaseTests.swift`](../../ios/Tests/AgentCoreTests/PolicyEngineEdgeCaseTests.swift)

**Goal:** Add smoke tests for edge cases in `PolicyEngine`.

Examples:

- Level 4 data blocks external delegation,
- critical actions require approval,
- local-only mode blocks external routing.

**Validation:** Run the Swift test command.

## Safe runtime tasks

### 9. Add MemoryStore safe stub

**Status: COMPLETED — canonical artifact:** [`ios/Sources/AgentCore/MemoryStore.swift`](../../ios/Sources/AgentCore/MemoryStore.swift) (tests in [`ios/Tests/AgentCoreTests/SmokeTests.swift`](../../ios/Tests/AgentCoreTests/SmokeTests.swift))

**Goal:** Add in-memory scoped memory without persistence.

Requirements:

- no embeddings,
- no file access,
- no real private data,
- delete by scope or id,
- tests for save/list/delete.

**Validation:** Run the Swift test command.

### 10. Add DelegationBroker policy-gated stub tests

**Status: COMPLETED — canonical artifact:** [`ios/Sources/AgentCore/DelegationBroker.swift`](../../ios/Sources/AgentCore/DelegationBroker.swift) (tests in [`ios/Tests/AgentCoreTests/SmokeTests.swift`](../../ios/Tests/AgentCoreTests/SmokeTests.swift))

**Goal:** Ensure delegation remains metadata-only and policy-gated.

Requirements:

- no networking,
- no external providers,
- no model calls,
- tests for local-only blocking and approval-required decisions.

**Validation:** Run the Swift test command.

## Research tasks

### 11. Add App Intents safety notes

**Status: COMPLETED — canonical artifact:** [`docs/app-intents-safety.md`](../app-intents-safety.md)

**Goal:** Create or extend a doc explaining safe App Intents patterns.

Focus:

- draft before execute,
- approval before critical action,
- synthetic examples only,
- no private data in docs.

**Validation:** Source-linked doc review.

### 12. Add device test checklist

**Status: COMPLETED — canonical artifact:** [`docs/device-test-checklist.md`](../device-test-checklist.md)

**Goal:** Create a checklist for real iPhone testing.

Include:

- device model,
- iOS version,
- commit tested,
- scenario,
- privacy notes,
- expected behavior,
- result.

**Validation:** Manual docs review.

## Social/community tasks

### 13. Draft first Instagram carousel

**Goal:** Create a text-only carousel draft for the first public post.

Topic:

> The trusted device should control identity, permissions and auditability.

**Validation:** Follow `docs/community/SOCIAL_MEDIA_PLAYBOOK.md`.

### 14. Draft first LinkedIn announcement

**Goal:** Create a professional launch/update draft.

Must include:

- experimental status,
- GitHub-first community model,
- contributor types wanted,
- no production-ready claims.

**Validation:** Manual review.

## How to convert one into a GitHub issue

Use a short issue title, for example:

```text
Good first issue: Add glossary for privacy and runtime terms
```

Use the relevant issue template and include:

- scope,
- affected files,
- stop rules,
- validation target.
