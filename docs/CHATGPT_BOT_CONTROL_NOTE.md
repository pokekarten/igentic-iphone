# ChatGPT Bot Control Note

Last updated: 2026-06-14

Use the private Brain control files as the source for scheduled ChatGPT slot behavior.

Primary local sources:

- `PROJECT_STATE.md`
- `docs/CHATGPT_NEXT_TASK.md`

Applicable slots:

- 06 source scan
- 12 review gate
- 18 micro-step

Each run should read current repository sources first, keep project context separate, avoid overlapping edits, and end with the Brain-defined `BOT_RESULT` block.
