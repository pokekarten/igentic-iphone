# Codex Next Task

Repository: `pokekarten/igentic-iphone`

## Goal
Bootstrap the open-source iGentic iPhone repository from the verified flat ZIP import.

## Working branch
`codex/bootstrap-open-source-repo`

## Rules
- Do not commit ZIP archives, build artifacts, `.build/`, `node_modules/`, secrets, provisioning profiles, or model weights.
- Extract the attached verified ZIP into the repository root as real files.
- Run repository validation before opening a PR.
- Keep the PR as Draft until ChatGPT reviews it.

## Required validation
```bash
npm run validate
cd ios && swift test
```

## Stop conditions
Stop and report clearly if:
- the ZIP is missing or invalid,
- GitHub/Codex blocks `.github/workflows/**` changes,
- validation or Swift tests fail,
- unexpected secrets or binary/model-weight files are present.
