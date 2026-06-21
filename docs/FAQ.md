# Frequently Asked Questions

## Is iGentic a finished app?

No. iGentic iPhone is an experimental research prototype for a privacy-first iPhone AI runtime layer. It is not a production assistant, medical device, financial system, legal advisor or identity wallet.

## Does iGentic automatically send my data to external AI services?

No. Local-only behavior is the default research mode. Private raw data must not be sent to external models automatically. Any future external delegation must be explicit, minimized, policy-checked, approval-gated and auditable.

## What does “approval-gated” mean?

Critical actions must wait for explicit user approval before execution. The project prefers drafting and previewing over immediately sending, changing or executing something.

## What does “controlled delegation” mean?

Larger work may eventually be delegated to trusted devices or external AI only when policy allows it. Delegation should minimize and redact data, preserve local control and record a useful audit trail without turning logs into private-data dumps.

## Why is GitHub the source of truth?

GitHub is the canonical place for project decisions, issues, pull requests, validation evidence and roadmap changes. Social channels may explain progress or help people discover the project, but they do not replace repository records.

## Can I contribute without Swift experience?

Yes. Useful contributions include documentation improvements, source-verification notes, issue triage, reproducible test reports, design work that follows the brand rules and social drafts that link back to GitHub.

Start with:

- `CONTRIBUTING.md`
- `GOVERNANCE.md`
- `SECURITY.md`
- `ROADMAP.md`
- `docs/community/CONTRIBUTOR_STARTER_GUIDE.md`
- `docs/community/GOOD_FIRST_ISSUES.md`

## Why are model weights not committed?

Model weights are intentionally outside this repository’s current scope. The repository focuses on architecture, policy, safety controls, validation and small reviewable runtime components. Candidate models are evaluated separately, and no model weights should be added in a normal contribution.

## Why is social media not a decision authority?

Instagram, X and LinkedIn are discovery and build-in-public channels. Actionable decisions, feature proposals, code changes, security handling and roadmap updates belong on GitHub so they remain reviewable and traceable.

## What should not be posted in public issues or pull requests?

Do not post secrets, tokens, credentials, real user messages, contacts, calendars, health data, financial data, private logs, exploit details or privacy-sensitive proofs of concept. Use synthetic examples whenever possible.

For a sensitive security report, follow `SECURITY.md` and avoid publishing the sensitive details in a public issue.

## Does the project claim production or device readiness?

No. Real iPhone testing is required before making device-performance or usability claims. Missing production deployment, signing, App Store configuration or full model integration are expected limitations at this stage.

## Where should I ask questions or propose changes?

Use GitHub Issues for bugs, questions, research tasks and feature proposals. Use pull requests for small reviewable changes. Keep the project’s experimental status, privacy rules and stop conditions explicit.
