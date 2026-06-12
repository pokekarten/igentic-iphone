# iGentic Governance

Last updated: 2026-06-12

## Status

iGentic is currently maintainer-led while the project is in early research and safety bootstrap.

This governance model is intentionally lightweight. It should become more formal only after there are repeated external contributors and active maintainership needs.

## Source of truth

GitHub is the source of truth for:

- roadmap,
- issues,
- pull requests,
- architecture decisions,
- community rules,
- brand and logo rules,
- security policy,
- project state.

Social media is not a decision authority.

## Maintainer responsibilities

Maintainers are responsible for:

- protecting privacy-first principles,
- reviewing security and policy impact,
- keeping docs current,
- keeping contribution paths clear,
- avoiding unsafe autonomy claims,
- enforcing code of conduct,
- protecting the iGentic identity from confusing use.

## Contributor responsibilities

Contributors should:

- keep changes small,
- use synthetic data only,
- explain privacy impact,
- add or update tests when behavior changes,
- follow `CONTRIBUTING.md`, `SECURITY.md` and `docs/brand/LOGO_USAGE.md`,
- avoid unsupported performance or platform claims.

## Decision process

### Small changes

Small documentation, test and safe stub changes can be decided in pull request review.

### Design changes

Logo, brand, UX and social changes should use design feedback issues or focused pull requests.

### Architecture changes

Architecture changes that affect privacy, approval, delegation or data classification need:

1. a clear issue,
2. scope and anti-goals,
3. privacy impact note,
4. test plan,
5. maintainer review.

### Security-sensitive changes

Security-sensitive changes need extra caution and may be blocked until the threat model is updated.

## Roles

### Maintainer

Can merge pull requests, update roadmap, manage issues and represent the project publicly.

### Contributor

Can open issues, pull requests, design proposals, research notes and test reports.

### Reviewer

Can provide review feedback on docs, design, privacy, security, tests or device behavior.

### Community participant

Can ask questions, suggest improvements and share the project while respecting the code of conduct.

## Commit and merge rules

- Prefer small PRs.
- Prefer squash or rebase when it keeps history clear.
- Do not merge broad changes without a linked issue or roadmap entry.
- Do not merge code that introduces real private data, secrets or model weights.
- Do not merge external delegation behavior without policy and approval notes.

## Codex and agent usage

Coding agents may be used only for narrow, reviewable tasks.

Agent-produced changes must still be reviewed like human-produced changes. The maintainer is responsible for the final merge decision.

## Brand governance

The code is open source under the repository license, but the iGentic name and logo must remain clear and non-confusing.

See:

- `docs/brand/BRAND.md`
- `docs/brand/LOGO_USAGE.md`
- `docs/brand/LOGO_BRIEF.md`

## When to update this file

Update this governance model when:

- a second active maintainer is added,
- GitHub Discussions are enabled,
- Discord or another real-time channel becomes official,
- the first public release is tagged,
- brand or trademark rules need more precision,
- community moderation needs increase.
