# Security Policy

## Project status

iGentic iPhone is an experimental research prototype. It is not a production assistant, medical device, financial system, legal advisor or identity wallet.

Security and privacy architecture come before autonomy.

## Supported versions

The project is pre-release. Security review applies to the default branch and active pull requests only.

| Version | Supported |
| --- | --- |
| `main` | Yes |
| releases | Not yet |

## What to report

Please report issues involving:

- unsafe handling of sensitive data,
- missing approval gates for critical actions,
- unintended external delegation,
- data leaks in logs or audit trails,
- insecure storage assumptions,
- unsafe App Intent behavior,
- secret or credential exposure,
- concurrency bugs in safety-critical components,
- model/runtime behavior that bypasses policy controls.

## What not to report as a vulnerability

Because this is an early prototype, the following are expected limitations unless they bypass a stated safety rule:

- incomplete app UI,
- missing model runtime integration,
- stubbed memory or tool interfaces,
- lack of production deployment,
- lack of Apple signing or App Store configuration.

## Reporting process

Do not open a public issue if the report includes secrets, private data, exploit details or a privacy-sensitive proof of concept.

Preferred process:

1. Open a minimal public issue that says a security report exists, without sensitive details, or contact the repository owner privately if possible.
2. Include affected files, expected behavior and observed behavior.
3. Use synthetic examples whenever possible.
4. Do not include real messages, contacts, calendars, health data, financial data, credentials or tokens.

## Security design priorities

The project should preserve these properties:

- Level 4 data must never be delegated automatically.
- Critical actions require approval.
- Drafting is safer than execution.
- External AI delegation must be explicit and minimized.
- Audit logs must not become private-data dumps.
- Local-first behavior is preferred over cloud processing.
- Policy and approval checks must not be bypassed by tools, app intents or delegation code.

## Coordinated fixes

Security fixes should be small and reviewable. A good security PR changes the minimum number of files, adds focused tests and clearly explains the affected data class and action risk.
