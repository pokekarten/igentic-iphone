# Offline persistent replay ledger (single Mac, proposal-only)

This optional capability **builds on** the read-only signed envelope in
[AUTHENTICATED_TASK_ENVELOPE.md](AUTHENTICATED_TASK_ENVELOPE.md). It provides
restart-resistant replay checks without needing an iPhone, OpenAI API, hosted
Site, Apple permissions, or a device-control daemon.

## Separation of duties

- `prepareSignedReadOnlyProposal`: prepares a HMAC-signed proposal with the
  sole capability `igentic.own_app.status.read`, a fresh UUID and <= 60s TTL.
- `provisionPrivateReplayLedger`: one-time **explicit local** initialization
  in a pre-existing OS-user-owned 0700 directory, using a separate
  owner-relay key (32 bytes). Creates an exclusive 0600 SQLite file with a
  key-bound integrity seal. It is not run automatically on startup.
- `createDurableOwnerProposalAdmission`: verifies the signature and strict
  schema, then atomically records a keyed digest of the request UUID in
  local SQLite. Existing unexpired digests, forged payloads and excess
  outstanding proposals are rejected.
- On successful admission, **only**
  `state: authenticated-proposal-only`,
  `iPhoneConnected: not-checked`,
  `ownerApproved: false`,
  `actionExecuted: false`,
  `deviceReceipt: none` are returned. There is no execution layer.

### Local example (no secrets supplied here)

```js
import { randomBytes } from 'node:crypto';
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { prepareSignedReadOnlyProposal }
  from './src/authenticated-task-envelope.mjs';
import {
  provisionPrivateReplayLedger, createDurableOwnerProposalAdmission
} from './src/durable-task-admission.mjs';

const key = randomBytes(32); // ephemeral TEST key, not enrollment
const dir = mkdtempSync(join(tmpdir(), 'igentic-test-ledger-'));
const databasePath = join(dir, 'ledger.sqlite');
provisionPrivateReplayLedger({ key, databasePath }); // exactly once
const verifier = createDurableOwnerProposalAdmission({ key, databasePath });
const proposal = prepareSignedReadOnlyProposal({
  key, issuedAt: Math.floor(Date.now() / 1000)
});
const result = verifier.admit(proposal);
// result.actionExecuted === false; result.deviceReceipt === 'none'
verifier.close();
```

Never use a generated demo key as a production identity. Real enrollment
must store the per-owner secret in a platform-native secure store; never in
code, logs, Git, model prompts, URLs, tool results, command arguments, or
environment variables.

## Fail-closed and recovery semantics

A database must exist before admission begins. If it is missing, replaced,
not private, symlinked, wrong-key sealed, truncated or otherwise corrupt,
admission fails. It does **not** silently reinitialize a missing database;
explicit provisioning to an existing path is rejected. Manual recovery must
first investigate whether an earlier proposal may have been accepted. Losing
the database loses the replay history: do not automatically generate a fresh
one and claim continuity.

The local SQLite transaction uses `BEGIN IMMEDIATE` to serialize concurrent
writers across processes using the same filesystem, with FULL synchronous
journal commits. It prunes expired rows on later admitted requests and
limits active rows (default 256, configurable up to 1024). Only keyed digests
and expiry times are stored, never tasks, credentials, private text,
signatures or raw device IDs.

## Explicit limitations / next security gates

This is **single-host** durability, not global replay defense across Mac,
iPhone, multiple cloud instances, shared network filesystems or restored
backups. There is no distributed consensus, secure boot, anti-rollback
attestation, transport authentication, revocation, account enrollment,
external authorization or device receipt. File deletion/replacement by
someone who controls the OS account and has access to a live key is beyond
this standalone module's security boundary. Human approval is still absent.

Do not wire it into the publicly accessible Site Worker or enable remote
commands based on this alone. Production design requires independently
reviewed owner/device enrollment, secret rotation, TLS and permissions,
a global replay store if distributed, idempotent dispatch with explicit
unknown-outcome states, and independent Apple-owned-device receipts.

No user iPhone connection or real ChatGPT model/tool callback has been
verified by this code. Local tests use synthetic keys, temporary private
folders and isolated test processes.
