# Qwen Mac-only local smoke: fail-closed response boundary

This is a **Mac host validation**, not a native iPhone inference test, nor a replacement for the native model-policy gate. It does not authorize actions, contact user data or copy model weights. Only a hardcoded synthetic English prompt is sent to the fixed loopback address `127.0.0.1`. Invoke explicitly:

```sh
python3 scripts/ollama_local_output_probe.py
python3 scripts/ollama_local_output_probe.py --run --model qwen3:4b
python3 -m unittest discover -s scripts -p 'test_ollama_local_output_probe.py'
```

The first call never invokes a model. The second requires a *previously installed local Ollama model* and an already-running local Ollama daemon. It emits only disposition and numeric durations, not raw model output. No network downloads or remote targets are supported. The optional model request includes `think: false`, but this is **not** a guarantee that the model will omit reasoning. The script deliberately rejects responses with any extra text, Markdown fences, `<think>` content, or appended JSON. Even a clean result is `synthetic_preview_only`, never execution or approval.

Observed manual host experiment on 2026-11-21, MacBook Neo 8 GB, Ollama 0.32.15, `qwen3:4b`, one cold synthetic request: response contained an extraneous reasoning preamble plus a `</think>` marker before JSON despite the request's nonthinking intent. Approximately 47.04 s elapsed; reported Ollama total duration 40.19 s, 51 output tokens and 4.13 s evaluation. This is a **single uncontrolled host observation**, not an iOS benchmark or statistically valid latency comparison. Keep model inference opt-in and avoid heavy simultaneous loads on this 8 GB machine.

Future iOS integration should use the official pinned `ggml-org/llama.cpp` XCFramework approach and its SwiftUI sample, with verified GGUF provenance, memory-pressure measurements on physical iPhone Air, and typed output passed to `UntrustedActionProposalGate`. No inference adapter should parse an arbitrary substring of model output as authorization.
