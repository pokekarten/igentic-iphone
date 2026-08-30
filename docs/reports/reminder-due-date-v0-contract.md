# ReminderDueDate V0 — canonical time identity contract

Status: normative design refinement for Safe Action Execution V0; no side-effect implementation authorized  
Tracks: #340  
Baseline: `52811fd56f0b28f8c6644d27db3cb29f42c52e85`  
Parent design: `docs/reports/safe-action-execution-v0-design.md`

## Purpose

This document pins the date/time contract required before the `createReminder` Safe Action Slice A may implement `ReminderDueDate`, draft fingerprinting, or execution-capability binding.

It is a normative refinement of the parent Safe Action V0 design for due-date validation and identity. The parent design's simpler local-components-plus-time-zone shape is not sufficient by itself for an executable approval identity because a daylight-saving overlap can map the same wall-clock components to more than one real instant.

This document does not authorize EventKit, App Intents, reminder permissions, signing changes, persistence, model execution, or any real reminder write.

## Decision

Safe Action V0 uses both:

1. the user-visible civil-time meaning — Gregorian local components plus an explicit IANA time-zone identifier; and
2. one frozen absolute identity — integer Unix seconds plus the resolved UTC offset.

An executable `CreateReminderDraft` may exist only when the requested civil time maps to exactly one real minute-aligned instant.

Repeated local times and nonexistent local times fail closed and require clarification. V0 does not silently choose an occurrence of a fall-back overlap and does not silently normalize a spring-forward gap to another time.

## Canonical value shape

The production API may use an equivalent representation, but it must preserve these fields and semantics:

```swift
public struct ReminderDueDate: Equatable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int
    public let hour: Int
    public let minute: Int
    public let timeZoneIdentifier: String
    public let resolvedUnixSeconds: Int64
    public let resolvedUTCOffsetSeconds: Int32
}
```

V0 precision is one minute. Canonical seconds are exactly `0`.

The local fields and IANA identifier preserve what the user reviewed. `resolvedUnixSeconds` prevents two different real instants from accidentally sharing the same approval identity. `resolvedUTCOffsetSeconds` is an additional consistency witness for the exact time-zone rule that produced the approved instant.

Locale-formatted strings, device default time zone, device locale, localized time-zone names, and Swift `Hashable.hashValue` are not canonical identity inputs.

## Admission algorithm

Validation happens before effective-classification freezing, PolicyEngine evaluation, ApprovalManager approval, draft fingerprinting, or capability issuance.

For a proposed reminder due time:

1. Resolve `timeZoneIdentifier` explicitly. Unknown identifiers are rejected.
2. Validate Gregorian year/month/day independently of the machine's default time zone.
3. Validate `hour` in `0...23` and `minute` in `0...59`; canonical second is `0`.
4. Build a neutral UTC reference from the requested numeric components.
5. Search a bounded UTC window around that reference at exact minute-aligned candidate instants.
6. Project each candidate through the requested IANA time zone.
7. Retain only candidates whose projected Gregorian year/month/day/hour/minute/second exactly equal the requested local components and second `0`.
8. Classify the exact-match count:
   - `0` matches: `nonexistentLocalTime`; clarification required;
   - `1` match: unambiguous; freeze its Unix-second identity and UTC offset;
   - more than `1` match: `repeatedLocalTime`; clarification required.
9. Round-trip the frozen instant through the same explicit time zone once more and require exact equality before an executable draft may be created.

A bounded `±36 hour` search window with one-minute steps is an acceptable V0 implementation strategy for an interactive single-reminder validator. A future optimization is allowed only if it preserves identical semantics and the same regression matrix.

## Why not rely on default Calendar resolution

Foundation exposes `Calendar.RepeatedTimePolicy` because a local time may occur more than once during a daylight-saving transition. APIs such as `nextDate` also have default repeated-time and matching behavior, so V0 must not inherit those defaults as authorization semantics.

Primary Apple references:

- https://developer.apple.com/documentation/foundation/calendar/repeatedtimepolicy
- https://developer.apple.com/documentation/foundation/calendar/matchingpolicy
- https://developer.apple.com/documentation/foundation/calendar/nextdate%28after%3Amatching%3Amatchingpolicy%3Arepeatedtimepolicy%3Adirection%3A%29
- https://developer.apple.com/documentation/foundation/calendar/date%28bysettinghour%3Aminute%3Asecond%3Aof%3Amatchingpolicy%3Arepeatedtimepolicy%3Adirection%3A%29

`RepeatedTimePolicy.first` and `.last` remain useful API background but are not the sole V0 ambiguity detector. Repository scratch validation found that a first/last comparison was not sufficiently portable for a synthetic `Australia/Lord_Howe` 30-minute fall-back case. The V0 contract therefore counts exact real-instant round-trip matches instead of assuming DST shifts are one hour or that first/last exposes every overlap consistently.

## Fingerprint contract

The deterministic, length-delimited `CreateReminderDraft` fingerprint must bind at least:

- draft UUID;
- literal tool identity `createReminder`;
- normalized title bytes;
- year;
- month;
- day;
- hour;
- minute;
- canonical second `0` or an explicit V0 precision/version marker;
- IANA time-zone identifier;
- resolved Unix seconds;
- resolved UTC offset seconds;
- effective data-sensitivity level;
- fixed `.execute` action risk.

Changing any due-date field or either resolved identity field must change the fingerprint.

Display formatting must never participate in canonical identity.

## Execution-time consistency rule

A future executor receives only an already validated typed request. Immediately before any platform save, the platform boundary must re-project the frozen `resolvedUnixSeconds` through the frozen `timeZoneIdentifier`.

If that projection no longer reproduces the approved local fields, canonical second, and frozen UTC offset, execution fails closed and requires a fresh draft/approval/capability transaction.

This rule covers time-zone database/rule drift without pretending that a stale approval still refers to the same civil time.

The executor must not silently re-resolve a changed civil time, choose a different overlap occurrence, normalize a gap, or mutate the approved due identity.

## Required Slice A regression matrix

Use synthetic data only and never depend on the machine's default time zone or locale.

At minimum pin:

| Case | Expected result |
| --- | --- |
| Ordinary unambiguous local time | accepted; exactly one frozen instant |
| Impossible Gregorian date | rejected |
| Unknown IANA time zone | rejected |
| Berlin `2026-03-29 02:30` | rejected as nonexistent |
| Berlin `2026-10-25 02:30` | rejected as repeated |
| New York `2026-03-08 02:30` | rejected as nonexistent |
| New York `2026-11-01 01:30` | rejected as repeated |
| Lord Howe `2026-10-04 02:15` | rejected as nonexistent |
| Lord Howe `2026-04-05 01:45` | rejected as repeated |
| Mutation of any local due field | fingerprint changes |
| Mutation of time-zone identifier | fingerprint changes |
| Mutation of resolved Unix seconds | fingerprint changes |
| Mutation of frozen UTC offset | fingerprint changes |
| Device locale/default-zone change | canonical identity unchanged |
| Locale-formatted display change | canonical identity unchanged |
| Re-projection mismatch before execution | fail closed; no platform save |

The `Australia/Lord_Howe` cases are intentionally retained because its non-one-hour transition protects the validator against hidden one-hour DST assumptions.

## Error semantics

The proposal/validation boundary should distinguish bounded non-secret outcomes equivalent to:

```text
invalidCalendarDate
unknownTimeZone
nonexistentLocalTime
repeatedLocalTime
```

`nonexistentLocalTime` and `repeatedLocalTime` are clarification-required outcomes, not executor failures. They occur before an executable draft, approval receipt binding, or execution capability exists.

Generic audit output must not include the due date/time itself.

## Authority boundary

Neither Foundation's date resolution, a model-generated time string, a locale parser, EventKit, nor the operating system's default calendar/time-zone settings may grant execution authority.

The authority sequence remains:

```text
proposal
-> deterministic parsing
-> exact civil-time validation
-> frozen ReminderDueDate identity
-> CreateReminderDraft
-> policy
-> explicit approval
-> one-shot capability
-> executor
```

The resolved absolute identity is therefore produced before approval and is never selected by the executor after approval.

## Evidence already available

A non-merged scratch prototype recorded on #340 exercised the exact-match round-trip approach across Berlin, New York, and Lord Howe, including gap/overlap cases, impossible Gregorian dates, unknown zones, and resolved instant/offset identity. The scratch-augmented package reported 286 tests with zero failures, including 21 focused Safe Action prototype tests, followed by a clean repository-structure validation.

That scratch evidence establishes feasibility only. It is not merged implementation evidence and does not bypass repository safety prerequisites.

## Implementation ordering

This contract may merge as documentation while GitHub platform settings remain pending.

Production Slice A remains behind the repository prerequisites already tracked separately:

- #286 default-branch enforcement;
- #287 base-trusted public-content admission.

CodeQL security posture is tracked separately: keep healthy Default Setup evidence; Advanced Setup remains optional hardening per the completed #334 decision and is not a Slice A prerequisite.

Once those gates permit the bounded implementation, Slice A should be decomposed into reviewable changes rather than publishing the large scratch spike wholesale.

No EventKit work belongs in the `ReminderDueDate` implementation slice.

## Definition of done for this contract

This contract is pinned when repository review confirms that:

- repeated and nonexistent civil times fail closed before approval;
- an executable due date has exactly one real instant;
- local components, IANA zone, frozen Unix seconds, and frozen offset are all approval-bound;
- the fingerprint cannot identify two distinct real instants as the same approved due time;
- locale/default-zone formatting cannot change canonical identity;
- execution-time time-zone-rule drift fails closed;
- Berlin, New York, and Lord Howe synthetic regressions are required for Slice A;
- no side-effect implementation is introduced by this document.
