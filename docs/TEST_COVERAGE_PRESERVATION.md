# Test Coverage Preservation Gate

Issue: #34

## Purpose

Runtime and test pull requests must preserve unrelated existing test coverage. A narrow PR may add focused tests or change tests that are directly in scope, but it must not silently delete existing safety coverage.

## Review rule

For every runtime or test PR, reviewers should compare changed test files against the current base branch and confirm:

- new tests are additive unless the issue explicitly scopes replacement,
- unrelated safety tests remain present,
- removed or replaced tests are listed in the PR description,
- unexplained test deletion is a merge blocker,
- the final gate is checked against the latest PR head SHA.

## Mini-loop for reviewers

1. List changed files.
2. Identify test files.
3. Compare each changed test file with the base branch.
4. Check whether any existing test function disappeared.
5. Allow the PR only when removed tests are either in scope or explicitly justified.

## Immediate verification

This document is process-only and does not change Swift runtime behavior. It is verified by inspecting this file and confirming that future PR reviews use this gate before merge.
