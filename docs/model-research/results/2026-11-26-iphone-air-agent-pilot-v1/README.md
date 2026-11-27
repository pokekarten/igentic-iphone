# Physical iPhone Air — 24-case agent pilot

2026-11-26. Three local MLX candidates, 24 new synthetic requests each, 12 English/12 German, identical prompt and tool declarations, fresh session per case. Twelve positive requests, four missing information, four unsupported, four explicit prohibitions. No dispatcher or actions; exact function and typed argument, or exact CLARIFY/NO_CALL sentinel. Negative call-or-rejection counts any parsed call or parser rejection on a negative fixture, not an actual device effect. A missing sentinel without a call remains an exact-score failure.

| Candidate | Positive /12 | Negative /12 | Negative call or parser rejection /12 | Total /24 | Median case ms | Max sampled app footprint bytes |
|---|---:|---:|---:|---:|---:|---:|
| MiniCPM5 1B | 5 | 0 | 10 | 5 | 404 | 745998968 |
| Qwen3.5 0.8B | 8 | 4 | 7 | 12 | 610 | 655231368 |
| Qwen3 0.6B | 4 | 6 | 0 | 10 | 122 | 544934208 |

All 72 generations completed, no token caps, all sampled case thermal states nominal. Debug build, single session order, no controlled battery/ambient conditions. Footprint is the Mach task physical footprint sampled before/after model load and after each case, not continuous or guaranteed peak, GPU allocation or total device memory. First visible chunk or parsed tool event latency is not raw TTFT. Prompt/decode durations are runtime-reported. No power measurement. Main app and seven existing staged model inventories preserved. Model weights and device identifiers not committed. All records validated using scripts/agent_v1_receipt.py. The model manifests and source hash reference the repository, not hardware attestation. No production qualification; this is a small exploratory pilot, not the full planned 240-case benchmark or independent statistical holdout.
