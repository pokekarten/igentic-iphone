# Source Verification

This repo separates verified facts from assumptions.

## Rule

For fast-moving topics, verify current official sources before making durable architecture claims.

Fast-moving topics include:

- Apple Intelligence APIs,
- Foundation Models framework,
- Core AI and Core ML,
- iOS background behavior,
- iPhone Air hardware,
- local LLM runtimes,
- model candidates,
- MCP and agent tooling.

## Evidence levels

| Level | Meaning |
| --- | --- |
| Apple official | Apple developer, support or security documentation |
| Project official | Runtime, model, project documentation or model card |
| Research | Paper, benchmark or analysis |
| Community signal | Issue, discussion, benchmark repo or blog post |
| Assumption | Plausible but not yet verified |

## Required wording

Use these labels in docs and issues:

- `Apple-officially available`
- `Technically plausible`
- `Prototype candidate`
- `Speculative / later`

## Do not overstate

Do not overstate iOS background behavior, model-size viability, model API availability, local data access or action automation.

## Update path

When source claims change, update this file, `MODEL_STRATEGY.md`, `PROJECT_STATE.md` and the related issue or PR body.
