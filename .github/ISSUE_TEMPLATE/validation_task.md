---
name: Validation task
description: Track repository validation, CI, build or test verification.
title: "Validation: "
labels: ["validation", "ci"]
body:
  - type: markdown
    attributes:
      value: |
        Use this template when a task is about proving repository health, CI, Swift build/test status or documentation of validation evidence.
  - type: textarea
    id: goal
    attributes:
      label: Goal
      description: What validation outcome should be proven?
      placeholder: Example: Prove that the current main commit passes repo structure validation, Swift tests and Swift build.
    validations:
      required: true
  - type: textarea
    id: scope
    attributes:
      label: Scope
      description: Which files, workflows or commands may be touched?
      placeholder: Example: PROJECT_STATE.md, docs/CHATGPT_NEXT_TASK.md, docs/VALIDATION.md, .github/workflows/ci-phase-0-validation.yml
    validations:
      required: true
  - type: textarea
    id: required_commands
    attributes:
      label: Required commands / evidence
      value: |
        - [ ] `python3 scripts/validate_repo_structure.py`
        - [ ] `cd ios && swift test`
        - [ ] `cd ios && swift build`
        - [ ] GitHub Actions run checked for the relevant commit
    validations:
      required: true
  - type: textarea
    id: forbidden
    attributes:
      label: Forbidden changes
      value: |
        - No app actions
        - No persistence
        - No networking
        - No external providers
        - No model calls
        - No CoreML runtime changes
        - No App Intents
        - No secrets or real private data
    validations:
      required: true
  - type: textarea
    id: done
    attributes:
      label: Definition of Done
      placeholder: Example: PROJECT_STATE.md records exact pass/fail evidence and Issue #1 remains open unless every required check is proven green.
    validations:
      required: true
