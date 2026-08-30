# Safe Action approval binding V0 — exact human decision contract

Status: normative design refinement for Safe Action Execution V0; no real side effect authorized  
Tracks: #342  
Baseline: `a3f9025a017a4d981bdcff91b10fe42fecc7d29b`  
Related contracts: `docs/reports/reminder-due-date-v0-contract.md`, `docs/reports/reminder-storage-destination-v0-contract.md`

## Purpose

Safe Action V0 must not turn approval of a generic summary into authority for a more specific side effect. The person approving `createReminder` must see and approve the exact canonical action whose fingerprint later enters the one-shot execution capability.

This document pins the approval identity, title canonicalization, display integrity, and test/production separation required before the approval/capability portion of Slice A is implemented.

No EventKit, App Intents, reminder permission, signing, persistence, model execution, or real reminder write is authorized here.

## Core invariant

The authority chain is:

```text
validated canonical draft
-> deterministic canonical fingerprint
-> typed approval subject derived from that same draft
-> human-visible presentation derived from that subject
-> explicit decision for that exact fingerprint
-> fingerprint-bound approval receipt
-> one-shot capability for the same fingerprint
```

A generic approval, a coarse task summary, device authentication, OS permission, routing, ToolRegistry presence, or model confidence can never be upgraded after the fact into approval for an exact executable draft.

## Typed approval subject

The implementation may choose equivalent names, but the Safe Action approval subject must preserve semantics equivalent to:

```swift
public struct CreateReminderApprovalSubject: Equatable, Sendable {
    public let draftID: UUID
    public let draftFingerprint: String
    public let canonicalTitle: String
    public let due: ReminderDueDate
    public let effectiveDataSensitivity: DataSensitivityLevel
    public let actionRisk: ActionRisk
    public let actionDataDestination: ActionDataDestination
}
```

The subject is constructed only after proposal validation, title/date canonicalization, effective-classification resolution, and storage-destination resolution.

The fingerprint already exists before the decision. The decision does not create, replace, or refine the action identity.

## Human-visible approval floor

Before a real side effect can be approved, the presentation must materially expose:

- the action: create one reminder;
- the full canonical reminder title;
- the resolved due date/time with enough timezone context to avoid ambiguity;
- whether persistence is device-local or system-synced when applicable;
- that the operation writes persistent user data;
- that the action has `.execute` risk and requires explicit approval.

The UI may localize labels and date formatting for readability, but those display strings are not authority inputs. They must faithfully represent the canonical typed values.

If the surface cannot faithfully show the canonical action, the action is not approvable.

Silent truncation of the canonical title is not acceptable. If a visual layout uses a length cap, the user must be able to reveal the entire canonical title before deciding.

## Canonical reminder title

Use one title value for detection, approval, fingerprinting, execution, and the future EventKit assignment.

Canonicalization order:

```text
raw proposal title
-> trim leading/trailing whitespace and newlines
-> Unicode NFC (Form C)
-> display-integrity validation
-> require non-empty
-> freeze canonicalTitle
```

NFC should be implemented with Foundation's canonical precomposition facility or an equivalent Unicode-conformant Form C operation.

Do not use locale-sensitive case folding, NFKC, or NFKD for identity. Compatibility normalization may alter distinctions the user intentionally entered.

The fingerprint uses the exact UTF-8 bytes of the frozen canonical title with deterministic length delimiting.

## Display-integrity validation

Safe Action V0 keeps international text, ordinary combining characters, and normal emoji, but rejects title scalars that can make the approval display materially misleading or multiline.

Reject at minimum:

- Unicode general category `Cc` control characters, including tab/newline controls;
- line separator `U+2028` and paragraph separator `U+2029`;
- bidi formatting/override/isolate controls `U+061C`, `U+200E`, `U+200F`, `U+202A...U+202E`, `U+2066...U+2069`;
- zero-width space `U+200B`, word joiner `U+2060`, and BOM/zero-width no-break space `U+FEFF`.

Do not blanket-reject `U+200C` ZWNJ or `U+200D` ZWJ because they participate in legitimate scripts and emoji sequences.

For the `Cc` check, use Unicode scalar general category rather than assuming a broad convenience `CharacterSet` exactly matches the normative category.

## Bound approval receipt

A receipt capable of contributing to real Safe Action authority must strongly bind at least:

- approval request ID;
- canonical draft fingerprint;
- decision status (`approved`, `rejected`, `pending` or equivalent);
- effective data sensitivity;
- literal action identity and fixed `.execute` risk;
- coarse storage destination and the destination binding required by the storage-locality contract.

An absent, stale, mismatched, or differently scoped fingerprint cannot issue a capability.

V0 may keep the binding in memory/process-local. Cryptographic signatures and durable cross-launch persistence are out of scope. Deterministic identity is still required; Swift `hashValue` is not an approval identity.

## Production human decision vs test double

`FixedApprovalDecisionPolicy(defaultStatus: .approved)` and equivalent auto-approval policies are test doubles only.

They may drive fake-executor Slice A tests because those tests produce zero real side effects. They must not be accepted as production evidence of explicit human approval for EventKit or any other real write.

Before a real reminder can be saved, a user-driven approval adapter/surface must produce the bound decision for the exact `CreateReminderApprovalSubject`.

The production wiring must make this distinction structural rather than relying on comments or operator discipline.

## Mutation rule

After approval, any mutation of an approval-bound canonical field invalidates the decision for execution.

This includes at least:

- canonical title;
- any canonical/resolved due-date identity field;
- effective sensitivity;
- `.execute` risk/action identity;
- storage destination;
- target binding required by the storage-locality contract.

A newly rendered display string may differ because of locale without changing authority, but the canonical subject/fingerprint must remain identical.

## Audit separation

Private content can be shown to the person making the decision. Generic audit logs cannot reuse that content.

Audit may retain bounded metadata such as:

- action kind;
- sensitivity;
- approval outcome category;
- non-secret request/capability lifecycle state;
- coarse destination class.

Generic audit must not contain reminder title, due time, raw proposal text, calendar/source/account identifiers, or localized approval display text.

## Required regression matrix

Use synthetic data only.

| Case | Expected result |
| --- | --- |
| Exact subject + explicit approved decision | capability may proceed to later gates |
| Pending/rejected/missing decision | no capability |
| Approval for draft A used with draft B | rejected |
| Changed canonical title after approval | fingerprint mismatch |
| Changed due identity after approval | mismatch |
| Changed sensitivity | mismatch |
| Changed destination/target binding | mismatch |
| Generic coarse `ApprovalRequest` without exact Safe Action fingerprint | cannot authorize real execution |
| Fixed auto-approved test policy + fake executor | allowed only in test/synthetic path |
| Fixed auto-approved policy + real side-effect wiring | structurally rejected/not wired |
| Composed/decomposed canonically equivalent title | same NFC canonical title/fingerprint |
| Leading/trailing whitespace | removed before approval/fingerprint |
| Ordinary internal spaces | preserved |
| Empty after trimming | rejected |
| Control/newline/line separator | rejected |
| Bidi formatting/override/isolate control | rejected |
| `U+200B`, `U+2060`, `U+FEFF` | rejected |
| Legitimate emoji ZWJ sequence | accepted and byte-stable after NFC |
| Localization around canonical title/date | does not change fingerprint |
| Approval surface truncates without full reveal | not approvable |
| Generic audit | contains no title/due/raw proposal/private identifiers |

## Evidence already available

A non-merged synthetic prototype recorded on #342 passed 286 Swift tests with zero failures, including 21 focused Safe Action prototype tests, followed by clean repository-structure validation.

The scratch evidence covered trim -> NFC -> display-integrity validation, canonical-title equivalence, rejection of bidi/zero-width/control cases, acceptance of an emoji ZWJ sequence, a typed approval subject, and mutation rejection for title/due/sensitivity/destination.

This is feasibility evidence only. It does not prove a production human approval UI and does not authorize a real side effect.

## Ordering

This contract can merge as documentation while GitHub settings are deferred.

Production Safe Action work remains behind the repository prerequisites tracked in #286 and #287. Keep CodeQL Default Setup healthy; Advanced Setup remains optional hardening per the completed #334 decision and is not a Safe Action prerequisite.

Within Safe Action Slice A, the logical order is:

1. canonical title and due-date/destination identity;
2. exact typed approval subject and fingerprint-bound decision;
3. capability issuance;
4. irreversible one-shot capability consumption (#343);
5. fake-executor authority tests;
6. only later, after prerequisites and review, real EventKit/user-facing integration.

## Definition of done for this contract

This approval contract is pinned when repository review confirms that:

- the human decision refers to the exact canonical draft fingerprint before capability issuance;
- title, due identity, sensitivity, risk, and destination are materially represented in the approval subject;
- title bytes shown/fingerprinted/executed come from one frozen NFC canonical value;
- misleading/multiline invisible control cases fail closed without blocking legitimate ZWJ text;
- generic/coarse approval cannot be promoted into exact execution authority;
- auto-approval remains a fake-executor test facility only;
- any canonical mutation invalidates the approval;
- generic audit remains content-minimized;
- no real side effect is introduced by this document.
