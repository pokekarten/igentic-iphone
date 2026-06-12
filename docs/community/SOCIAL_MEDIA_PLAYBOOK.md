# Social Media Playbook

Last updated: 2026-06-12

## Strategy

Social media exists to make the project understandable and discoverable. GitHub remains the canonical project space.

The content direction is **build in public for privacy-first personal AI**.

## Primary channels

1. **Instagram** for visuals, carousels and brand/design evolution.
2. **X** for short developer updates, links and research notes.
3. **LinkedIn** for serious positioning and community credibility.
4. **GitHub** for the actual work, decisions and contribution flow.

## Content pillars

### 1. Vision

Explain why local-first personal AI needs a trust/control layer.

Example hook:

> The iPhone does not need to be the strongest AI computer. It needs to be the most trusted one.

### 2. Architecture

Turn system pieces into simple diagrams:

- User
- Controller
- Policy Engine
- Approval Manager
- Task Router
- Local Execution
- Delegation Broker
- Audit Log

### 3. Safety and privacy

Explain policies in plain language:

- local-only default,
- approval before critical actions,
- no automatic sharing of private raw data,
- audit logs for meaningful decisions,
- blocked data classes.

### 4. Open-source community

Invite specific contributions:

- Swift tests,
- privacy reviews,
- logo feedback,
- architecture diagrams,
- device test reports,
- documentation improvements.

### 5. Brand/design

Share the iGentic identity as it evolves:

- logo mark drafts,
- color system,
- app icon mockups,
- approval UI concepts,
- roadmap visuals.

## Instagram carousel format

Use 5 slides:

1. Hook / thesis.
2. Problem.
3. iGentic approach.
4. Architecture or policy example.
5. GitHub CTA.

Example:

1. `Private AI needs a control layer.`
2. `Cloud-first agents can act before users understand the risk.`
3. `iGentic starts local, classifies data and asks before critical action.`
4. `User -> Policy -> Approval -> Action -> Audit Log`
5. `Open-source research. Join on GitHub.`

## X post format

Keep posts direct:

```text
iGentic is exploring a local-first AI control layer for personal devices.

Current rule: policy before action.

No real private data in issues.
No model weights in repo.
Approval before critical actions.

GitHub: <repo link>
```

## LinkedIn post format

Use a more serious tone:

```text
We are building iGentic as an open-source research project for privacy-first personal AI.

The central thesis: the trusted device should control identity, permissions and auditability, while compute can be delegated only when policy allows it.

We are looking for careful contributors in Swift, local AI, privacy review and UX for consent flows.
```

## Weekly cadence

### Week start

- One GitHub roadmap/status post.
- One X technical note.

### Midweek

- One Instagram carousel.
- One issue/PR contributor call.

### Week end

- One LinkedIn summary.
- One GitHub project-state update if meaningful progress happened.

## Hashtag direction

Use sparingly:

- `#OpenSource`
- `#LocalAI`
- `#PrivacyFirst`
- `#SwiftUI`
- `#iOSDev`
- `#PersonalAI`
- `#AIAgents`

Avoid hype hashtags that attract the wrong audience:

- `#MakeMoneyWithAI`
- `#AutonomousEverything`
- `#AIGrowthHack`

## Visual rules

- White or mist background.
- Graphite text.
- Blue/silver accent.
- One idea per slide.
- Use diagrams, not screenshots with private data.
- No Apple logos or product silhouettes.
- Make experimental status visible.

## CTA library

- `Read the roadmap on GitHub.`
- `Open a design feedback issue.`
- `Contribute a device test report.`
- `Review the policy model.`
- `Help us make personal AI safer.`
- `Small PRs welcome.`

## Social safety checklist

Before posting, check:

- Does this imply the app is production-ready? If yes, rewrite.
- Does this imply Apple endorsement? If yes, rewrite.
- Does this contain real private data? If yes, do not post.
- Does this make performance claims without evidence? If yes, cite or remove.
- Does it point back to GitHub for action? If no, add the link.
