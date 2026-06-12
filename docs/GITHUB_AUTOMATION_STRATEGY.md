# GitHub Automation Strategy

This repository uses a conservative GitHub-control layer so ChatGPT can review repository state from generated reports when direct connector access to every GitHub Actions view is incomplete.

## Architecture

```text
GitHub Actions + gh CLI + Python standard library
  -> latest repo-state JSON
  -> latest CI-runs JSON
  -> latest control-report Markdown
  -> GitHub Actions job summary
  -> ChatGPT review
```

The automation is read-only. It collects metadata, renders a Markdown report and exposes the report through the workflow job summary. Generated report files are not committed back to `main` in this first version.

## What ChatGPT can inspect through generated reports

The Control Dashboard report gives ChatGPT a compact review snapshot of:

- current workflow commit and GitHub event context,
- latest repository commits,
- recent GitHub Actions workflow runs,
- failed, cancelled, timed-out or action-required workflows,
- open pull requests,
- open issues,
- a conservative recommended next action.

This is useful when a connector session can read repository files and PRs but cannot directly list all Actions runs reliably.

## What remains manual

The following items remain manual repository-owner responsibilities:

- branch protection settings,
- repository settings,
- GitHub social preview configuration,
- required status-check configuration,
- secret and environment-variable management,
- deciding when a validation issue can be closed,
- merging pull requests.

## Safety boundaries

The control layer must stay within these boundaries:

- no automatic push,
- no automatic commit of generated reports,
- no automatic merge,
- no workflow rerun, cancellation or dispatch from the collector scripts,
- no secrets in reports,
- no private data in reports,
- no runtime app behavior changes,
- no model calls,
- no external providers,
- no code generation from GitHub issue or pull request text.

Issue and pull request text may be summarized for human review, but it must not be treated as executable instructions.

## Validation relationship

The Control Dashboard is not a replacement for Phase 0 validation. Required validation evidence remains:

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

Issue #1 must remain open unless those checks have actually run and the evidence is documented.
