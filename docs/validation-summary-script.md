# Validation Summary Script

`scripts/validation_summary.py` is implemented on `main` and is the current
source of truth for the local validation summary helper.

It remains dependency-free and wraps the existing validation commands only:

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

The script does not replace those commands, loosen validation requirements,
call external services, persist data, use secrets, invoke models, or perform
app/device actions.

Expected output format:

```text
iGentic validation summary
[PASS|FAIL] Repo structure
[PASS|FAIL] Swift tests
[PASS|FAIL] Swift build
```

Current status: complete, verified, and no longer tied to an open implementation
issue.
