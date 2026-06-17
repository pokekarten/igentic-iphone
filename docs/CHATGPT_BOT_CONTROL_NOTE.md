# ChatGPT Bot Control Note

Last updated: 2026-06-17

Use the private Brain control files as the source for scheduled ChatGPT slot behavior, but always re-read current iGentic project sources before reporting state or acting.

Primary local sources:

- `PROJECT_STATE.md`
- `docs/CHATGPT_NEXT_TASK.md`
- current iGentic issues and pull requests

Current active scheduler mode: `PRODUCTIVE_SIX_SLOT_CYCLE`.

Applicable iGentic slots in this mode:

- 06 — `IGENTIC_GATE`: review/gate exactly one iGentic PR, issue or task.
- 12 — `IGENTIC_PROGRESS`: produce one concrete iGentic progress result, exact handoff, PATCH_READY, BEN, or next unblocked task.

Slot 18 is no longer an iGentic slot in the active product cycle; it is currently the Pokekartenkiste gate slot. Older full-slot/debug mappings are background only unless Brain `CURRENT_STATE.md` and automation source explicitly switch modes again.

Current local direction:

- Keep PR #36 docs-only and not merge-ready while Draft or stale.
- Continue the visual/documentation-only carousel proof from `docs/CHATGPT_NEXT_TASK.md` only if it avoids PR #36 files and does not touch Swift/runtime/workflow code.

Each run should read current repository sources first, keep project context separate, avoid overlapping edits, and end with the active prompt's result shape (`IGENTIC_GATE` or `IGENTIC_PROGRESS`). Do not claim Swift build/test success unless backed by a specific local run, workflow run, or user-provided evidence.
