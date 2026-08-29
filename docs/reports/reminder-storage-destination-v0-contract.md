# Reminder storage destination V0 — EventKit locality contract

Status: normative design refinement for Safe Action Execution V0; no EventKit implementation authorized  
Tracks: #341  
Baseline: `9818735597e007ee2b7b8d3d7ca9bfcb5f343d0d`  
Parent design: `docs/reports/safe-action-execution-v0-design.md`

## Purpose

This document closes the design ambiguity around where an approved `createReminder` side effect is stored.

An EventKit API call executed on the iPhone is not automatically a device-local persistence operation. The user's default reminders calendar can belong to a local source or to a synced account/source such as iCloud/CalDAV or Exchange. Safe Action V0 must resolve that distinction before action authorization is finalized.

This contract separates **where agent computation is delegated** from **where side-effect data is persisted**.

It does not authorize EventKit writes, App Intents, reminder permission prompts, Info.plist changes, signing, persistence, model execution, or real reminder/calendar inspection.

## Apple platform facts

The future implementation must verify the exact current SDK surface at build time, but the design relies on these current EventKit facts:

- `defaultCalendarForNewReminders()` identifies the user's configured default reminder calendar.
- `EKCalendar.source` is the source/account to which the calendar belongs.
- `EKSource.sourceType` exposes the coarse `EKSourceType`.
- `EKSourceType.local` represents a local source.
- `EKSourceType.calDAV` represents a CalDAV or iCloud source.
- `EKSourceType.exchange` represents an Exchange source.
- Reminders access uses Full Access; EventKit does not provide the write-only reminders permission available for calendar events.

Primary Apple references:

- https://developer.apple.com/documentation/eventkit/ekeventstore/defaultcalendarfornewreminders%28%29
- https://developer.apple.com/documentation/eventkit/ekcalendar/source
- https://developer.apple.com/documentation/eventkit/eksource/sourcetype
- https://developer.apple.com/documentation/eventkit/eksourcetype
- https://developer.apple.com/documentation/eventkit/accessing-the-event-store
- https://developer.apple.com/documentation/eventkit/ekeventstore/requestfullaccesstoreminders%28completion%3A%29

## Core architecture decision

Do not add a synced reminder store to `DelegationTarget`.

`DelegationTarget` describes where computation/agent work is delegated. A reminder written by an on-device process into an iCloud/CalDAV/Exchange-backed store is still local computation, but the resulting user data is persisted/synchronized outside a device-local store.

Safe Action V0 therefore introduces a separate policy dimension equivalent to:

```swift
public enum ActionDataDestination: Equatable, Sendable {
    case none
    case deviceLocalStore
    case systemSyncedPersonalStore
    case unknown
}
```

Names may change during implementation, but the semantic separation is mandatory.

For side-effect policy, the authorization input must be able to evaluate both:

```text
requestedDelegationTarget
+ actionDataDestination
```

Existing side-effect-free paths may use `.none`. A real side-effect path may not silently default an unresolved destination to `.deviceLocalStore`.

## Reminder V0 source mapping

The resolver inspects only the default reminders calendar and the minimum coarse source metadata needed for policy.

Map source types conservatively:

| EventKit source class | V0 destination |
| --- | --- |
| `.local` | `.deviceLocalStore` |
| `.calDAV` / iCloud | `.systemSyncedPersonalStore` |
| `.exchange` | `.systemSyncedPersonalStore` |
| subscribed / birthdays / deprecated / unsupported / unknown | `.unknown` |

`.unknown` fails closed for V0 unless a later, separately reviewed contract proves the source writable and gives it explicit destination semantics.

The V0 resolver must not infer locality from the fact that EventKit itself runs on-device.

## Metadata minimization

The resolver may inspect only metadata necessary to authorize and execute the one approved write:

- reminder authorization status;
- `defaultCalendarForNewReminders()`;
- the default calendar's coarse source type/locality;
- a non-secret target binding needed to detect target changes;
- the single new reminder object during the later executor step.

V0 must not fetch existing reminders merely because Full Access technically permits reading them.

Do not introduce:

- reminder predicates;
- `fetchReminders` calls;
- enumeration/search of existing reminder contents;
- read-backed deduplication;
- ingestion of reminder contents into MemoryStore;
- model access to existing reminder contents;
- raw reminder/calendar/account data in generic audit or diagnostics.

If future target resolution cannot be implemented from the default calendar/source object alone and would require broader account/calendar enumeration, that expansion requires separate review before implementation.

## Permission setup boundary

EventKit reminders permission is platform access control, not iGentic action approval.

Because reminder access is Full Access rather than write-only, Safe Action V0 should not request permission halfway through an already approved action transaction.

Preferred ordering:

```text
explicit reminder-permission setup
-> read-only default-target resolution
-> proposal validation / typed draft
-> freeze ActionDataDestination + target binding
-> destination-aware policy evaluation
-> explicit action approval
-> one-shot execution capability
-> executor re-resolves current target
-> exact target/locality match
-> at most one save attempt
```

If reminder permission is not available, not determined, or otherwise prevents safe target resolution, the action path returns a bounded setup-required/unavailable result before capability issuance.

The OS permission prompt must never be presented as approval for a specific reminder.

## Policy floor

The following rules are the minimum Safe Action V0 floor.

### Local Only

Under `PrivacyMode.localOnly`:

- `.deviceLocalStore` may continue to the normal policy and explicit `.execute` approval path;
- `.systemSyncedPersonalStore` is blocked before capability issuance;
- `.unknown` is blocked before capability issuance.

### Restricted sensitive data

For `.restrictedSensitiveData`:

- `.systemSyncedPersonalStore` is blocked in V0;
- `.unknown` is blocked in V0;
- `.deviceLocalStore` may continue only to the existing strict policy/approval gates.

Action approval cannot override this destination block.

### Contextual and highly private data

For `.contextualPrivateData` and `.highlyPrivateData`, a synced personal destination may proceed only when the selected privacy mode explicitly permits it and the coarse destination class is part of the action authorization context shown before approval.

`.execute` remains approval-required in all V0 reminder cases.

A future policy may distinguish trusted synced accounts more finely, but V0 must not infer trust simply because the account is configured in iOS.

## Target binding

The approved reminder transaction must bind both:

1. the coarse `ActionDataDestination`; and
2. enough non-secret target identity to prove that the default reminder target has not changed between approval and save.

Raw calendar titles, source titles, account names, calendar identifiers, source identifiers, or other personal account metadata must not appear in generic audit output.

A process-local opaque equality token or deterministic internal digest may be used as the binding representation if it does not expose the underlying identifier in logs or UI.

The target binding is authorization input, not general-purpose telemetry.

## TOCTOU fail-closed rule

Immediately before any future save, the EventKit executor must re-resolve the current default reminders calendar and its coarse destination.

If either:

- destination class differs from the approved destination; or
- bound target identity differs from the approved target binding,

then execution returns a bounded `targetChanged`/stale result and performs zero save attempts.

The user must receive a fresh draft/approval/capability transaction for the new target.

The executor must not silently redirect an approved reminder to a newly selected default calendar.

## Fingerprint/capability contract

The canonical Safe Action reminder fingerprint must bind the storage destination dimension in addition to the already pinned title, due-date identity, classification, and risk fields.

At minimum bind:

- coarse `ActionDataDestination`;
- non-secret target binding or a canonical digest representation suitable for exact equality.

Changing only the destination must invalidate the approval/capability binding.

The model cannot choose, override, downgrade, or relabel destination locality.

## Required regression matrix

Use fakes/synthetic metadata only. No real account names, calendar names, identifiers, or reminder contents.

Pin at minimum:

| Case | Expected result |
| --- | --- |
| Local source + Local Only | destination is local; may continue to normal policy/approval |
| CalDAV/iCloud source + Local Only | hard block before capability |
| Exchange source + Local Only | hard block before capability |
| Unknown/unsupported source | fail closed |
| Restricted data + synced destination | hard block |
| Restricted data + unknown destination | hard block |
| Contextual/highly-private synced path | never bypasses explicit `.execute` approval |
| Same delegation target, different storage destination | policy/fingerprint outcomes differ correctly |
| Same draft, changed destination | fingerprint changes |
| Same destination, changed bound target | capability becomes stale before save |
| Destination/target changes after approval | zero save attempts |
| Audit output | coarse destination/outcome only |
| Existing-reminder read APIs | not required/called in V0 |
| Model output proposes locality | ignored/rejected as non-authoritative |

The regression suite must prove that `DelegationTarget` and `ActionDataDestination` vary independently.

## Audit contract

Generic audit may include bounded values equivalent to:

```text
deviceLocalStore
systemSyncedPersonalStore
unknown
permissionRequired
targetChanged
destinationBlocked
```

Generic audit must not include:

- calendar title;
- source title;
- account name/address;
- source identifier;
- calendar identifier;
- existing reminder titles/content;
- raw EventKit error text that may contain personal metadata.

## Scratch feasibility evidence

A non-merged synthetic prototype recorded on #341 has already shown that a separate destination dimension can remain orthogonal to `DelegationTarget`, and that Local Only/sensitive-data destination gates can be tested without changing `PolicyEngine` or `RiskScorer` globally.

The scratch package reported 286 Swift tests with zero failures, including 21 focused Safe Action prototype tests, followed by a clean repository-structure validation.

That evidence proves feasibility only. It does not establish EventKit source mapping, real Full Access behavior, real target re-resolution, physical-device behavior, or production PolicyEngine integration.

## Implementation ordering

This design contract may merge while GitHub platform settings remain pending.

Real Safe Action implementation remains ordered as follows:

1. complete repository admission/platform prerequisites tracked in #286, #287, and #334;
2. implement the pure Slice A authority/date/fingerprint path using fakes;
3. integrate the destination policy dimension in a bounded reviewable slice;
4. only then implement the EventKit adapter and real target re-resolution;
5. collect physical iPhone evidence separately.

No EventKit write code belongs in this design PR.

## Definition of done for this contract

This contract is pinned when repository review confirms that:

- storage destination is distinct from computation delegation;
- a synced reminder store is never mislabeled as device-local;
- Local Only rejects synced or unknown reminder destinations;
- restricted-sensitive reminder data cannot be synced in V0 through approval override;
- target locality is resolved before approval/capability issuance;
- destination and non-secret target identity are approval-bound;
- target change after approval fails closed with zero saves;
- Full Access does not authorize reading existing reminders for V0;
- generic audit exposes only coarse destination/outcome metadata;
- no real side effect is introduced by this document.
