# iGentic Community Strategy

Last updated: 2026-06-12

## Direction

The community strategy is **GitHub-first, social-supported**.

GitHub is the source of truth for decisions, roadmap, issues, pull requests, architecture records and community rules.

Social platforms are used for discovery, storytelling and recruitment. They are not used for binding technical decisions.

## Why GitHub-first

This project is about privacy, policy, local execution and controlled delegation. Those topics require durable, reviewable, source-linked decisions. A social thread is useful for attention, but not enough for governance.

## Channel roles

| Channel | Role | Decision authority |
| --- | --- | --- |
| GitHub Issues | Feature requests, bugs, design proposals, research tasks | Yes, after maintainer review |
| GitHub Pull Requests | Code, docs, assets, tests | Yes, after review |
| GitHub Discussions | Open questions, RFCs, community feedback | Advisory unless converted to issue/PR |
| Instagram | Visual storytelling, brand development, build-in-public | No |
| X | Short research notes, release links, developer discovery | No |
| LinkedIn | Longer professional updates, privacy/AI positioning | No |
| Discord | Later real-time contributor coordination | No by default |
| Email/security contact | Vulnerability reports and sensitive coordination | Security-only |

## Community promise

Contributors should understand:

1. what iGentic is,
2. what is safe to contribute,
3. where decisions happen,
4. how privacy constraints work,
5. how brand and IP boundaries work,
6. what is intentionally not accepted yet.

## First community audience

The first community should be narrow and high-quality:

- Swift/iOS developers,
- privacy/security reviewers,
- local LLM/runtime researchers,
- open-source maintainers,
- UX designers interested in consent and control flows,
- technical writers who can make the system understandable.

Avoid chasing a broad consumer audience before the architecture and safety model are mature.

## Contribution lanes

### Non-code

- improve docs,
- review design language,
- propose architecture diagrams,
- test README clarity,
- write source verification notes,
- create issue reproductions,
- improve social posts and explainers.

### Code

- tests for policy decisions,
- safe stubs,
- small Swift types,
- validation scripts,
- example synthetic data,
- diagnostic UI experiments.

### Research

- Apple API notes,
- local runtime comparisons,
- device test reports,
- privacy threat model refinements,
- App Intents safety reviews.

## Rules for healthy growth

1. Small PRs only until the project stabilizes.
2. No real private data in public issues or examples.
3. No model weights in the repo.
4. No signing/provisioning files.
5. No claims about iPhone performance without real device evidence.
6. No external AI delegation without policy notes.
7. Brand assets must follow `docs/brand/LOGO_USAGE.md`.

## First public message

> iGentic is an open-source experiment for local-first personal AI control. The iPhone track explores how trusted devices can route tasks, require approval, keep audit logs and delegate only when policy allows it. We are looking for careful contributors: Swift, privacy, local AI, UX and docs.

## Community success metrics

Early success is not follower count.

Good early signals:

- clear README comprehension,
- first outside issue with a useful proposal,
- first docs PR from a contributor,
- first device test report,
- first design feedback issue,
- first security/privacy review discussion,
- first small code PR that improves tests.

## Anti-goals

Do not build a hype community around unsafe autonomy.
Do not market iGentic as a finished assistant.
Do not imply Apple partnership.
Do not let social media outrank GitHub decisions.
Do not accept convenience over privacy policy.
