# iPhone Air Validation Report

> Status: `NOT_RUN`
>
> Replace this status only after a real physical-device run. Allowed values: `NOT_RUN`, `PARTIAL`, `FAILED`, `PASSED_WITH_LIMITATIONS`.

## Report identity

- Test date:
- Timezone:
- Tester:
- Repository commit SHA:
- Branch or tag:
- Related issue:
- Related pull request:

## Evidence vocabulary

Label every finding with one of:

- `OBSERVED`: directly seen during this physical-device run.
- `AUTOMATED`: proven by a named command or GitHub Actions result for the tested commit.
- `ASSUMED`: expected but not directly verified.
- `NOT_AVAILABLE`: prerequisite or tool was unavailable.
- `FAILED`: attempted and failed.

## Device and toolchain

| Field | Value | Evidence state |
| --- | --- | --- |
| Device model |  |  |
| iOS version |  |  |
| Mac model |  |  |
| macOS version |  |  |
| Xcode version |  |  |
| Build configuration |  |  |
| Network state during test |  |  |
| Apple Developer Team selected locally | yes / no / not available |  |

Do not record Apple account email addresses, team identifiers, device UDIDs, signing certificates or provisioning-profile contents.

## Repository baseline

| Check | Result | Evidence reference |
| --- | --- | --- |
| `python3 scripts/validate_repo_structure.py` |  |  |
| `cd ios && swift test` |  |  |
| `cd ios && swift build` |  |  |
| GitHub Actions checks for tested commit |  |  |

## App-wrapper readiness

| Check | Result | Evidence state / note |
| --- | --- | --- |
| Installable iOS app target exists |  |  |
| App imports local `iGenticApp` package product |  |  |
| App root presents `DiagnosticView` |  |  |
| Unique bundle identifier selected |  |  |
| Local signing configured |  |  |
| No signing material committed |  |  |

If an installable app target does not exist, stop here and set overall status to `PARTIAL` or `NOT_RUN`. A Swift package build alone is not a physical-device validation.

## Build, install and launch

| Step | Result | Evidence state | Exact error or limitation |
| --- | --- | --- | --- |
| Resolve local package |  |  |  |
| Build for physical device |  |  |  |
| Sign |  |  |  |
| Install |  |  |  |
| First launch |  |  |  |
| Relaunch |  |  |  |

## Diagnostic UI observations

| Observation | Result | Evidence state | Notes |
| --- | --- | --- | --- |
| `iGentic Diagnostics` title visible |  |  |  |
| Safety section visible |  |  |  |
| Operating mode visible |  |  |  |
| Synthetic metadata audit status visible |  |  |  |
| Validation status visible |  |  |  |
| `No private content` visible |  |  |  |
| Four scenario rows visible |  |  |  |
| Route/policy/approval/delegation readable |  |  |  |
| Raw synthetic task sentences absent |  |  |  |
| Real user content absent |  |  |  |
| VoiceOver focus order checked |  |  |  |
| Dynamic Type checked |  |  |  |

## Synthetic scenario results

| Scenario ID | Route observed | Policy observed | Approval observed | Delegation observed | Match expected result? |
| --- | --- | --- | --- | --- | --- |
| `local-only-summary` |  |  |  |  |  |
| `critical-reminder` |  |  |  |  |  |
| `external-provider-check` |  |  |  |  |  |
| `trusted-device-metadata` |  |  |  |  |  |

## Privacy and capability checks

- [ ] Synthetic data only.
- [ ] No contacts, messages, calendars, photos, health, financial or location data used.
- [ ] No API key or secret required.
- [ ] No provider configured.
- [ ] No App Intent or real action executed.
- [ ] No unexpected permission request observed.
- [ ] Evidence attachments contain no private identifiers.

Network note:

- Observation method:
- What was directly observed:
- What was not measured:

Do not convert “no traffic noticed” into a formal claim that no network activity is possible.

## Qualitative performance

| Area | Direct observation | Measurement used? | Limitation |
| --- | --- | --- | --- |
| Launch responsiveness |  |  |  |
| Scrolling responsiveness |  |  |  |
| UI stability |  |  |  |
| Device temperature |  |  |  |
| Memory |  |  |  |
| Energy |  |  |  |

Use qualitative language unless an actual measurement tool was used. Do not publish comparative or production-readiness claims from this report.

## Failures and unresolved questions

1.
2.
3.

## Facts versus assumptions

### Observed facts

- 

### Automated evidence

- 

### Assumptions not yet verified

- 

### Not available during this run

- 

## Final assessment

- Overall status:
- What this run proves:
- What this run does not prove:
- Smallest next action:
- Retest required: yes / no

## Evidence attachments

List only sanitized evidence:

- Screenshot or recording:
- Build log excerpt:
- GitHub Actions run:
- Other:

## Sign-off

I confirm that this report distinguishes physical-device observations from automated evidence and assumptions, and that no private data, secret, account identifier or device identifier is included.

- Tester:
- Date:
