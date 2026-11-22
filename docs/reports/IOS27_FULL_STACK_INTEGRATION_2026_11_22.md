# iGentic iPhone — iOS 27 combined integration acceptance

**Date:** 2026-11-22  |  **Scope:** isolated review worktree and Draft GitHub integration PR

This report is an integration **candidate**, not product release or authorization
for merging into `main`. All component PRs remain independently reviewable.
No source branch was force-pushed, rewritten, or merged into main.

## Parent PRs combined

| Order | PR | Purpose | Exact reviewed head |
| --- | --- | --- | --- |
| 1 | #389 | iOS 27-only Xcode baseline | `feef7ab` |
| 2 | #380 | read-only system App Intent | `b44848b` |
| 3 | #381 | untrusted local-model proposal gate | `5a131c9` |
| 4 | #382 | Apple Foundation Models structured preview | `17e0c80` |
| 5 | #384 | opt-in live local-model probe | `1610fb1` |
| 6 | #386 | combined UI test and Swift 6 actor annotation | `cc01d01` |
| 7 | #390 | user-approved reminder draft flow | `7279c79` |
| 8 | #383 | pinned open-weight files validation | `f1ebcd8` |
| 9 | #385 | native GGUF/manifest admission | `f34759d` |
| 10 | #393 | mock-only MCP lab | `84c73a7` |
| 11 | #392 | physical USB evidence and read-only network gate | `fb3ed6a` |
| 12 | #394 | local MCP iPhone Connect and physical-only readiness gate | `a876d6f` |

Excluded by design: #378 ARTEMIS experimental driver, #379 research atlas,
#387 optional Qwen smoke, #388 separate phone-readiness utility, and #391
standalone Mac build preflight. Exclusion does not mean those PRs are invalid.

## Real merge conflicts and isolated resolutions

1. #380 and #386 both declare a native `iGenticDiagnosticsUITests` target
   with different Xcode object IDs. The integration reuses #380's target and
   app scheme, adds the `DiagnosticsUITests.swift` source from #386 to it,
   and keeps all iOS targets at deployment minimum **27.0**. Both distinct
   UI test classes remain active. Follow-up: review the final exact Xcode
   project diff before landing parent PRs.
2. #384 and #390 add separate sections to
   `docs/OPT_IN_LOCAL_FOUNDATION_MODELS_PROBE.md`. The merge preserves both
   locale eligibility requirements and the opt-in synthetic German reminder
   fixture instructions. No local model is called by default.
3. #389 and #394 changed the same README introduction. Both the iOS 27
   baseline and the bounded iPhone Connect plugin introduction are retained.
   The Swift package adds the `iGenticPluginPolicy` executable next to the
   existing probe products.

## Evidence on the Mac (no real iPhone required)

- Xcode 27.2 on MacBook Neo, Swift package `swift test -j 2`: **337/337 passed**
  on exact latest combined head including #386 `cc01d01` and #394 `a876d6f`.
- `python3 scripts/validate_repo_structure.py`: passed.
- Python suites: MCP mock contract **19/19**, GGUF verification **11/11**,
  and iOS27 baseline **11/11**, all passed (41 total).
- `plugins/iphone-connect`: official MCP client, browser MCP Apps UI, fixture
  smoke/service, bounded 128-session receipts, read-only physical readiness,
  and the actual compiled Swift policy helper: **20/20 Node tests passed**.
- Previous combined head: iOS27 signed iPhone Air simulator UI suite **2/2
  passed** (system App Intent and synthetic navigation/review/cancel).
- Latest combined head: independent signed simulator run is a separate
  acceptance gate; see the corresponding PR CI log for the exact result.

## Evidence limitations and safety

- The owner's paired physical iPhone was still **unavailable** to CoreDevice.
  Live read-only doctor on Mac: `configured=true`, `available=false`.
  MobileCLI discovered **zero** reachable real devices. No physical device
  action, screenshot, data read, write, pairing reset, or app installation was
  performed during this integration review.
- Tests involving iOS simulator are *not* evidence of physical iPhone, mobile
  data, VPN/Tailscale iPhone control, reliable iOS background execution, or
  ChatGPT-web connector registration.
- PR #393 mock-only MCP tools overlap names with #394. The two plugins must
  remain explicitly named and isolated; fixture success never proves a
  physical action. No production cross-app control or arbitrary commands.
- Approval remains mandatory for persistent writes. The only UI navigation
  accepted in the experimental plugin is opening bundled app discovery;
  reminder tests only review/cancel synthetic data, not EventKit writes.

## Required sign-off before merge to main

- Review final Xcode target composition, app Intents and least-privilege policy.
- Required GitHub checks green for this exact integration head; accept neither
  old checks nor separate parent checks as sufficient evidence.
- Review dependency/stacked PR order, licenses and privacy policy; ensure
  Codex/ChatGPT plugin endpoints are authenticated and user-authorized.
- Perform a user-authorized physical USB-C test with a newly observed session
  and independently verified result; separately test LAN/cellular afterward.
- Treat all unverified, timed-out or interrupted actions as unknown, never
  retry an uncertain action without explicit reconciliation.
