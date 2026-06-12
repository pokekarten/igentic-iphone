# ChatGPT Next Task

After Codex opens a Draft PR for `codex/bootstrap-open-source-repo`, ChatGPT should review the PR before merge.

## Review checklist
- Confirm ZIP archives are not committed.
- Confirm `.build/`, `node_modules/`, DerivedData, logs, secrets, certificates, provisioning profiles, and model weights are not committed.
- Confirm expected open-source files exist: `README.md`, `LICENSE`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `AGENTS.md`, `PROJECT_STATE.md`.
- Confirm iOS Swift package files exist under `ios/`.
- Confirm `npm run validate` and `cd ios && swift test` pass.
- Confirm `.github/workflows/swift.yml` exists or Codex clearly reported a workflow-permission block.
- Keep PR Draft until all checks pass.
