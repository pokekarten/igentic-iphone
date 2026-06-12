# Contributing to iGentic iPhone

Thank you for your interest in iGentic iPhone.

This project explores a privacy-first iPhone AI Runtime Layer. It is an experimental research prototype, not a production AI assistant. Security, privacy, auditability and user approval come before autonomy.

## Start here

New contributors should read:

- `docs/community/CONTRIBUTOR_STARTER_GUIDE.md`
- `docs/community/GOOD_FIRST_ISSUES.md`
- `ROADMAP.md`
- `GOVERNANCE.md`
- `SECURITY.md`

If you want to contribute visuals, also read:

- `docs/brand/BRAND.md`
- `docs/brand/DESIGN_SYSTEM.md`
- `docs/brand/LOGO_USAGE.md`

## Project principles

Contributions should follow these principles:

1. Local-first behavior before cloud delegation.
2. Privacy policy before runtime expansion.
3. Auditability before automation.
4. Draft before execute.
5. Small pull requests before large rewrites.
6. Real device evidence before iPhone performance claims.
7. GitHub decisions before social media discussion.

## Good first contributions

Good first contributions include:

- documentation improvements,
- tests for `PolicyEngine`, `AuditLog`, `TaskRouter` and `AgentKernel`,
- safe stubs for future runtime components,
- source verification notes,
- issue triage and reproducible test reports,
- logo/design refinements that follow the brand rules,
- social post drafts that point back to GitHub.

Avoid starting with:

- model weights,
- external AI provider integrations,
- App Store configuration,
- signing or provisioning files,
- real private user data,
- broad architecture rewrites,
- production-readiness or performance claims without evidence.

## Development workflow

1. Open an issue or comment on an existing one.
2. Keep the proposed change small and focused.
3. Create a branch with a descriptive name.
4. Add or update tests when behavior changes.
5. Run validation before opening a pull request.
6. Open a pull request with a clear privacy and security note.

Recommended validation:

```bash
python scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

## Pull request expectations

Every pull request should explain:

- what changed,
- why it changed,
- which data classes are touched,
- whether approval behavior changes,
- whether delegation behavior changes,
- how it was validated,
- what remains intentionally out of scope.

Use `.github/PULL_REQUEST_TEMPLATE.md`.

## Privacy and data handling

Do not commit:

- secrets,
- tokens,
- `.env` files,
- certificates,
- provisioning profiles,
- logs with private data,
- real user messages,
- contacts,
- calendars,
- health data,
- financial data,
- model weights,
- build artifacts.

If a contribution requires sample data, use synthetic examples only.

## Coding style

- Use English file names and code comments.
- Keep Swift types small and focused.
- Prefer explicit policy decisions over implicit behavior.
- Keep public APIs stable unless there is a clear reason to change them.
- Add tests for security-sensitive behavior.
- Keep validation dependency-free unless there is a strong reason.

## Design style

- Keep the brand calm, precise and privacy-first.
- Do not use Apple logos, iPhone outlines, Dynamic Island shapes or Apple-owned campaign styling.
- Prefer diagrams and policy states over generic AI hype.
- Include accessibility metadata in SVG assets where possible.
- Treat design proposals as project artifacts, not disposable marketing.

## Agent and Codex usage

Codex and other coding agents must follow `AGENTS.md`, `PROJECT_STATE.md` and the active task file. Broad unsupervised agent work is not accepted.

## License

By contributing, you agree that your contribution is licensed under this repository's license. Brand and logo usage must also follow `docs/brand/LOGO_USAGE.md`.
