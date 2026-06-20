# iGentic Session Handoff

Issue #35 standardizes the smallest useful handoff for continuous iGentic work. Use this format when a cycle result needs to be handed to the next slot, PR reviewer or maintainer.

## Five-line handoff

```text
TARGET: <issue, PR or file scope>
EVIDENCE: <current source checked, including PR/issue numbers and head SHA when relevant>
ACTION: <one completed action or explicit no-write result>
RESULT: <terminal artifact such as PR_OPENED, ISSUE_UPDATED, WAITING_RUNNER or OWNER_BOUNDARY>
NEXT: <next slot or reviewer action>
```

## Rules

- Keep iGentic separate from Pokekartenkiste.
- Link to current GitHub issues, PRs or files instead of copying private raw context.
- For open PRs, include the latest head SHA before gate or merge decisions.
- Record only privacy-safe evidence; never include secrets, environment dumps, signing material, device identifiers or private user data.
- Prefer a no-write result over speculative fixes when workflow runs are queued or the exact failure is not known.

## Example

```text
TARGET: #35 session handoff process
EVIDENCE: open issue #35 acceptance criteria; no Swift/runtime scope
ACTION: added docs/SESSION_HANDOFF.md as process-only guidance
RESULT: PR_OPENED
NEXT: review docs-only scope and run repository structure validation
```
