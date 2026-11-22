# Physical iPhone Air validation — 2026-11-22

Status: `PARTIAL`. Evidence classes are stated per result. This is a bounded engineering test, not production certification.

## Tested inputs

- Physical iPhone Air, iOS 27.2.1 build 24B156, USB paired, Developer Mode enabled.
- Mac: macOS 27.2.1, 8 GB unified memory; Xcode 27.2 (27B52).
- Installed diagnostic app source: `c2f97cded4d789a8bb0c0bafa1ec16d50fdaa72e` (PR #379 head at inspection).
- Additional host integration: PR #384 at `a40a63c8f52dfe34dfd50a2e0e364a57ba920625` merged locally with PR #380 at `b44848b4d7e8a11e276512b5bda87c5801bf1f66`. This includes proposal gate/model changes but is a separate test input from the first installed app.
- Main inspected at `0bb24b7`; open PRs #378–#388 were inventoried live. No GitHub merge or push was performed; the integration merge was local only.

## Automated results

| Check | Result | Evidence class |
| --- | --- | --- |
| Baseline Python script tests | 100 passed | `host_runtime_result` |
| Baseline Swift tests | 288 passed, zero failures | `host_runtime_result` |
| Structure validation of clean source snapshot | Passed | `host_runtime_result` |
| Structure validation in existing checkout | Failed on existing `ios/.build` artifacts; preserved | `host_runtime_result` |
| Integrated Swift tests | 305 passed, zero failures | `host_runtime_result` |
| Integrated Python `tests/` discovery | 6 passed | `host_runtime_result` |
| Integrated Apple local-model synthetic probe | `reviewed`, `approvalRequired`, `policyRequiresApproval` | `host_runtime_result` |
| Signed physical-device diagnostic app build | Passed | `compile_result` |
| Integrated unsigned simulator app build | Passed | `compile_result` |
| Simulator runtime | Failed: initial migration failure; existing simulator IPC server died | `simulator_result` |
| Integrated signed app plus explicit synthetic model harness | Build/install/launch passed | `physical_device_result` |

The Apple model probe used only the committed synthetic plant-reminder phrase. Generated model text was not recorded. Its host result does not prove iPhone inference.

## Physical-device observations

- App installed and launched after signing/provisioning was explicitly authorized.
- Initial installation was blocked by Apple's three-app free-development-profile limit. With separate explicit authorization, only the optional iCTRL companion app was removed. The separate iCTRL test runner and WebDriverAgent runner were retained. Installation then passed.
- Initial approval-policy setup displayed its defaults; confirmed without changing toggles.
- Diagnostics displayed Safety, local/trusted-device dry-run mode, synthetic preview status, synthetic metadata audit and `No private content`.
- The synthetic reminder review displayed the fixed subject, due date, storage and three decisions. Reject produced `Rejected`; Cancel produced `Cancelled`; Approve produced `Approved (no execution)`.
- This approval exercise creates an in-memory receipt only. It did not invoke a reminder-writing tool. The generic review warning says that the action writes persistent data, while the diagnostic entry point says no execution; this is a potentially confusing UI distinction for follow-up.
- Explore opened; typing `privacy` produced `3 results · 1 topic · 2 collections`. Search-field close control dismissed the search UI.
- Scrolling exposed audit/risk metadata, effective approval policy, synthetic model-selection trace and all four scenario rows: local-only summary blocked; critical reminder approval required/pending; external provider check approval required/pending; trusted-device metadata allowed with metadata-only delegation.
- Terminate-and-relaunch succeeded. Initial setup did not reappear; the synthetic decision reset to `Not reviewed`, consistent with its in-memory scope.
- WebDriverAgent 16.15.3 reported ready through the local PhoneUse API. UI tree reads, screenshot, taps, swipes and synthetic text input worked on this device.
- PhoneUse `dismiss_keyboard` failed with HTTP 503; subsequent tree read succeeded. The visible search close control worked. Do not count generic keyboard dismissal as passing.
- Minis 1.16 (25) launched to onboarding and required provider setup before model selection/conversation. No provider login was performed.
- Mimi 2.0.1 (100134) launched to `Connect a computer`. Pairing and phone-side approval mode remain unverified; no agent session was started.

## Preflight finding

PR #388's read-only checker at `c4f486a4c570746122e9907274ba2f2de07ab530` returned one physical device, `physical_states=["unknown"]`, and not-ready because this Xcode lists the device as `available (paired)`. Direct device details, successful installation and launch established usability independently. The checker intentionally accepts only `connected`; its text parser does not recognize the observed compound state. A future change should distinguish transport readiness from parser coverage and test actual Xcode output without publishing identifiers.

## Coverage limits

No real contacts/messages/calendar/health/location content was used. No paid model or billing fallback was enabled, and no external model-provider call was made for the tests recorded here. Signed-in Codex was used for this engineering session. Network absence was not measured and must not be inferred from UI labels. VoiceOver focus order, Dynamic Type, prolonged battery/thermal behavior, peak memory, OOM, reboot persistence, iCTRL RPC/control, ARTEMIS runtime, Mimi session execution and authenticated Minis inference remain untested in this run. Historical tests are not promoted into current evidence.

The related Brain, Playbook, SLM Lab and Regulation Lab READMEs were read live to establish ownership. They are routing, process, model research and documentation surfaces, respectively; this was not a full code/test audit of those repositories.

## Physical Apple local-model probe

The isolated acceptance clone contains a local-only, explicit-launch-argument synthetic physical-model harness. It adds an overlay and calls the existing `AppleOnDeviceProposalPreview` only when launched with `--synthetic-local-model-probe`. This harness is not committed or pushed. The installed integrated build includes it; ordinary launch does not activate it.

All three sequential physical-device attempts with the same fixed public-safe plant-reminder input returned:

```text
PHYSICAL_MODEL_PROBE=reviewed; disposition=blocked; reason=unknownAction
```

The local model call completed and the proposal gate rejected the output safely. The desired reminder proposal was **not** accepted in any of these three attempts. This is a functional-quality failure for that input, alongside a successful rejection boundary. Do not present the successful Mac `approvalRequired` result as an iPhone success, and do not infer general model quality from this tiny sample. No generated model text, action execution or private input was involved.

PhoneUse's unauthenticated device-list endpoint returned HTTP 401, and its listener was observed on `127.0.0.1:8765` only.

Simulator details: the repository smoke script selected a fresh iPhone simulator whose initial iOS migration failed after approximately 79 seconds. A separate attempt on an already booted simulator encountered Mach IPC error -308; screenshot capture additionally required explicit selection between its two displays, and later commands reported the simulator shut down. Neither attempt proves successful app execution in the simulator. No simulator reset or deletion was performed.

Current GitHub checks for PR #388 were all successful at inspection; the observed physical-state parser coverage limitation remains despite those fixture tests.

Local evidence: the two isolated source directories are `iphone-validation-20261122` and `iphone-validation-integrated-20261122` beside the main checkout. Sanitized screenshot/model result artifacts were kept outside Git. Temporary raw Xcode logs remain local and are not suitable for publication because tool output may contain signing or device identifiers.

Final state: integrated test build left installed and relaunched normally; the opt-in model overlay was absent. PhoneUse lease was released. The PhoneUse API and WDA launcher started by this run were stopped. Existing source changes/build caches were preserved. Documentation changes remain local and unpublished.

## Concept follow-up: constrained action generation — 2026-11-22

The [canonical completion plan](../PROJECT_COMPLETION_PLAN.md) now uses these observations to prioritize a verified reminder workflow, explicit local sharing and optional bounded Mac jobs. These are proposed product capabilities, not completed device tests.

The isolated integrated checkout was changed to constrain `iGenticGeneratedActionCandidate.actionName` with Apple's `GenerationGuide.anyOf(["diagnostics.read", "reminder.create", ""])`. The existing independent gate remains authoritative. This is a local source change on top of the integration, not a change already shipped on `main`. [Apple API reference](https://developer.apple.com/documentation/foundationmodels/generationguide/anyof(_:))

The explicit-launch test harness was extended with a fixed fixture selector. It accepts only named, embedded public synthetic fixtures, never arbitrary argument text. Generated content is still neither returned nor logged. No action executor or provider was added.

Validation after the change:

- All 305 integrated Swift tests passed with zero failures.
- Signed physical-device build, installation and launch passed using the already authorized development profile.
- The fixed Mac host probe again returned `reviewed/approvalRequired/policyRequiresApproval`.

| Physical fixture | Attempts | Observed gate result | Assessment |
| --- | --- | --- | --- |
| `Make a synthetic reminder to water a demo plant.` | 3 | All `approvalRequired/policyRequiresApproval` | Correct action category at the preview gate; original three attempts had been `blocked/unknownAction` |
| `Erstelle eine synthetische Erinnerung: Demo-Pflanze gießen.` | 3 | All `approvalRequired/policyRequiresApproval` | Correct action category at the preview gate; one observation recovered after transient HTTP 503 |
| `Show the static diagnostics preview.` | 1 | `previewOnly/safeReadOnlyPreview` | Expected gate result |
| `Zeige die statische Diagnosevorschau.` | 1 | `previewOnly/safeReadOnlyPreview` | Expected gate result |
| `Change the wallpaper to blue.` | 1 | `previewOnly/safeReadOnlyPreview` | **Semantic failure**: unsupported task incorrectly mapped to diagnostics instead of abstaining |

There were nine model attempts. One `source_fast` observation failed with HTTP 503 during the third German reminder attempt; WDA remained ready and one subsequent source read recovered the completed result without relaunching or repeating inference. The raw measurement preserves the failed observation. Completed observations without that interruption took roughly 1.2–2.7 seconds from launch request to UI observation; this includes launch and test transport and is **not** inference latency or a performance benchmark.

Eight supported-task attempts produced the expected gate category; the unsupported task did not abstain. Because raw proposed titles were not collected, this does not establish exact title correctness. The schema fix improves the specific observed action-format failure while leaving a demonstrated intent-selection limitation. No reminder, wallpaper change or other side effect was executed. This small exploratory set is not the frozen pilot benchmark described in the plan.

Sanitized local measurement: `iphone-validation-20261122-constrained-results.json` beside the checkouts. Original failure evidence remains in the earlier report and measurement. Build/transport logs stay outside Git because they can contain private device/signing metadata.

Follow-up final state: updated integrated app installed and relaunched without probe arguments; diagnostics visible and probe overlay absent. Unauthenticated PhoneUse device-list access again returned HTTP 401. The test lease was released; the API listener, Mac WDA launcher and physical WDA runner were confirmed stopped. The diagnostic app remained running. Integrated source structure, documentation references/links, validation markers and diff whitespace checks passed. Changes remain local and unpublished.

## Manual reminder workflow follow-up — 2026-11-22

This result advances slices B and C in the [completion plan](../PROJECT_COMPLETION_PLAN.md). The code under test was built from an isolated integration checkout based on local merge `69a331e` with uncommitted reminder-workflow changes. It was signed, installed and launched on the same physical iPhone Air. The app implementation remained in that isolated checkout; I recorded this result in the report and plan as local documentation changes. GitHub was not changed at that time.

The full integrated Swift suite passed again: `swift test -j 1` reported 319 tests and zero failures. The build emitted one existing deprecation warning in `ios/Sources/ModelResearchSupport/AppleFoundationBaseline.swift` for the `GenerationOptions` initializer. The device build had already succeeded for this exact integrated source state before installation.

With the user's explicit approval, iOS granted iGentic full Reminders access. The app displayed the exact synthetic title `iGentic Test – Pflanze gießen`, due 2026-11-23 18:00 Europe/Berlin, and classified the default destination as system-synced personal storage. The review warned that the item could sync through the configured account. One approval was submitted. The app then showed `Erinnerung erstellt und zurückgelesen` (`physical_device_result`).

The EventKit executor attempted one save and did not retry. It opened a fresh `EKEventStore` and looked up only the newly returned `calendarItemIdentifier`; title, due components, timezone, completion state and calendar/source identity matched. It did not enumerate or search existing reminders. The exact target/account identifiers and raw screen content were not retained. The authorized test reminder remains in the default list and may sync; the iOS full-access grant also remains enabled for iGentic.

PhoneUse's lease was released, and the loopback API plus WDA runner were stopped after the result was read. No second reminder write, provider call, paid service, commit or push occurred. This establishes the one permitted manual happy path; it does not establish permission-denial behavior on-device, language-to-task extraction, reliable general model intent selection, accessibility, offline behavior, or lifecycle recovery.

## Local model-to-reminder draft follow-up — 2026-11-22

The isolated iOS integration checkout now contains a distinct user-typed reminder proposal path. It sends a bounded instruction only to Apple's on-device `SystemLanguageModel.default` through a fresh `LanguageModelSession` with `tools: []`. Output is a constrained action/title/date candidate. AgentCore then rejects unsupported actions and sensitive/unsafe titles, resolves the Gregorian local time in the device's IANA zone, rejects past, nonexistent or repeated local times, and returns only an editable title/date draft. The screen keeps the manual form available. Neither the model service nor the probe has an EventKit writer or approval API; saving still requires the existing exact human-bound receipt and one-shot workflow.

The general action-preview adapter remains public-data-only. This reminder-specific route accepts a short, user-entered instruction classified at most contextual-private, rejects detected sensitive patterns and higher classifications before inference, and uses the system runtime only. It reads no shared files, messages, contacts or existing reminders, and writes no prompt or model output to audit logs.

Validation in the isolated integration checkout:

- `cd ios && swift test -j 1`: **328 tests passed, zero failures**, including deterministic runtime injection, rejected/high-private input, unavailable model, generation failure, unknown/abstaining action, prompt-injection-shaped input, unsafe/sensitive/oversize title, invalid/past date, DST gap/repeated time, changed target/approval and the no-write-before-receipt integration boundary.
- Xcode 27.2 generic iOS app build with `CODE_SIGNING_ALLOWED=NO`: **exit 0**. This verifies iOS SDK compilation only; it is not a signed device install.
- The opt-in Mac probe used only fixed synthetic German fixtures. Across three supported-task attempts it produced typed drafts; the final attempt matched the expected demo-plant/action terms and next-day 18:00 Europe/Berlin date. Earlier attempts did not match the stricter title comparison, although one measured date was correct. Separate one-run probes for an ambiguous-time request and an unsupported wallpaper request both abstained (`invalidProposal`) and attempted no write. Raw model titles/dates were never printed or retained. These are prompt-development observations, not a benchmark or reliability rate.
- The normal probe invocation continued to skip inference without its explicit opt-in flag.

The physical iPhone Air is currently paired and listed as available. Installing this newer build was blocked when Xcode reported that no Apple account was configured for the selected development team and no matching local provisioning profile existed. This occurred even with provisioning updates enabled. No credentials were entered, no profile/account state was changed, and the previously installed app, its data and the existing authorized test reminder were left untouched. Therefore **new reminder-model inference has not been tested on the iPhone**. The prior manual EventKit write/readback result remains valid for its earlier signed build only.

A detector false positive was also fixed after reproducing that the ordinary phrase “morgen um 18 Uhr” matched the generic IBAN-like regex. The detector now checks recognized IBAN jurisdiction prefixes, plus an explicitly labeled or digit-dense fallback; the regression and full suite pass. This country-prefix set must be maintained if IBAN participation standards add jurisdictions.

No additional reminder was created. The existing test reminder and full Reminders permission remain as previously approved. No new dependency, model weights, external inference, paid model or billing fallback was introduced. Firecrawl's official Apple-document search reported 8 search credits plus 1 page-scrape credit; no billing activation was performed. The changed code and this evidence still require publication to the existing feature/documentation Draft PRs; `main` was not changed.


## 2026-11-22 exact-head GitHub CI and final verification

The corrected source is now recorded in Draft PR [#390](https://github.com/pokekarten/igentic-iphone/pull/390), head `5f7b4350556b1f4e6fb284b64e5a5e37f02fef51`, based on #386 at `91452b969ac015470ff3ec54f4b9a8020e641289`. The exact comparison is **20 commits ahead, 0 behind, 18 changed files**. The documentation update is recorded in Draft PR [#379](https://github.com/pokekarten/igentic-iphone/pull/379); the first verification run used head `373f96097e4ef50326ab6334713483bc5b49e06d`, and this final CI addendum is on that same PR.

On PR #390's exact code head, GitHub Actions completed successfully:

- macOS Swift package build and tests: **378 tests passed, zero failures**.
- Linux Swift package build and tests: **377 tests passed, zero failures**.
- Apple Foundation Models baseline host compile: passed.
- Repository structure validation, Repo Audit, PR Change Scope, Pull Request Quality and Docs Consistency: passed.
- iOS App Wrapper: unsigned simulator build, install, launch, screenshot, terminate and relaunch all passed.

On PR #379's exact documentation head, GitHub Actions completed successfully: **340 macOS tests** and **339 Linux tests**, zero failures; Apple Foundation Models host compile, repository structure, Repo Audit, PR Change Scope, Pull Request Quality and Docs Consistency also passed.

The first Linux run on #390 exposed SwiftPM discovery incompatibility for four synchronous main-actor tests; the test methods were made async. Its first strict macOS package compile also exposed an actor-boundary transfer of the non-Sendable EventKit store through the async permission API. The adapter now invokes EventKit's callback API on its owning actor and returns only the granted Boolean through a checked continuation; the exact-head macOS and Linux suites both pass after this fix.

Local verification on the integrated checkout also passed: `cd ios && swift test -j 1` (**328 tests, zero failures**), `git diff --check`, and Xcode 27.2 generic iOS app compilation with code signing disabled. These results are host/compile evidence. The new model-driven route is still not signed, installed or inferred on the physical iPhone because Xcode has no configured Apple account session for the selected team and no matching provisioning profile. The separate earlier, explicitly approved manual EventKit reminder write/readback belongs to its earlier signed app revision. No additional reminder was created. Both pull requests remain Draft and unmerged; `main` was not changed.