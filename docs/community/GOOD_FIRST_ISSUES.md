# Good First Issues

Last updated: 2026-06-12

This file lists safe starter tasks for new contributors. It is intentionally written as a backlog that can be converted into GitHub issues.

## Rules for all starter tasks

- Keep the change small.
- Use synthetic data only.
- Do not add external services.
- Do not add real model weights.
- Do not add persistence unless the task explicitly says so.
- Explain privacy impact in the PR.
- Update docs or tests when behavior changes.

## Documentation tasks

### 1. Add a glossary

**Goal:** Create `docs/GLOSSARY.md` explaining project terms.

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

**Goal:** Create `docs/FAQ.md` for common early questions.

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

**Validation:** `python scripts/validate_repo_structure.py`.

### 8. Add policy edge-case tests

**Goal:** Add smoke tests for edge cases in `PolicyEngine`.

Examples:

- Level 4 data blocks external delegation,
- critical actions require approval,
- local-only mode blocks external routing.

**Validation:** `cd ios && swift test`.

## Safe runtime tasks

### 9. Add MemoryStore safe stub

**Goal:** Add in-memory scoped memory without persistence.

Requirements:

- no embeddings,
- no file access,
- no real private data,
- delete by scope or id,
- tests for save/list/delete.

**Validation:** `cd ios && swift test`.

### 10. Add DelegationBroker policy-gated stub tests

**Goal:** Ensure delegation remains metadata-only and policy-gated.

Requirements:

- no networking,
- no external providers,
- no model calls,
- tests for local-only blocking and approval-required decisions.

**Validation:** `cd ios && swift test`.

## Research tasks

### 11. Add App Intents safety notes

**Goal:** Create or extend a doc explaining safe App Intents patterns.

Focus:

- draft before execute,
- approval before critical action,
- synthetic examples only,
- no private data in docs.

**Validation:** Source-linked doc review.

### 12. Add device test checklist

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
