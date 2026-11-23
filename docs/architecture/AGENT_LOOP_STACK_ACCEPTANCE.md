# iGentic Agent Loop — reproducible pinned offline stack acceptance

**Scope:** Reviewer-owned, test-only composition of already open Draft
branches. This does **not** deploy the private ChatGPT Site, merge to main,
access a phone, enable a transport, issue a device command or prove execution
of a Siri/ChatGPT task.

## Why this is necessary

Different iGentic chats are working concurrently on distinct components.
An earlier manual integration was difficult to replay and a branch could
change mid-test without the operator noticing. The very first run of this
reviewer exposed exactly that: PR #410 changed mid-check; instead of silently
merging different code, it stopped with a **pin mismatch**.

The standard-library-only verifier pins exact heads in the JSON manifest
at scripts/agent_loop_stack_manifest.json. Its isolated temporary clone
starts with #420 and folds in, in order, #414 (ledger integrity), #416 (Swift
crypto/replay boundary), #410 (read-only ChatGPT Site/MCP controls), and #421
(native two-turn loop on the #409 Shortcuts/Agent Home foundation). Parent
branches are included by ancestry. The manifest is deliberately NOT rewritten
to latest: new heads require review and manual SHA repinning.

The verifier checks exact branch heads before merging, reports conflicting
file paths if a merge fails, validates repository structure, runs selected
Node checks for SQLite, write-ahead, crypto parity and the read-only Site,
and deletes its isolated clone when finished. The synthetic composition is
never pushed anywhere.

## Commands

From a clone with authenticated read-only access to the private repository:

    python3 -m unittest discover -s scripts -p test_verify_agent_loop_stack.py
    python3 scripts/verify_agent_loop_stack.py --mode merge
    python3 scripts/verify_agent_loop_stack.py --mode quick
    python3 scripts/verify_agent_loop_stack.py --mode full

Merge mode verifies heads and structure. Quick mode also executes selected
cross-PR Node tests. Full mode installs existing plugin dependencies, runs
the complete serial Node suite and all Swift package unit tests. Full mode
may fetch npm dependencies but uses NO paid or model OpenAI API. It never
runs an iOS UI test or attempts to contact a real iPhone.

This test tool belongs only to existing Draft integration PR #395.
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
