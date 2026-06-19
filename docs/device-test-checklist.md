# Real-Device Validation Checklist

Last updated: 2026-06-19

## Purpose

This checklist prepares a repeatable, privacy-safe real-iPhone validation run for the iGentic diagnostic shell. It does not claim that a physical-device test has happened.

The current repository contains a tested Swift package with an `AgentCore` library and an `iGenticApp` SwiftUI library. A physical iPhone run additionally requires an installable Xcode app target, Apple signing and a connected test device. Those steps are a separate human-device boundary.

## Evidence states

Use exactly one state for every check:

- `OBSERVED`: directly seen during the dated device run.
- `AUTOMATED`: proven by a named GitHub Actions or local command result for the tested commit.
- `ASSUMED`: expected but not directly verified.
- `NOT_AVAILABLE`: the required target, device, account or tool is not available.
- `FAILED`: attempted and did not work; record the exact error.

Never present `ASSUMED` or `AUTOMATED` evidence as a real-device observation.

## 1. Repository and build baseline

Record the exact commit before using Xcode:

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

Checklist:

- [ ] Tested commit SHA recorded.
- [ ] Repository structure validation result recorded.
- [ ] Swift test result recorded.
- [ ] Swift build result recorded.
- [ ] Relevant GitHub Actions run IDs or links recorded.
- [ ] No uncommitted production or signing material is used as evidence.

## 2. App-wrapper prerequisite

Before a physical-device test can start, confirm:

- [ ] An installable iOS app target exists in Xcode.
- [ ] The app target imports the `iGenticApp` package product.
- [ ] The app root presents `DiagnosticView` only.
- [ ] The target contains no networking, provider, model-call, App-Intent or persistence capability.
- [ ] A unique bundle identifier is selected.
- [ ] An Apple Developer Team is selected locally in Xcode.
- [ ] Signing files, provisioning profiles and account identifiers are not committed.

If any item is missing, stop the device run and record `NOT_AVAILABLE`. Do not treat the Swift package build as proof that the app installed on an iPhone.

## 3. Device and environment record

- [ ] Device model recorded exactly as shown by the device or Xcode.
- [ ] iOS version recorded.
- [ ] Xcode version recorded.
- [ ] macOS version recorded.
- [ ] Test date and timezone recorded.
- [ ] Build configuration recorded.
- [ ] Network state recorded as enabled, disabled or not observed.
- [ ] No personal accounts, contacts, messages, calendars, health data or financial data are used in the test scenario.

## 4. Build, install and launch

Record each step separately:

- [ ] Open the installable app project or workspace in Xcode.
- [ ] Select the app scheme rather than a package-library scheme.
- [ ] Link the local `iGenticApp` package product.
- [ ] Confirm the app entry point presents `DiagnosticView`.
- [ ] Connect and unlock the physical test iPhone.
- [ ] Select the physical device as the run destination.
- [ ] Select the local Apple Developer Team under Signing & Capabilities.
- [ ] Confirm that the bundle identifier is unique and contains no private account identifier.
- [ ] Xcode resolves the local package products.
- [ ] The app target builds for the selected physical device.
- [ ] Signing succeeds.
- [ ] Installation succeeds.
- [ ] The app launches without an immediate crash.
- [ ] Relaunch produces the same initial diagnostic state.

For every failed step, capture the exact error text with secrets and identifiers removed.

## 5. Diagnostic UI

Confirm only what is visible on the physical device:

- [ ] Navigation title reads `iGentic Diagnostics`.
- [ ] Safety section is visible.
- [ ] Operating mode is visible.
- [ ] Audit status states that output is synthetic metadata only.
- [ ] Validation status is visible.
- [ ] Privacy status states `No private content`.
- [ ] Four synthetic scenario rows are present.
- [ ] Route, policy, approval and delegation values remain readable.
- [ ] No raw synthetic task sentence is visible.
- [ ] No real user content is visible.
- [ ] VoiceOver focus order is usable or any issue is recorded.
- [ ] Text remains readable at the tested Dynamic Type size or any issue is recorded.

## 6. Synthetic scenario expectations

Use the committed scenario IDs and metadata only:

| Scenario | Expected route | Expected approval | Expected delegation |
| --- | --- | --- | --- |
| `local-only-summary` | local tool | not required | blocked |
| `critical-reminder` | approval required | pending | approval required |
| `external-provider-check` | local tool | not required | approval required |
| `trusted-device-metadata` | local tool | not required | allowed metadata only |

Checklist:

- [ ] All four scenarios appear in stable order.
- [ ] Critical reminder remains approval-gated.
- [ ] External-provider delegation remains approval-gated.
- [ ] Local-only delegation remains blocked.
- [ ] Trusted-device result is metadata-only.
- [ ] No scenario triggers a real action.

## 7. Privacy and network boundary

- [ ] No authentication prompt appears.
- [ ] No contacts, photos, calendar, reminders, health or location permission is requested.
- [ ] No external provider is configured.
- [ ] No secret or API key is required.
- [ ] No real private data is entered.
- [ ] Any network observation is described honestly; absence of observed traffic is not a formal network audit.

## 8. Qualitative performance record

Do not publish unsupported benchmark claims. Record only dated observations such as:

- launch felt immediate / delayed / failed,
- scrolling felt smooth / uneven,
- UI remained responsive / became unresponsive,
- device temperature change was not noticed / noticed qualitatively,
- memory or energy data was not measured unless an instrument was actually used.

Never infer production readiness from one device run.

## 9. Completion rule

A real-device validation result may be called complete only when:

- the exact commit and environment are recorded,
- build, install, launch and Diagnostic UI were directly observed,
- observed facts are separated from assumptions,
- evidence contains no private data or secrets,
- failures and unavailable prerequisites are preserved rather than hidden,
- the completed report uses `docs/reports/iphone-air-validation-template.md`.

Until then, project state must say `real-device validation pending`.
