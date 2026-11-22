# Native on-device GGUF integrity admission (stacked on artifact verifier PR)

`VerifiedGGUFArtifact` verifies a trusted six-field manifest, checks a regular local GGUF file using an `O_NOFOLLOW` file descriptor, and streams its SHA-256 hash in bounded 1 MiB chunks. It does **not** call inference, parse GGUF internally, download anything, approve an action or grant model permissions. It complements the independent Python preflight in PR #383. Native model IDs now enforce the same canonical two-segment `publisher/model-name` form as that verifier; traversal-like or nested identities are rejected before accessing a file.

This Swift component is iOS/macOS capable with CryptoKit. On unsupported platforms it rejects verification with `digestUnavailable`; Linux CI may compile the contract but cannot claim a successful artifact acceptance on devices. The `license_reviewed` flag is merely a caller assertion; legal validity and provenance require independent review. A matching SHA-256 against an untrusted manifest is not proof of authenticity. The verified receipt does not keep a file descriptor open or prevent later mutation; actual model loading must copy or lock immutable verified bytes before inference, and repeat verification at load time.

Native acceptance tests use synthetic files only, never real weights. Next step: pin a compatible llama.cpp revision and iOS XCFramework with a reproducible signed build, connect a trusted immutable model store, then verify physical-device memory/performance and review all tool proposals against an independent approval gate.


## Native JSON admission: duplicate member rejection

The verifier first scans the **raw, bounded (maximum 16 KiB), flat six-field JSON object** and decodes each member name as a JSON string. It rejects duplicate members, including escaped equivalent keys (for example `"model_id"` versus `"\\u006dodel_id"`), nested values, extra members, missing fields and malformed syntax, **before** `JSONDecoder` decodes the typed schema. Unlike a dictionary/JSONSerialization key-set check, this preserves the necessary evidence that the source JSON contained six **unique** members. Regression tests cover repeated identical and conflicting values, escaped duplicate names and nested/oversized inputs.

This closes the **known duplicate-key normalization gap** with Python PR #383 for the declared flat schema. The native verifier remains a proof of *matching bytes to a supplied digest*, not a guarantee of manifest provenance, license rights, immutable staging, device RAM limits or safe inference. The parser is intentionally not a general-purpose JSON parser: nested values are invalid for this manifest.

**Acceptance:** run the `VerifiedGGUFArtifactTests` suite on the exact PR head. A successful macOS test is not a physical iPhone inference test.
