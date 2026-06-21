# Five-Line Session Handoff

Issue: #35

Every meaningful iGentic work session should end with:

```text
Repo: pokekarten/igentic-iphone
Done:
Current blocker:
Next smallest step:
Learning / no new rule needed:
```

## Usage rules

- Keep iGentic separate from Pokekartenkiste.
- Keep every line short, source-backed and privacy-safe.
- Do not include secrets, environment data, private raw data or unrelated project context.
- For pull requests, reference the latest verified head when the result depends on PR state.
- Preserve unrelated tests and safety behavior unless deletion is explicitly scoped.

## Learning rule

Create or update an issue, checklist or runbook only when a learning changes future behavior or prevents a recurring failure. Otherwise use `Learning / no new rule needed: no new rule needed`.

The template is an adoption aid. Issue #35 should close only after future meaningful iGentic sessions demonstrate sustained use of this format.
