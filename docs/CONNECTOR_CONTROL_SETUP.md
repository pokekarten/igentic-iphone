# Connector Control Setup

This document defines what is needed so ChatGPT can control and review the project as effectively as possible through GitHub.

## What ChatGPT can already do

ChatGPT can already use the GitHub Connector to:

- read repository files,
- update repository files,
- create focused documentation and workflow changes,
- inspect repository metadata,
- inspect issues and pull requests,
- review pull request diffs,
- inspect workflow jobs and logs when a workflow run ID or job ID is known,
- document validation state in project files.

## What still needs external setup

Some controls are repository settings or GitHub API surfaces that are not currently exposed as direct connector actions.

### GitHub UI settings

Configure these manually in GitHub:

- Branch protection for `main`.
- Required pull request before merge.
- Required status checks before merge.
- No force pushes on `main`.
- No branch deletion on `main`.
- Repository description and topics.
- Social preview image after brand review.

### Useful connector/API capabilities

The project would be easier to control if the connector exposed these actions:

- list latest workflow runs for a repository,
- list workflow runs filtered by branch, event, status or commit,
- dispatch a workflow on a chosen ref,
- list latest commits on a branch,
- inspect branch protection settings,
- update branch protection settings,
- list repository workflows,
- inspect check runs for a ref.

## Current best working mode

Until those capabilities exist directly, use this workflow:

1. ChatGPT edits files, workflows, docs, issues and PRs through GitHub.
2. Ben starts manual workflows in GitHub UI when needed.
3. Ben provides the workflow run link or run ID.
4. ChatGPT inspects jobs, steps and logs through the connector.
5. ChatGPT documents the result in `PROJECT_STATE.md` and `docs/CHATGPT_NEXT_TASK.md`.

## Manual workflow trigger path

Use GitHub UI:

1. Open the repository.
2. Go to Actions.
3. Select `Phase 0 CI Validation`.
4. Choose `Run workflow`.
5. Select `main`.
6. Start the run.
7. Copy the run URL back to ChatGPT.

## Validation gate

Issue #1 may only be closed when the required validation evidence exists for the relevant current repository state.

Required validation evidence:

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

## Goal

The goal is not unlimited automation. The goal is controlled automation with traceable evidence, small diffs, public reviewability and strong privacy boundaries.
