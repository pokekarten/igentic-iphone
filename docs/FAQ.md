# iGentic FAQ

This FAQ answers early contributor and user questions about iGentic. It is intentionally plain-language and points back to the repository as the source of truth.

## Is this a finished app?

No. iGentic is an experimental research prototype. The repository is being built in small, reviewable slices so the safety model, documentation, and validation can stay ahead of product behavior.

## Does iGentic send my data to external AI?

The current repository should not be treated as a finished app or a live personal-data processor. Design and implementation work follows a privacy-first rule: do not add networking, external AI providers, model calls, persistence, secrets, or real private data unless a future reviewed issue explicitly allows that scope.

## Why is GitHub the source of truth?

GitHub issues, pull requests, workflow checks, and repository documentation provide the auditable project record. Decisions should be traceable to repository artifacts instead of private chat, social posts, or informal status updates.

## Can I contribute without Swift?

Yes. Helpful non-Swift contributions include documentation, issue triage, validation notes, workflow-safe examples, and contributor clarity improvements. Start with small issues that list exact files, validation, and stop rules.

## Why are model weights not committed?

Model weights are not committed because they can be large, sensitive, licensing-bound, or unsuitable for public repository history. The repository should document expected behavior and safe boundaries without embedding heavyweight or private model artifacts.

## Why is social media not a decision authority?

Social media can be useful for awareness, but it is not a durable project record. Project decisions, acceptance criteria, validation evidence, and follow-up work belong in GitHub issues, pull requests, and documentation.

## What does approval-gated mean?

Approval-gated means higher-risk behavior should not be added silently. Changes that could affect user data, external services, automation authority, or runtime behavior need explicit review scope and evidence before they are accepted.

## What does controlled delegation mean?

Controlled delegation means automated or assisted work must stay within the exact target, file scope, validation steps, and stop rules. It should not create parallel work, widen scope, or claim unobserved results.

## What should not be posted in public issues?

Do not post secrets, tokens, private messages, real personal data, proprietary model files, private datasets, device identifiers, signing credentials, or anything that would be unsafe to keep in public repository history.

## Where should contributors look next?

Use the README, issues, pull requests, and documentation in this repository. Prefer small, source-backed changes with clear validation steps and a narrow review surface.
