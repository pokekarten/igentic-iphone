# Public Repo Setup

This checklist captures the GitHub setup that makes the repository easier to run as a public open-source project.

## Already present

- Public repository visibility
- Apache 2.0 license
- README landing page
- Contribution guide
- Code of conduct
- Support file
- Governance file
- Community strategy
- Good-first-issue backlog
- Issue templates
- Pull request template
- GitHub Actions validation workflow
- Validation contract
- GitHub control runbook
- Dependabot configuration for GitHub Actions

## Recommended GitHub UI settings

### Branch protection for `main`

- Require a pull request before merging.
- Require status checks before merging.
- Require the Phase 0 validation workflow to pass.
- Do not allow force pushes.
- Do not allow branch deletions.

### Community features

- Add repository topics such as `iphone`, `swift`, `privacy`, `ai-agent`, `local-first`, `open-source`, `automation`.
- Add a short repository description.
- Set a social preview image after final brand asset review.
- Enable Discussions only after repeated community questions appear.

## Operating rules

- GitHub is the source of truth.
- Issues describe work.
- Pull requests describe changes.
- Actions provide validation evidence.
- `PROJECT_STATE.md` records the actual state.
- `docs/CHATGPT_NEXT_TASK.md` records the next controller task.
- `docs/VALIDATION.md` defines when validation is complete.

## Next setup tasks

1. Verify the latest `main` commit through GitHub Actions or local commands.
2. Close Issue #1 only after validation evidence is documented.
3. Configure `main` branch protection in the GitHub UI.
4. Convert selected good-first-issue backlog items into real public issues.
5. Add repository topics and a short description.
