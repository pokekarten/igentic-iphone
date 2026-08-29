# Safe Action Execution V0 — `createReminder`

Status: design decision — no execution code authorized by this document  
Issue: #335  
Repository baseline reviewed: `31be70ffa94809bf9baabf1d5bc7e731e08f4b24`  
Scope: one typed local side effect, `createReminder`

## Decision summary

The first real iGentic side-effect path should be `createReminder`, but the model, router, ToolRegistry, App Intent surface, EventKit permission state, and device authentication must never be execution authorities.

The V0 authority chain is:

```text
proposal
-> strict typed validation
-> CreateReminderDraft
-> effective classification
-> PolicyEngine
-> explicit ApprovalManager approval
-> one-shot CreateReminderExecutionCapability
-> CreateReminderExecuting.execute(...)
-> platform permission/preflight
-> at most one EventKit save attempt
-> metadata-minimized audit result
```

The first implementation must remain independently testable without a model or EventKit by using a deterministic synthetic proposal and a fake executor.

`createReminder` is selected because it already has a typed `TaskIntent`, a fixed local `TaskRouter` route, a Benchmark V0 proposal shape, and a ToolRegistry availability gate, while the repository deliberately has no tool invocation path yet. It is also narrower than sending messages, deleting records, exporting data, or delegating externally.

This document does **not** authorize EventKit imports, `EKReminder` creation, App Intents, Info.plist changes, signing changes, device permission requests, or any real side effect.

## Existing source boundary

Current AgentCore establishes these relevant facts:

- `TaskIntent.createReminder` is a typed intent.
- `TaskRouter` maps it to `.localTool(name: "createReminder", ...)` only after `AgentKernel` has completed deterministic policy and approval gates.
- `ActionRisk.execute` already requires approval.
- `ToolRegistry` validates typed tool presence but does not invoke tools.
- `AppActionCoordinator` demonstrates effective-classification and exact-draft receipt matching, but returns `Draft approved without execution.`
- `ApprovalReceipt` carries approval status, request identity, reason, and `mayContinueRouting`, but it is not a consumable execution token.
- Models and model selection remain advisory. They may propose; they do not authorize.

The existing generic `AppActionDraft` is not the execution request for this V0. Its action kinds and free-text summary shape were designed as a side-effect-free approval precursor. V0 uses a separate strongly typed reminder draft rather than adding execution semantics to generic summary strings.

## Non-negotiable invariants

1. No raw user/model text reaches EventKit.
2. A model proposal is never approval.
3. A TaskRouter route is never approval.
4. ToolRegistry presence is never approval.
5. RuntimeBudget, ModelSelection, MemoryStore, App Intent invocation, Siri/Shortcuts invocation, EventKit permission, or device authentication is never approval.
6. `createReminder` V0 always uses `ActionRisk.execute` and therefore always requires explicit approval.
7. The approval must bind the exact canonical draft that will execute.
8. An execution capability is one-shot and in-memory in V0.
9. Missing, stale, mismatched, already-consumed, or unapproved capability means no executor call.
10. Permission denial, cancellation, missing default reminder calendar, validation error, or executor preflight error means no EventKit save.
11. A successful executor performs at most one save attempt for one reminder.
12. Generic audit messages never contain the reminder title or due time.

## 1. Canonical typed draft

The implementation slice should introduce a dedicated value type with an API shape equivalent to:

```swift
public struct CreateReminderDraft: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let due: ReminderDueDate
    public let dataClassification: DataClassification
    public let actionRisk: ActionRisk
    public let toolName: String
}
```

V0 invariants:

- `toolName` is exactly `createReminder` and is not caller-selectable after typed validation.
- `actionRisk` is exactly `.execute` and cannot be lowered by proposal/model input.
- `title` is trimmed and must be non-empty after trimming.
- No notes, URL, location, recurrence, priority, tags, attachments, contacts, list identifier, or alarm offset are in V0.
- The target is the user's EventKit default reminders calendar. V0 does not accept a model-supplied list name or calendar identifier.

### Typed due date

Natural-language time parsing belongs before the execution boundary. The executor receives resolved, deterministic date components.

Use a value shape equivalent to:

```swift
public struct ReminderDueDate: Equatable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int
    public let hour: Int
    public let minute: Int
    public let timeZoneIdentifier: String
}
```

Validation must reject impossible calendar values, unknown time zones, and unresolved/ambiguous natural-language phrases. The canonical fingerprint representation uses numeric fields and the IANA time-zone identifier, not a locale-formatted display string.

The future EventKit adapter may construct `DateComponents` from these validated fields. Display formatting is separate from fingerprinting.

## 2. Proposal -> validation -> draft boundary

Define a model-independent proposal envelope for this action with exactly these action arguments:

```json
{
  "tool": "createReminder",
  "arguments": {
    "title": "...",
    "time": "..."
  }
}
```

The model-facing Benchmark V0 can continue to use strings. A deterministic proposal adapter must resolve that proposal into the typed execution draft before policy/approval.

The adapter must:

- allow only the fixed tool identity `createReminder`;
- allow only known argument keys;
- reject invented keys rather than silently ignore them;
- require non-empty `title`;
- require an unambiguous resolved due date before creating the executable draft;
- return clarification for missing or ambiguous values;
- reject invalid schema/types;
- never inspect Benchmark expected-answer fields at runtime;
- never use model confidence as authority.

A deterministic synthetic proposal must be sufficient to drive every V0 safety test. No model baseline is a prerequisite for the executor contract.

## 3. Effective classification

The reminder draft must carry an effective classification that cannot be lowered after policy evaluation.

V0 classification procedure:

1. Start from the caller/task classification.
2. Apply a conservative floor of `.contextualPrivateData` because a reminder is user-context stored in a personal reminders database even when its title looks benign.
3. Run the repository-required sensitive-data detection over the normalized reminder title.
4. Compute the highest level among caller classification, the reminder floor, and detector result.
5. Freeze that level into both the canonical draft fingerprint and execution capability.

The due date is structured metadata rather than free text and is not passed through the regex detector. It is nevertheless protected by the draft's effective classification and must not appear in generic audit messages.

If later research changes the reminder classification floor, that must be a separate policy decision with regression tests. The executor may never lower the already-computed effective classification.

## 4. Risk and approval semantics

V0 reminder creation is always:

```text
actionRisk = execute
requestedDelegationTarget = localDevice
```

Under the current `ActionRisk` contract, `.execute` requires approval. V0 therefore does not have a no-approval execution mode.

This is intentional even for simple reminders. It creates the first real action path with the strictest easy-to-explain contract: every real reminder side effect has one fresh approval bound to one exact draft.

A later issue may study a user-configurable lower-friction policy only after real-device evidence exists. That later policy must still preserve a non-lowerable safety floor.

## 5. Execution capability

`ApprovalReceipt` and `AppActionApprovalReceipt` are authorization evidence, but V0 needs a separate consumable execution capability so an approved draft cannot be replayed indefinitely.

Use an API shape equivalent to:

```swift
public struct CreateReminderExecutionCapability: Equatable, Sendable {
    public let capabilityID: UUID
    public let draftID: UUID
    public let draftFingerprint: String
    public let effectiveDataSensitivity: DataSensitivityLevel
    public let approvalRequestID: String
    public let toolName: String
}
```

The capability is issued only if:

- PolicyEngine allows the action;
- approval is explicitly `.approved`;
- the underlying receipt has `mayContinueRouting == true`;
- the receipt/draft binding matches the current canonical draft;
- the typed tool identity is `createReminder`.

### Fingerprint

The fingerprint must be deterministic and length-delimited, following the anti-ambiguity principle already used by `AppActionDraft.fingerprint`. It binds at minimum:

- draft UUID;
- literal tool identity;
- normalized title bytes;
- numeric due components;
- time-zone identifier;
- effective data-sensitivity level;
- `.execute` risk.

Do not use Swift `Hashable.hashValue`, because it is not a stable persistence/security identity.

### One-shot consumption

V0 uses an in-memory capability ledger owned by the action execution coordinator. It records capability IDs as `issued`, `consuming`, or `consumed` under a lock/actor-isolated boundary.

Execution must atomically transition:

```text
issued -> consuming
```

before calling the executor. A second caller observing `consuming` or `consumed` fails closed.

After the executor returns, the capability becomes `consumed` regardless of platform success or failure. V0 never retries the same capability. A user-requested retry requires a new draft review/approval/capability transaction.

This gives a strong within-process one-shot guarantee. It does **not** claim durable replay protection across process termination. Durable idempotency is explicitly deferred because adding persistence is a separate privacy/lifecycle decision.

## 6. Executor protocol

Keep platform code behind a protocol so the authority logic remains unit-testable on Linux/macOS without EventKit execution.

API shape:

```swift
public protocol CreateReminderExecuting: Sendable {
    func execute(_ request: CreateReminderExecutionRequest) async -> CreateReminderExecutionResult
}
```

The request contains only the validated typed execution fields needed by the platform adapter. It does not carry model output or raw task text.

The coordinator, not the executor, validates the capability and consumes it. The executor must never accept an approval receipt as an alternative input.

Required results:

```text
success
permissionDenied
permissionUnavailable
cancelled
noDefaultReminderCalendar
invalidRequest
platformFailure
```

`staleCapability`, `mismatchedCapability`, and `alreadyConsumedCapability` are coordinator failures and must occur before the executor is called.

## 7. EventKit adapter boundary

The first platform adapter should be `EventKitCreateReminderExecutor` behind the protocol above.

Apple platform facts relevant to the later implementation:

- Reminders access is provided through EventKit.
- Current iOS requires `NSRemindersFullAccessUsageDescription` for reminder access.
- The app must request reminder access before attempting to fetch or create reminders and must handle denial.
- `EKEventStore.defaultCalendarForNewReminders()` identifies the user's configured default reminder calendar and may return `nil`.
- `EKEventStore.save(_:commit:)` saves a reminder and throws on failure.
- `EKReminder(eventStore:)` is the supported initializer for a new reminder.

Primary references:

- https://developer.apple.com/documentation/eventkit/ekeventstore/requestfullaccesstoreminders%28completion%3A%29
- https://developer.apple.com/documentation/bundleresources/information-property-list/nsremindersfullaccessusagedescription
- https://developer.apple.com/documentation/eventkit/accessing-the-event-store
- https://developer.apple.com/documentation/eventkit/ekeventstore/defaultcalendarfornewreminders%28%29
- https://developer.apple.com/documentation/eventkit/ekeventstore/save%28_%3Acommit%3A%29

### V0 adapter decisions

- Maintain one `EKEventStore` instance for the lifetime of the adapter rather than constructing one per property access.
- Check reminder authorization before creating an `EKReminder`.
- Permission prompting is an explicit user-facing preflight state, never hidden inside an automatic background retry.
- If authorization is denied/restricted/unavailable, return without creating or saving a reminder.
- Use `defaultCalendarForNewReminders()` only. If it returns `nil`, fail closed. V0 does not guess another calendar.
- Construct one `EKReminder(eventStore:)`, assign the normalized title, default calendar, and validated due-date components.
- Call `save(reminder, commit: true)` at most once.
- Do not retry a thrown save under the same capability.
- Do not interpret EventKit permission as iGentic approval.

The later EventKit implementation issue must verify exact current SDK enum cases and concurrency annotations at build time instead of hard-coding assumptions from this design document.

## 8. Idempotency and replay

V0 protects against process-local duplicate execution in four places:

1. the canonical draft fingerprint invalidates changed action content;
2. capability identity is unique per approved execution attempt;
3. atomic capability consumption rejects double taps/concurrent duplicate calls;
4. every capability is terminal after the first executor attempt, even if EventKit fails.

No automatic retry exists.

Out of scope for V0:

- durable execution ledger across app restarts;
- querying EventKit to deduplicate semantically similar reminders;
- remote idempotency tokens;
- persistence of approval or capability state.

The UI must not claim replay protection beyond the lifetime of the in-memory coordinator.

## 9. Audit contract

Add typed audit event kinds in a later implementation rather than encoding execution state only in arbitrary free-text messages.

Required semantic events:

```text
reminderDraftValidated
reminderDraftRejected
executionCapabilityIssued
executionCapabilityRejected
reminderExecutionStarted
reminderExecutionSucceeded
reminderExecutionFailed
reminderExecutionCancelled
executionCapabilityConsumed
```

Audit metadata may include:

- action/tool identity;
- effective data-sensitivity level;
- approval status/reason category;
- non-secret capability lifecycle state;
- coarse platform outcome category.

Audit metadata must not include:

- reminder title;
- due date/time;
- raw proposal/user text;
- calendar name/account/source;
- EventKit object identifiers;
- Apple account/device identifiers;
- raw platform error descriptions when they may contain private content.

Platform errors should be mapped to bounded categories before generic audit emission.

## 10. Cancellation and no-side-effect invariant

The coordinator must prove with tests that the executor receives **zero calls** when any pre-executor authority or validation boundary fails:

- malformed/unsupported proposal;
- missing or ambiguous title/time;
- PolicyEngine denial;
- approval pending/rejected/missing;
- stale/mismatched approval;
- stale/mismatched/consumed capability;
- ToolRegistry explicitly supplied but missing the typed `createReminder` tool;
- user cancels before executor invocation.

Platform preflight outcomes are different because they are owned by the EventKit executor boundary. Permission denied/restricted/unavailable or a missing default reminders calendar may require one executor invocation, but they must produce **zero EventKit save attempts** and no reminder persistence side effect. The capability is still consumed after that first executor attempt; V0 does not retry it.

Once the single EventKit save attempt starts, cancellation must not be reported as though the save were guaranteed not to have happened. The adapter must return the actual bounded outcome it can establish. Do not manufacture rollback claims EventKit cannot prove.

## 11. Test and evidence matrix

### Pure AgentCore tests — required first

Use only fake executors and synthetic text.

Pin:

- valid typed draft generation;
- unknown/invented arguments rejected;
- ambiguous time asks clarification;
- reminder risk cannot be lowered below `.execute`;
- reminder classification floor and detector escalation;
- policy denial prevents capability issuance;
- pending/rejected approval prevents capability issuance;
- changed title/time/classification/risk invalidates binding;
- valid approved draft issues one capability;
- double execution/concurrent reuse calls fake executor once at most;
- failed fake executor still consumes capability;
- new attempt requires new approval/capability;
- audit messages contain no title/time/raw proposal;
- model/backend choice cannot alter permission.

### EventKit adapter compile/integration tests — second slice

Pin with test seams where the SDK permits:

- authorization-state mapping;
- denied permission produces no save;
- no default reminder calendar produces no save;
- exactly one save call on success path;
- thrown save maps to bounded platform failure;
- title/due fields map from the typed request only.

CI compile/simulator evidence proves compatibility only. It is not a physical-device behavior claim.

### Physical iPhone evidence — later

Only a real device may establish:

- system permission prompt behavior;
- real Reminders database write;
- relaunch/lifecycle behavior;
- user-visible reminder correctness;
- cancellation/user-flow observations that depend on actual iOS UI.

A physical-device run must use synthetic reminder content and must record no personal calendar/reminder contents.

## 12. Model independence

Safe Action Execution V0 is independent of the model research track.

Qwen #311, Apple Foundation Models #325, and FunctionGemma #326 determine whether a backend proposes `createReminder` reliably. They do not determine whether an approved action is safe to execute.

The first implementation must accept a deterministic synthetic typed proposal so the authority chain can be proven before any model is attached.

Future model adapters end at the proposal/schema boundary. They never receive an execution capability and never call EventKit.

## Authority table

| Stage | Input authority | May block? | May grant execution permission? |
| --- | --- | --- | --- |
| Model/proposal adapter | model or deterministic proposal | Yes, via invalid/clarify result | No |
| Typed schema validator | deterministic Swift | Yes | No |
| SensitiveDataDetector / classification | deterministic Swift | Yes/escalate | No |
| PolicyEngine | deterministic Swift | Yes | No; only policy allowance |
| ApprovalManager | explicit approval state | Yes | Necessary but not sufficient |
| ToolRegistry availability | deterministic metadata | Yes | No |
| Capability issuer | exact approved draft | Yes | Yes, only by issuing bound one-shot capability |
| EventKit permission | iOS/user platform permission | Yes | No; platform access only |
| Executor | typed request + consumed capability | Yes/fail | Performs only already-authorized action |
| Audit | observed lifecycle | No | No |

## Failure table

| Failure | Executor called? | Capability consumed? | Side effect allowed? |
| --- | ---: | ---: | ---: |
| Invalid proposal/schema | No | No capability | No |
| Policy blocked | No | No capability | No |
| Approval pending/rejected | No | No capability | No |
| Stale/mismatched approval | No | No capability | No |
| Stale/mismatched capability | No | No | No |
| Already-consumed capability | No | Already terminal | No new side effect |
| Permission denied before executor save | Executor preflight only | Yes | No |
| No default calendar | Executor preflight only | Yes | No |
| User cancellation before save | Executor may have started; zero save attempts | Yes | No |
| EventKit save throws | One save attempt | Yes | Not claimed successful |
| EventKit save succeeds | One save attempt | Yes | Exactly one intended reminder |

## App Intents boundary

App Intents is a later outer interface, not part of V0 execution authority.

A future `AppIntent.perform()` may:

- collect/normalize intent parameters;
- create a proposal/draft;
- surface clarification/approval UI;
- call the same internal execution coordinator only with a valid capability.

It must not:

- bypass iGentic policy because Siri/Shortcuts invoked it;
- map platform authentication directly to approval;
- call EventKit before exact draft approval;
- carry a model output directly into EventKit.

This preserves the repository's existing draft-first App Intents safety guidance.

## Implementation prerequisites

Real side-effect implementation is blocked until:

1. #286 default-branch privacy enforcement is terminal.
2. #287 base-trusted public-content admission is implemented, proven on a real PR event, and required by branch protection/ruleset.
3. #334 CodeQL Advanced migration has at least one successful manual all-language run using the explicit Swift build.

The design PR itself does not need to wait for those platform gates because it changes documentation only.

## Implementation sequence after prerequisites

Do not implement EventKit in the first code slice.

### Slice A — pure execution authority

AgentCore only:

- `CreateReminderDraft` and `ReminderDueDate`;
- deterministic validation/fingerprint;
- effective-classification/risk pinning;
- `CreateReminderExecutionCapability`;
- in-memory one-shot capability ledger/coordinator;
- `CreateReminderExecuting` protocol;
- fake-executor tests;
- typed/minimized audit events.

No EventKit, App Intents, Info.plist or device permissions.

Exit gate: all no-side-effect and replay tests pass with a fake executor.

### Slice B — EventKit adapter

Only after Slice A is merged and stable:

- EventKit adapter implementation;
- reminder usage-description key;
- authorization/preflight mapping;
- default reminders calendar selection;
- one-save-attempt behavior;
- compile/integration tests.

No App Intents yet.

### Slice C — user-facing execution flow / device evidence

Only after Slice B:

- user-facing draft/approval/cancel flow;
- synthetic physical-device test;
- receipt/outcome evidence;
- no real private reminder content in test evidence.

### Slice D — optional App Intent surface

Only after the internal executor path is independently proven. App Intent is an adapter to the same authority chain, never a parallel execution path.

## Explicitly deferred

- no reminder notes/location/recurrence/priority/list selection;
- no calendar-event creation;
- no file/message/delete/export actions;
- no automatic action mode;
- no durable capability or idempotency persistence;
- no MemoryStore use in authorization;
- no cloud/provider execution;
- no model-driven tool execution;
- no App Intent implementation in V0 authority slices.

## Definition of done for this design

This design is complete when review confirms that:

- `createReminder` is the single V0 side effect;
- its draft and due date are typed before policy/approval;
- `.execute` risk and explicit approval are mandatory;
- effective classification cannot be lowered;
- a separate one-shot capability binds the exact approved draft;
- replay/double-tap behavior is fail-closed within the documented in-memory scope;
- EventKit permission/cancel/preflight failures cannot create a reminder;
- generic audit output excludes title/time/private platform identifiers;
- models and App Intents remain outer proposal interfaces only;
- the smallest next implementation is Slice A, not EventKit.
