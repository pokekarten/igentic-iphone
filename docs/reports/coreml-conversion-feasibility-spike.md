# CoreML conversion feasibility spike

Repository: `pokekarten/igentic-iphone`  
Issue: #111  
Scope: compile-only, no runtime integration

## Target models

- FunctionGemma 270M (`google/functiongemma-270m-it`)
- Qwen3 0.6B (`Qwen/Qwen3-0.6B`)

## Reference

`coremltools` stateful model guide: https://apple.github.io/coremltools/docs-guides/source/stateful-models.html

## Result

**Status: blocked**

### Why blocked

This repository does not contain model weights or a pinned local model artifact for either candidate, and the task explicitly forbids networking / downloads. Because of that, no compile-only `coremltools` conversion could be executed from repository state alone.

### What was checked

- the issue scope was constrained to compile-only research
- no runtime integration was added or requested
- no weights were committed
- no changes were made to `AgentKernel`, `PolicyEngine`, `ApprovalManager`, or any audit / approval path

### Compatibility notes to validate later

When a local artifact is available, the follow-up check should record:

- whether `coremltools` accepts the source graph as-is
- whether stateful-cache support is available for the exported shape
- whether any operator or graph rewrite is required
- whether the candidate can be converted without touching runtime wiring

## Follow-up

If a future run supplies a local model artifact inside the allowed scope, rerun the compile-only conversion check and replace this blocked result with a concrete success or failure record.
