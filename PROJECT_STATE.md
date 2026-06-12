# Project State

Last updated: 2026-06-12

## Current status

`iGentic iPhone` is being initialized as an open-source, privacy-first iPhone AI Runtime Layer repository.

The repo is now controlled directly through GitHub instead of relying only on ZIP download/upload loops.

## Current baseline

- Repository: `pokekarten/igentic-iphone`
- Visibility: public
- Controller: ChatGPT via GitHub Connector
- Implementation assistant: Codex through small Draft PRs only
- Primary target device: iPhone Air as trust/control plane
- Current phase: Phase 0 / Phase 1 bootstrap

## What exists now

- README with product vision and repo operating model
- `AGENTS.md` with ChatGPT/Codex/iPhone tester rules
- `docs/CODEX_NEXT_TASK.md` as the single next-task handoff
- GitHub issue templates for feature, model and security reviews
- Placeholder import work is being replaced with real tracked files

## What still needs bootstrapping

- Complete Swift Package skeleton under `ios/`
- Architecture docs from the verified v3 package
- Repo validation script
- Source verification and sparsamkeit docs
- Initial CI verification after the first full Swift package commit

## Important constraint

The GitHub Connector can edit repository files, but it does not directly upload and extract ZIP archives. Therefore repository bootstrapping should happen as either:

1. direct file commits through the connector,
2. a narrow Codex Draft PR that imports the verified ZIP locally,
3. manual local push from the verified ZIP.

## Current next task

See `docs/CODEX_NEXT_TASK.md`.

## Review owner

ChatGPT reviews all Draft PRs before merge.
