# iPhone Air Physical-Device Evidence Protocol

Status: measurement contract, no device result  
Parent: Issue #83  
Last reviewed: 2026-08-03

## Purpose

This protocol defines the minimum reproducible evidence required before iGentic may claim that one exact model/runtime artifact ran on one physical iPhone Air configuration. It separates device measurements from source claims, compile results, host runs and simulator runs.

The protocol measures proposal-generation behavior only. It does not transfer policy, approval, schema validation, audit or execution authority to a model.

## What this protocol can establish

A conforming result can establish only that:

- the exact recorded app build, backend and artifact were tested;
- the exact recorded prompt profile and decoding settings were used;
- the listed measurements and failures were observed on the recorded physical device configuration;
- cancellation, timeout, recovery and rollback behavior were exercised as recorded;
- the exported or quantized artifact retained the reported benchmark quality.

It cannot establish behavior on another device, OS, app build, model revision, tokenizer, template, quantization or runtime version.

## Preconditions

Do not begin a device run until:

1. a runtime-matrix record exists for the exact backend/artifact combination;
2. model, tokenizer, template, runtime and app revisions are immutable;
3. the model artifact and package hashes are recorded;
4. license and distribution gates are passed for the test;
5. compile and required pre-device runtime checks are complete or explicitly documented as not applicable;
6. deterministic fallback and rollback paths are defined;
7. cancellation and timeout controls exist;
8. the test uses synthetic, public-safe prompts only;
9. no serial number, UDID, account identifier, contact, message, file or other personal content will be captured;
10. the result template validates as JSON and contains no pre-filled measurements.

A failed precondition blocks the run. It is not converted into an assumption.

## Device identity without personal identifiers

Record only the technical configuration needed for reproducibility:

- Apple hardware model identifier or commercially named model;
- OS version and build where available;
- total and available storage at test start;
- device thermal state at test start;
- battery percentage and charging state at test start;
- low-power-mode status;
- relevant accessibility or locale setting only when it affects the tested behavior.

Never record a serial number, UDID, IMEI, Apple ID, phone number, advertising identifier or precise location.

## App and artifact identity

Record the exact:

- repository commit;
- app version and build number;
- build configuration;
- runtime/backend ID and immutable revision;
- model ID and immutable revision, or `system_managed` when the system does not expose one;
- tokenizer and prompt/chat/tool-template revisions;
- artifact SHA-256 and package size;
- export and quantization configuration;
- minimum deployment target and SDK version;
- feature flags relevant to the runtime path;
- runtime-matrix record ID.

A changed artifact or build requires a new result record.

## Prompt and decoding profile

Use only versioned synthetic prompt profiles. Record:

- prompt-profile ID and hash;
- benchmark or scenario-set ID and hash;
- language distribution;
- context length;
- maximum output tokens;
- temperature, top-p, top-k and seed where supported;
- repetition controls;
- stop sequences;
- schema or structured-output configuration;
- timeout threshold;
- cancellation trigger point.

Do not edit prompts between candidate runs without creating a new profile revision.

## Test environment preparation

Before measurements:

1. reboot only when the run plan requires a documented cold-device condition;
2. record charging, low-power, network and background-app conditions;
3. close unrelated apps when the protocol calls for an isolated run;
4. wait until the initial thermal state is recorded;
5. verify available storage;
6. verify the deterministic fallback path before loading the model;
7. verify that logs contain no prompt text or private data unless the synthetic prompt artifact is explicitly approved for publication;
8. synchronize the device clock sufficiently for duration measurements.

The preparation procedure must be identical across compared artifacts or the difference must be disclosed.

## Required measurement sequence

### 1. Availability and load

Record:

- backend availability result;
- cold load duration;
- cold load success or failure;
- warm load duration for each repeat;
- package verification result;
- load-time crash, OOM or timeout;
- post-failure recovery and fallback behavior.

“Cold” means the runtime/model is not resident according to the documented preparation. “Warm” means the same app process and runtime remain available. State the exact definition used.

### 2. Proposal generation

For every scenario record:

- scenario ID;
- start and completion timestamps or monotonic durations;
- time to first token or first complete structured fragment where observable;
- generated token count where the backend exposes it;
- decode duration and tokens per second where meaningful;
- normalized proposal validity;
- repetition and truncation flags;
- timeout or failure category;
- fallback outcome.

Do not estimate token speed when token counts are unavailable. Use `null` and explain the limitation.

### 3. Memory and storage

Record peak memory only when the measurement method is available and documented. Include:

- measurement tool and version;
- whether the value is process, resident, allocated or system-wide memory;
- baseline before load;
- peak during load;
- peak during generation;
- value after unload or rollback;
- observability limitations.

Do not substitute model file size for peak memory.

### 4. Battery and elapsed duration

Record:

- battery percentage at start and end;
- charging state;
- elapsed duration;
- number of completed scenarios;
- screen state and brightness policy where controlled;
- network state;
- any interruption.

A single battery-percentage change is coarse evidence. Do not infer precise energy consumption without suitable instrumentation and repeated runs.

### 5. Thermal behavior

Record the platform thermal-state sequence and timestamps when available:

- nominal;
- fair;
- serious;
- critical.

Also record visible throttling, forced pauses, app termination or cooling periods. Do not infer internal temperature from surface feel.

### 6. Cancellation and timeout

Exercise at least:

- cancellation during model load where supported;
- cancellation during generation;
- configured timeout during generation;
- repeated cancellation followed by a clean retry.

Record:

- trigger point;
- acknowledgement time;
- cancellation latency;
- whether generation actually stopped;
- whether memory/resources were released;
- whether a partial proposal was discarded;
- whether any side effect was attempted;
- fallback and audit outcome.

A cancellation API existing in source code is not cancellation evidence.

### 7. Crash, OOM and recovery

Record both observed failures and deliberately bounded failure tests where safe. For each failure record:

- phase;
- sanitized error category;
- app/process survival;
- corrupted or partial output handling;
- model/runtime unload result;
- restart requirement;
- deterministic fallback availability;
- whether the next clean run succeeded;
- sanitized raw-evidence reference and hash.

Never provoke unsafe device conditions. Stop immediately at critical thermal state, repeated crash loops, uncontrolled storage growth or inability to recover deterministic behavior.

### 8. Post-export benchmark quality

Run the same immutable benchmark and evaluator contract used for the untouched baseline. Record:

- benchmark ID and SHA-256;
- evaluator revision;
- normalized-proposal schema revision;
- baseline result hash;
- exported/quantized result hash;
- every component metric separately;
- German/English differences;
- repetition and truncation rates;
- comparison limitations.

A runtime artifact cannot advance solely because it is fast or small. Quality and safe-failure behavior remain gates.

## Repetition and aggregation

A result must state the number of cold, warm and generation repetitions. Retain each raw observation before calculating summaries.

When enough observations exist, report:

- count;
- minimum;
- median;
- maximum;
- arithmetic mean only when useful;
- dispersion measure such as standard deviation or percentile range;
- excluded observations and reasons.

Do not hide crashes, timeouts or thermal throttling by averaging only successful runs.

## Evidence capture

Raw evidence may include sanitized logs, Instruments exports, benchmark result JSON and test-run metadata. Every referenced artifact must have:

- stable location without embedded credentials;
- SHA-256;
- capture tool and version;
- creation date;
- privacy review status;
- retention rule.

Screenshots are optional and must contain no notifications, account names, personal content, identifiers or location data.

## Result states

Use one overall result state:

- `not_run`
- `passed`
- `failed`
- `blocked`
- `invalid`

`passed` means all required identity, measurement, cancellation, recovery, privacy and benchmark fields are complete for the defined scope. It does not mean production-ready.

`invalid` is required when artifact identity, configuration, timing method, privacy boundary or raw evidence cannot be trusted.

## Review gates

An independent reviewer verifies:

- exact artifact/build identity;
- no pre-filled or inferred measurement;
- synthetic prompt use;
- no personal identifiers or private content;
- timing and memory methods;
- inclusion of failed runs;
- cancellation, timeout and rollback evidence;
- benchmark/evaluator identity;
- hashes of raw and summarized evidence;
- limitations and prohibited inferences.

The reviewer records `ACCEPT`, `REWORK` or `REJECT` for the evidence package. This review decision is separate from any model-selection decision.

## Stop rules

Stop the run and record a failure when:

- critical thermal state is reached;
- the app enters a crash loop;
- cancellation does not stop generation within the defined safe bound;
- the fallback path fails;
- storage or memory behavior becomes uncontrolled;
- private data or a personal identifier appears in logs;
- the artifact hash differs from the approved record;
- the test configuration changes unexpectedly.

Do not continue merely to obtain a complete metric table.

## Publication boundary

A public result may contain technical model identifiers, OS/build versions, aggregate measurements, hashes and synthetic scenario IDs. It must not contain:

- serial numbers, UDIDs, IMEIs or account identifiers;
- personal prompts, messages, contacts, files or photos;
- credentials, signed URLs or private storage paths;
- raw crash data that exposes user or device identity;
- model weights or gated artifacts;
- claims extending beyond the exact tested configuration.

## Required output

Use `device-result-v0.example.json` as the structural template. A real result must replace every placeholder, retain `null` for genuinely unobservable measurements, link to the matching runtime-matrix record and record an explicit evidence-review decision.

The example file is not a device result and must never be cited as proof of execution.
