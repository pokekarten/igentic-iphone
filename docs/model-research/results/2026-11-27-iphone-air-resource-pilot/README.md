# Physical iPhone Air — short resource pilot

2026-11-27. Eleven fresh app processes, identical three synthetic text prompts, greedy up to 64 generated tokens per prompt, fresh sessions, no tools. Signed isolated Debug lab, primary app and previous model/staging inventories preserved. Each MLX candidate passed native artifact verification before load; Apple system provider available. All 33 requests completed.

| Model | App sampled peak MB | MLX peak active MB | Min sampled headroom MB | Load ms | Elapsed ms | Generated tokens | Max thermal |
|---|---:|---:|---:|---:|---:|---:|---|
| Apple Foundation Models | 15 | N/A | 3525 | N/A | 4086 | N/A | nominal |
| Qwen3 4B Instruct | 2537 | 2400 | 1003 | 1053 | 8178 | 164 | nominal |
| Qwen3.5 2B | 1331 | 1151 | 2209 | 1558 | 5445 | 188 | nominal |
| Qwen3.5 0.8B | 691 | 522 | 2849 | 1541 | 4171 | 192 | nominal |
| Qwen3 0.6B | 585 | 475 | 2955 | 833 | 2996 | 183 | nominal |
| LFM2.5 1.2B | 841 | 749 | 2699 | 406 | 1929 | 114 | nominal |
| MiniCPM5 1B | 766 | 704 | 2774 | 806 | 2691 | 183 | nominal |
| LFM2.5 350M | 375 | 321 | 3165 | 380 | 1075 | 116 | nominal |
| Granite 350M | 362 | 306 | 3178 | 537 | 2749 | 125 | nominal |
| SmolLM 135M | 175 | 151 | 3365 | 239 | 2317 | 192 | nominal |
| Falcon-H1-Tiny 90M | 199 | 108 | 3341 | 211 | 3887 | 192 | nominal |

App physical footprint and available-process allowance sampled approximately every 100 ms plus explicit endpoints, including model load. Not guaranteed true peak, total device RAM or independent GPU memory. MLX peak active excludes allocator cache and must not be added to process footprint. Apple system model runs outside the app process; its total memory and actual generated tokens are not measured, and its load time is not exposed. No degrees Celsius API; thermal state is iOS system category, not chip temperature. All thermal samples nominal during this short workload (not endurance). Different actual output lengths, tokenizers and templates; not a controlled throughput benchmark. Fixed sequential order with short pauses, no controlled ambient temperature, charging state or baseline thermal equilibration. No energy measurement. No production qualification. No raw generation, private identifiers or weights committed.
