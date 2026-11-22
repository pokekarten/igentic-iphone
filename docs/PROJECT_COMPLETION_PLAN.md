# iGentic Project Completion Plan

Status: canonical product and implementation plan; proposed capabilities are not completion claims.
Updated: 2026-11-22.
Scope: `pokekarten/igentic-iphone`, physical iPhone Air and optional trusted Mac.

This refresh replaces the 2026-08-17 execution sequence using current source inspection and physical-device evidence. The older plan remains in Git history. Existing safety and immutable benchmark contracts still apply; this document grants no additional permissions. Current `AGENTS.md` governs engineering workflow.

## 1. Product decision

Build a task assistant whose authority stays on the iPhone. The useful unit is a completed, independently checked task, not a chat answer or an installed model. “Agentic First” means the user can express an outcome, inspect the proposed change, grant any required approval, and receive an honest result with a way to recover from interruption.

The first product should be a native iPhone app that works for a small set of useful tasks without a Mac. A trusted Mac is optional capacity. Developer automation is a separate testing facility. Extra runtimes, cloud providers and broader device control are later options justified by measured shortcomings.

A target interaction is: “Remind me tomorrow at 18:00 to water the plant.” iGentic resolves the local date/time and ambiguity, shows the exact title/time/list, obtains required approval, writes once, reads the created record back and shows the verified result. Until the writer and readback exist, the interface must call this a **preview**, never a completed reminder.

## 2. What we actually have

See the [physical validation report](reports/iphone-air-validation-2026-11-22.md) for exact revisions, devices, tests, limitations and follow-up results. See the [technical reassessment](research/TECHNICAL_REASSESSMENT_2026_11_21.md) for the broader source review and the [project atlas](research/IPHONE_AGENT_PROJECT_ATLAS.md) for alternatives.

At the start of this refresh:

- The canonical checkout was PR #379 head `c2f97cde`; fetched `origin/main` was `0bb24b75`. Open PRs #378–#388 were inventoried. An open PR is not shipped functionality.
- An isolated local integration of #384 and #380 includes the proposal gate, Apple preview adapter, host probe and read-only App Intent. It is a different source input from `main` and the documentation checkout.
- Baseline host evidence: 100 Python script tests and 288 Swift tests passed. The integrated input passed 305 Swift tests and six Python tests.
- The signed diagnostic app installed and ran on the physical iPhone. Synthetic approval/rejection/cancellation, Explore search, scrolling and relaunch were exercised. Approval did not execute an action.
- A fixed Apple-model reminder probe passed on the Mac but returned `blocked/unknownAction` on all three initial iPhone attempts. This is a functional failure and a successful rejection boundary. The follow-up report records the constrained-generation experiment separately.
- Follow-up: schema-constrained action names produced the expected gate category in eight supported DE/EN attempts, but one unsupported wallpaper request was incorrectly mapped to diagnostics. No action executed; raw title correctness remains unmeasured. Intent selection and abstention are still open.
- The manual EventKit reminder flow has a separate signed physical happy-path result: exactly one user-approved synthetic item was written once and read back by its returned identifier. It did not require or test model inference.
- A reminder-specific Apple system-model path now exists locally in the isolated integration checkout: short user-entered text is sent only to the on-device system model with no tools, then an allowlisted action/title and strict Gregorian local date are validated into an editable draft. The model cannot write or approve. Host tests and the iOS SDK build pass; a synthetic Mac inference reached a component-matched draft on the final measured attempt, while one ambiguous and one unsupported prompt abstained in separate probes.
- The current iPhone is paired and available, but this Mac's Xcode build cannot sign the updated app at present: the selected development team has no Xcode account session and no matching local provisioning profile. The already-installed iGentic app was left untouched; this model path has not yet been installed or exercised on the phone.
- The integrated simulator build passed, but simulator runtime attempts failed. Siri/Shortcuts invocation, private-content processing, real reminder writing, background recovery, voice accessibility, energy and sustained inference have not passed device acceptance.
- PhoneUse/WDA provided deterministic test navigation. Minis reached provider onboarding; Mimi reached pairing. Neither is evidence of a functioning iGentic runtime or an authenticated end-to-end assistant session.

The product remains an experimental diagnostic prototype. There is enough evidence to choose and implement the next product slice; there is not enough to call it production-ready.

## 3. Architecture and authority

```text
User / explicit share / App Intent / Shortcut / Widget
                         |
            Task record + trusted input classification
                         |
       Deterministic parsing or local model proposal
                         |
          Typed capability + argument validation
                         |
   AgentKernel / PolicyEngine / exact-draft approval
                         |
     Local executor OR approved bounded Mac request
                         |
        Independent result readback / verification
                         |
     Verified result OR explicit uncertain/failed state

Metadata audit accompanies transitions. It is not an execution permission.
```

Models propose values; Swift code decides whether they may become an action. A generated action name must be constrained by schema and independently checked by the gate. A constrained schema improves format reliability; it does not establish correct intent, valid authorization or successful execution.

Reuse `AgentKernel`, `PolicyEngine`, `ApprovalManager`, `ApprovalReceipt`, `AuditLog`, `TaskRouter` and the existing app-action contracts. Extend them for one real capability before adding general orchestration layers. `ToolRegistry` metadata, model-selection diagnostics and budget estimates do not gain execution authority by appearing in the UI.

Every executable capability needs: typed input, declared data access, risk, supported platform, preconditions, required permission, approval binding, timeout/cancellation rules, idempotency strategy and a verifiable result. Read-only diagnostics is a suitable integration test; it is not a substitute for a useful task.

## 4. First three user workflows

| Priority | User outcome | Smallest useful implementation | Acceptance evidence |
| --- | --- | --- | --- |
| 1 | Create one reminder reliably | Explicit title/time/list draft, clarification, approval, a narrow reminders adapter and readback; manual form available when inference is unavailable | One approved synthetic reminder in a clearly designated test destination, verified identifier/fields; no write on cancel, deny, changed draft or stale approval |
| 2 | Turn explicitly shared text into a useful local draft | Share input, previewed scope, local summary or extracted task; user edits before any subsequent action | Fixed DE/EN fixtures, injection/ambiguity cases, private-content policy and retention tests, physical offline behavior measured |
| 3 | Send a bounded job to the trusted Mac | User-selected project and predefined operation, scoped task envelope, authenticated pairing and result receipt | Small real task through the intended route; wrong identity, missing Mac, cancelled request and unverified output never count as success |

The general Apple proposal preview remains public-data-only. The separate reminder-specific path may receive a short user-typed instruction classified no higher than contextual private data, but only through Apple's `.system` runtime; it rejects detected sensitive patterns and highly private/restricted classifications. It creates an editable proposal only. Shared files, messages, contacts, calendar content and persistent prompt history are not read or modeled by this slice. Private shared-content extraction remains a future capability requiring explicit scope, classification, retention and permission design.

Build the first workflow before starting the third. Do not add inbox ingestion, autonomous messaging, payments, health integration or unrestricted file access as incidental scope.

## 5. Everyday interface

The primary screen should show tasks and their next useful step: **Needs information**, **Needs approval**, **Running**, **Verified**, **Could not verify**, or **Failed**. A text field and an explicit structured form are sufficient for the first usable version. Voice and system entry points use the same task path.

An approval sheet should answer: what will change, which app/list/device is affected, which data is used, and whether anything leaves the iPhone. Bind approval to the exact normalized action and expiry. Editing the draft invalidates approval. Routine reads already allowed by policy should not acquire ceremonial confirmation screens.

Show preview/demo status prominently in the diagnostic app, including on the approval sheet itself. The current combination of a persistent-write warning and “Approved (no execution)” needs correction before using it as a real-action interface.

A verified result should include a destination or record link where available. An interrupted operation with a possible side effect should say **Could not verify** and offer a check; it must not invite a blind repeat.

Accessibility acceptance includes German and English text, VoiceOver focus/labels, large Dynamic Type, keyboard handling and explicit cancel/back controls. These are planned checks, not results from the present device run.

## 6. Models, context and memory

1. Use deterministic code for dates, identifiers, permission checks, validation and simple form completion where it is sufficient.
2. Use Apple's local system model for bounded language interpretation when availability is actually established. Keep a deterministic/manual fallback. A refusal or unavailable model is a supported product state.
3. Keep sessions short and task-scoped. Treat shared documents, retrieved text, web content and tool output as untrusted data. They cannot change the action allowlist or grant approval.
4. Evaluate any extra local model only after a named missing capability or repeatable quality problem justifies its storage, memory and maintenance cost. Follow `MODEL_STRATEGY.md` and the existing immutable benchmark contracts. Do not install weights merely to increase the model count.
5. Cloud inference is an explicit future opt-in with destination, data scope and cost visibility. No paid or cloud fallback is enabled by this plan.

Persist minimal task state first: task ID, normalized draft, classification, decision, approval binding, execution attempt, verified result reference and uncertainty. Keep content out of general logs. Store credentials in Keychain, and protect any task content with appropriate device data protection and tested retention/deletion behavior. A future memory store should contain user-approved preferences or scoped facts with provenance and expiry; do not turn all conversation history into permanent memory.

Official Apple utilities provide patterns for bounded history and just-in-time skills. Review individual mechanisms when needed; adopting their OpenAI-compatible adapter or networking is not required. [Apple foundation-models-utilities](https://github.com/apple/foundation-models-utilities)

## 7. Lifecycle, interruption and background work

Proposed durable state sequence:

```text
captured -> needsInformation OR draft
 draft -> policyBlocked OR needsApproval OR ready
 needsApproval -> cancelled OR expired OR ready
 ready -> executing -> verified OR failed OR uncertain
```

Keep the existing policy approval floor. A recorded approval, an executor response and a verified result are distinct facts. After a crash, timeout or lost connection, read back the target before deciding whether to retry a possible write. Test duplicate taps and changed drafts. Do not claim exactly-once effects from a locally stored idempotency key alone.

Start with foreground execution and honest pause/resume. On relaunch, recover task status without replaying a write. Lock/background transitions should cancel or suspend inference according to the supported API and preserve a resumable state. Background work must be bounded and compatible with OS scheduling; the product must not depend on an always-running process.

Apple documents continued processing for eligible work begun in the foreground. This is a possible later integration, not evidence that iGentic already runs continuously in the background. [Apple background-task session](https://developer.apple.com/videos/play/wwdc2025/227/)

## 8. What belongs on the phone, Mac and in the lab

| Surface | Intended responsibility | Boundary |
| --- | --- | --- |
| iGentic iPhone | Identity, input scope, classification, approvals, task state, local capabilities and verified results | Core useful task works without the Mac; personal context stays scoped |
| Trusted Mac | Optional larger computation or explicitly scoped project work | Authenticated job, least data, cancellation, deadline and receipt; cannot approve its own actions |
| App Intents / Shortcuts / widgets | Declared task entry points and supported app capabilities | Same policy and approval path; an exposed shortcut is not arbitrary cross-app access |
| PhoneUse / WDA / iCTRL / ARTEMIS | Controlled engineering and physical-device evaluation | Separate lab setup, developer tooling and evidence; not a prerequisite for the consumer app |
| Minis / Mimi | Alternative interfaces or comparison experiments | Only claim readiness after pairing/provider setup and a real authorized task through that route |

App Intents exposes capabilities an app declares to system surfaces such as Siri and Shortcuts. Use public APIs and actual supported integrations rather than assuming every installed app can be controlled. [Apple App Intents](https://developer.apple.com/documentation/appintents)

On the 8-GB Mac, run one heavy build/model/agent task at a time. Reuse existing tools; keep development servers local and stop test services after use. A paired Mac protocol must be designed independently from a permissive developer-control API.

## 9. Lessons from the other repositories

These are source/design lessons, not claims that all repositories were executed in this run. Ownership was established from current READMEs and the atlas.

| Source | Reuse in iGentic | Avoid importing |
| --- | --- | --- |
| `agentic-private-brain` | Compact durable context, routing to the right project/source | A second task scheduler or indiscriminate personal-data store |
| `agentic-dev-playbook` | Small causal slices, measured task completion and concise handoff | Process artifacts that delay a useful tested change |
| `agentic-slm-lab` | Synthetic DE/EN evaluations, held-out cases and evidence before model changes | Fine-tuning or weight deployment as a prerequisite for the first task |
| `igentic-regulation-lab` | Explicit uncertainty, evidence classes and documentation boundaries | Implicit medical/health functionality |
| Mac/Neo operations | Resource budget, serial execution and zero-cost default | Always-on duplicate agents and paid fallbacks |
| TCGP2P work | Provenance and separation of observation from derived claims | Treating an absent result as proof of success or of no side effect |
| Apple foundation-models-utilities | Bounded history and selective context loading | Unneeded dependencies or a network bridge by default |
| FoundationModelsKit | Inspect runtime capabilities, coordinate sessions, distinguish safe retry from possible side effects | Treating third-party helpers as the authorization authority |

The FoundationModelsKit review was of its current README, not a dependency audit or device runtime test. [Source](https://github.com/rryam/FoundationModelsKit)

## 10. Ordered implementation slices

Each slice ends with observable evidence and a reviewable diff. Refresh relevant GitHub heads before integration; do not merge all experimental PRs together just because they compile.

| Order | Work | Exit condition |
| --- | --- | --- |
| A — tested locally | Constrain Apple action generation; run fixed physical fixtures and existing safety tests | 305 Swift tests passed; eight supported physical attempts reached the expected gate category; unsupported request failed to abstain. Evidence is recorded; semantic reliability remains open |
| B — implemented locally, host-tested | Add an optional on-device structured proposal to the manual reminder form | System model only, no tools, bounded input, exact action allowlist, Gregorian/zone/DST validation, editable title/date, and a manual fallback; model unavailable or invalid output makes no proposal |
| C — manual path verified | Add the narrow reminder executor and fresh-store readback | One approved synthetic write verifies once by returned identifier; denied/stale/changed/cancelled drafts cause zero writes; uncertain writes are terminal and never blindly retried |
| D | Persist task transitions and handle lifecycle failure | Relaunch, lock/background, duplicate taps, timeout and lost connection have tested outcomes; raw content is absent from diagnostic logs |
| E | Connect supported system entry points and accessibility | Physical Shortcuts/App Intent invocation reaches the same boundary; VoiceOver/Dynamic Type pass; manual path works without the model |
| F | Add explicitly shared local content | Private classification and retention implemented; selected content scope is clear; offline behavior and injection boundary measured |
| G | Add optional trusted Mac job | Pairing, scope, authorization, cancellation and a real verified result; phone remains useful when Mac is unavailable |
| H | Release hardening and distribution decision | Exact release revision passes device matrix, current CI and privacy checks; signing/expiry/update path documented; publishing or paid enrollment separately authorized |

B and C now have a local implementation and the manual path has one successful physical happy path. The user-typed model route is tested with injected candidates on the host and has one final component-matched synthetic Apple-model run on the Mac; the physical iPhone route is not yet installed because Xcode signing is blocked by the missing account/profile. Automated tests cover model preflight, unavailable/failing runtime, abstention/unknown action, unsafe title, invalid/past/DST-ambiguous date, and the boundary that no store write occurs without an exact human-bound receipt. The separate physical manual write was verified by reopening only the new item through its returned EventKit identifier. Still open: repeated semantic accuracy across held-out DE/EN prompts, phone inference, physical permission denial/recovery, accessibility and lifecycle behavior. Continue with D while keeping the earlier unsupported-action abstention failure from slice A visible. Extra models, long-term memory, general cross-app controllers and cloud integrations remain conditional tracks.

## 11. Evaluation and acceptance

Use the same versioned synthetic cases on Mac and iPhone, with separate results. Include correct tasks in German and English, missing/ambiguous parameters, unsupported actions, prompt injection, sensitive input, model unavailability, stale approvals, cancellation and possible duplicate execution. Freeze held-out cases before tuning; never use exploratory prompt fixes as benchmark evidence.

Record at least: source/runtime/OS versions, fixture identity, expected action, observed disposition, accepted semantic correctness, abstention, malformed output, permission state and whether any side effect occurred. Preserve the original failures. Never collect private prompt/generated text merely to make debugging easier.

Proposed acceptance for the first useful pilot:

- All deterministic authorization, binding, cancellation and duplicate-write tests pass; every test requiring zero side effects observes zero.
- On a frozen 40-case DE/EN task set, at least 95% of supported unambiguous cases produce the correct draft across the declared repeated-run schedule. Unsupported/ambiguous cases must not be silently represented as successful actions. This is a proposed pilot target, not a measured score or a universal safety guarantee.
- One physical synthetic reminder was approved, written and read back through a fresh EventKit store. The manual route works without inference; offline behavior remains unmeasured.
- Record median and p95 end-to-end latency, task completion, peak memory and thermal/battery behavior on a defined session. Choose performance budgets from those measurements rather than inventing current numbers.
- Exercise launch, relaunch, lock, background, permission denial, missing model assets and airplane-mode/offline behavior. A “local” label is not network evidence.
- Test latest available supported OS plus the declared minimum where practical. Record coverage gaps instead of marking untested versions supported.

The small 2026-11-22 exploratory probes do not meet this pilot evaluation bar. They select the next implementation step.

## 12. Completion and handoff

A useful first milestone is **one real reminder workflow with verified completion**, manual fallback and honest recovery. A publishable prototype additionally needs the evaluation above, an accurate privacy/permission explanation, accessible UI, reproducible builds and an explicit distribution path. Free development installation is a test channel, not a demonstrated distribution strategy; observe provisioning expiry rather than assuming permanent installation.

Keep model research in `MODEL_STRATEGY.md`, alternatives in the atlas, test observations in the device report and product sequencing here. Do not create another competing master plan.

No existing user data is deleted by this plan. No external provider, private-content transfer, paid service, unrestricted controller, new signing change or publication is authorized by a roadmap entry. Already approved scoped device setup and engineering work can proceed without asking for the same permission again.

Source note for slice A: Apple's `GenerationGuide.anyOf` constrains a generated string to enumerated values; the independent gate remains mandatory. [Apple anyOf reference](https://developer.apple.com/documentation/foundationmodels/generationguide/anyof(_:))
