# Validation Summary Script

This note records the intended scope for a local validation summary helper.

The helper should remain dependency-free and should only wrap existing validation commands:

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

It must not replace those commands, loosen validation requirements, call external services, persist data, use secrets, invoke models or perform app/device actions.

Expected output format:

```text
iGentic validation summary
[PASS|FAIL] Repo structure
[PASS|FAIL] Swift tests
[PASS|FAIL] Swift build
```

Issue #17 remains the preferred implementation target once a code-edit path is available. Issue #1 should remain open until validation evidence is recorded for the latest `main` commit.
