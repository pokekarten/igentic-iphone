# API-free offline delivery write-ahead marker

**Scope:** This is a local, optional, synchronous safety gate used by the
transport-neutral iGentic agent-loop prototype. It does not send a task,
contact iOS, execute Siri/App Intents, call ChatGPT, or report device success.

## What it solves

Before a future transport adapter receives any prepared read-only task,
the local agent loop can synchronously reserve a per-task marker. If the
process crashes after this reservation but before recording a transport
outcome, another process sees `outcome-unknown` and MUST NOT retry the
same task automatically. To be conservative, even a crash before the
actual first send is classified as possibly delivered.

The marker is a new, empty 0600 file named using a domain-separated
HMAC-SHA256 digest of the task UUID. Only existence matters. The request
UUID, nonce, secret, route, private prompt and any device identifiers are
never persisted in marker contents or filename. A private owner-owned
0700 directory is required, and it must already exist. Marker creation
uses O_EXCL and O_NOFOLLOW; the marker and directory are fsynced before
any delivery payload is returned. Two concurrent local writers cannot
reserve the same request.

## Optional explicit wiring

```js
import {randomBytes} from 'node:crypto';
import {mkdtempSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createPrivateDeliveryAttemptMarker}
  from './src/delivery-attempt-marker.mjs';
import {createTransportNeutralAgentLoop}
  from './src/agent-loop-protocol.mjs';

const directory = mkdtempSync(join(tmpdir(), 'igentic-test-only-'));
const key = randomBytes(32); // synthetic test key, never an actual enrollment
const deliveryAttemptMarker = createPrivateDeliveryAttemptMarker({
  directory, key
});
const loop = createTransportNeutralAgentLoop({
  admission: trustedReadOnlyAdmission, // separately enrolled and replay-safe
  receiptKey: deviceReceiptVerificationKey, // separate owner-approved key
  deliveryAttemptMarker
});
// The task is still only a prepared proposal, not a command.
```

In production the key must be enrolled and securely stored. Do not
derive it from an API key, an LLM conversation, or the cellular
readiness-only secret. Only the trusted local transport adapter may
receive the delivery preparation.

## Failure and recovery rules

- If marker creation or durability fails, `prepareDelivery` throws
  before returning any payload to a transport adapter. No attempt
  counter increments and the loop remains pending. A marker that was
  partially created must be treated as committed/uncertain, not erased.
- If `recover({requestId})` finds a marker after a crash, it returns
  `outcome-unknown`, `automaticRetryAllowed: false`,
  `actionExecuted: false`, `ownerApproved: false`,
  `iPhoneConnected: not-checked`, `deviceReceipt: none`.
  This is a conservative local observation **not a device receipt**.
- A missing marker does not prove that the task was never sent.
  The separate durable owner-admission replay ledger must still be
  checked. An owner/OS attacker who can delete or roll back both
  marker directory and replay ledger is outside this local prototype's
  trust boundary.
- Markers deliberately are not automatically expired, deleted or
  released. A manual, audited reconciliation workflow is required.
  No automatic resend after timeout, stop or restart.
- This only works for a single trusted local filesystem and one OS
  owner. Multi-host/distributed deployment requires a shared,
  transactional and anti-rollback-safe durable state store.

Crucially, the current test harness simulates all deliveries.
A successful marker is **not** proof of iPhone reachability,
readiness, owner consent or action execution. The existing private
Sites plugin remains navigation-only and is unchanged by this PR.

## Offline validation

`cd plugins/iphone-connect && npm test`

Focused tests exercise simulated process restarts, duplicate concurrent
marker reservations, corrupted/unsafe inputs, filesystem security,
recovery classification, and absence of any transport action.
Physical USB-C, WLAN, cellular, Siri, Shortcuts and live app acceptance
remain open for future device-connected testing.
