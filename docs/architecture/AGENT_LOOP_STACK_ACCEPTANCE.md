# iGentic Agent Loop — reproducible pinned offline stack acceptance

**Scope:** Reviewer-owned, test-only composition of already open Draft
branches at the time of the original review. This does **not** deploy the private ChatGPT Site, merge to main,
access a phone, enable a transport, issue a device command or prove execution
of a Siri/ChatGPT task.

## Status on 2026-11-25

This is a historical stack reproducibility tool, not the acceptance
contract for the current consolidated integration branch (#436).
The eight pinned refs were checked again: six still matched, while
#416 moved to `eaf44d5375f347f093905e92d12b885a424b9c03` and #422
to `9f6f9b84118bbc0e2f4843cd5ad3c61d89db453b`. Both observed heads
are ancestors of integration commit `206e80868dea387494ffe873f91451a4161de208`.
The old manifest therefore correctly fails closed; it was not repinned.
Its 13 local contract tests passed. This does not rerun the historical
stack or replace current integrated CI and physical acceptance.

## Why this is necessary

Different iGentic chats are working concurrently on distinct components.
An earlier manual integration was difficult to replay and a branch could
change mid-test without the operator noticing. The very first run of this
reviewer exposed exactly that: PR #410 changed mid-check; instead of silently
merging different code, it stopped with a **pin mismatch**.

The standard-library-only verifier pins exact heads in the JSON manifest
at scripts/agent_loop_stack_manifest.json. Its isolated temporary clone
starts with #420 (signed delivery marker and #417 lineage) and folds in,
in order, #414 (SQLite replay integrity), #416 (Swift cryptographic
verification), #410 (read-only ChatGPT Site/MCP controls), #421 (native
two-turn read-only loop), #423 (in-memory status expiry), #422 (persisted
Shortcuts two-turn App Intents) and #424 (cross-invocation locking for
Shortcuts AI exchange). Parent PRs, including #409, are included by
Git ancestry. The manifest is deliberately NOT rewritten to latest:
new heads require review and manual SHA repinning.

The verifier checks exact branch heads before merging, reports conflicting
file paths if a merge fails, validates repository structure, runs selected
Node checks for SQLite, write-ahead, crypto parity and the read-only Site,
and deletes its isolated clone when finished. The synthetic composition is
never pushed anywhere.

## Commands

From a clone with read-only access to the repository:

    python3 -m unittest discover -s scripts -p test_verify_agent_loop_stack.py
    python3 scripts/verify_agent_loop_stack.py --mode heads
    python3 scripts/verify_agent_loop_stack.py --mode merge
    python3 scripts/verify_agent_loop_stack.py --mode quick
    python3 scripts/verify_agent_loop_stack.py --mode full
    python3 scripts/verify_agent_loop_stack.py --mode full-ios

Heads mode checks **all** current remote refs, prints the full set of drifted
or unverifiable PRs and exits nonzero without even cloning; this prevents one
stale ref from hiding additional parallel changes. Every other mode executes
the same fail-closed preflight before entering the disposable clone, and the
composition independently rechecks fetched SHAs against ref movement.
These are read-only network lookups to the Git remote, **not** an offline
GitHub-free run. Do not automatically update a pin to make this step pass.

Merge mode verifies heads and structure. Quick mode additionally executes
cross-PR Node security tests. Full mode installs the existing plugin
dependencies and runs all serial Node and Swift package unit tests.
Full-ios adds an unsigned generic **iOS Simulator app build of the same
integrated source** (Xcode required, no simulator launch or App Intents
system dispatch). Full and full-ios may fetch standard npm dependencies
but use NO paid or model OpenAI API. They do not contact a real iPhone.

This historical test tool originated in integration PR #395.
Source conflicts, missing branches and stale SHAs are real failures;
do not add an allow-drift bypass.

## Remaining gates

A PASS is source-level compatibility for that *exact pinned version set*.
It is not proof of Keychain device enrollment, native task receiver,
foreground polling, actual physical action, an independent action receipt,
cellular connectivity, installed ChatGPT Site tools or continuity of a
ChatGPT Project conversation.

The iPhone was unavailable via both Wi-Fi and USB-C during this work.
Actual hardware and private-Site acceptance remain distinct release gates
tracked in GitHub issue #418. Never promote offline test success to
actionExecuted=true or an automatic retry after uncertain delivery.

## Concurrency, coverage and governance

A passing run means exactly the pinned immutable commits passed, **not**
that each moving upstream branch is still at that head later. GitHub
updates during the initial fetch/merge phase are rejected; new heads must
be reviewed and repinned, then the combined tests rerun.

The eight-way check exercises the owner's native two-turn status logic
and persistent, crash-conservative App Intent journal as Swift package
code. The Node checks cover MCP contract, signed admission, durable
replay, write-ahead marker and simulated receipt parity. Native iOS
signing/Keychain provisioning, separately configured Siri/Shortcuts
execution, ChatGPT Project-chat continuity, a genuine authenticated
Site-to-device transport and physical-device attestation remain
**unverified** in the historical composition. Never promote synthetic receipts
to confirmed physical execution.
