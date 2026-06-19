# ChatGPT Bot Control Note

Last updated: 2026-06-19

Use the private Brain control files as the source for scheduled ChatGPT slot behavior, but always re-read current iGentic project sources before reporting state or acting.

Primary local sources:

- `PROJECT_STATE.md`
- `docs/CHATGPT_NEXT_TASK.md`
- current iGentic issues and pull requests

Current active scheduler mode: `CONTINUOUS_10_SLOT_HOURLY`.

All ten cross-project slots run every hour. iGentic participates in the first half:

- 00 — cross-project director selects exactly one iGentic target and one separate Pokekartenkiste target.
- 06 — `IGENTIC_CONTEXT` verifies current source and creates one precise working question.
- 12 — `IGENTIC_PRODUCER` creates one verifiable artifact or an explicit waiting/owner result.
- 18 — `IGENTIC_REVIEWER` independently checks scope, diff, safety and current-head evidence; it does not implement.
- 24 — `IGENTIC_CLOSER` applies one exact fix or merges at most one fully gated PR.
- 54 — cross-project sequencer verifies the completed hour and selects the next focus without product mutation.

The shared rolling conversation bus is comment `4752404609` in `pokekarten/agentic-private-brain` issue #2. Each slot reads the previous same-cycle section, re-checks live repository truth, and updates only its own compact section. Detailed PR, issue, branch, head-SHA and validation truth stays in this repository.

Current local direction is always defined by `PROJECT_STATE.md`, `docs/CHATGPT_NEXT_TASK.md` and current GitHub evidence. Existing open PRs take priority over new candidates. Exactly one implementation candidate is allowed.

Safety and progress rules:

- current verified source overrides Brain and memory,
- no parallel PR or duplicate repository comment,
- producer-first: generic status does not count as progress,
- reviewer does not implement,
- closer does not merge with pending/failed checks, unsafe scope or unresolved threads,
- no speculative changes while a runner is queued or running,
- no networking, persistence, providers, App Intents, signing, model calls, secrets or real private data unless explicitly scoped by current project source,
- physical-device and owner settings remain owner-only boundaries,
- do not touch Pokekartenkiste files.

Each iGentic slot ends with the result shape defined by its active automation prompt. Do not claim Swift build/test success unless backed by a specific local run, current workflow run or user-provided evidence.
