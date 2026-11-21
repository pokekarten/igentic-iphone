# Native on-device GGUF integrity admission (stacked on artifact verifier PR)

`VerifiedGGUFArtifact` verifies a trusted six-field manifest, checks a regular local GGUF file using an `O_NOFOLLOW` file descriptor, and streams its SHA-256 hash in bounded 1 MiB chunks. It does **not** call inference, parse GGUF internally, download anything, approve an action or grant model permissions. It complements the independent Python preflight in PR #383. Native model IDs now enforce the same canonical two-segment `publisher/model-name` form as that verifier; traversal-like or nested identities are rejected before accessing a file.

This Swift component is iOS/macOS capable with CryptoKit. On unsupported platforms it rejects verification with `digestUnavailable`; Linux CI may compile the contract but cannot claim a successful artifact acceptance on devices. The `license_reviewed` flag is merely a caller assertion; legal validity and provenance require independent review. A matching SHA-256 against an untrusted manifest is not proof of authenticity. The verified receipt does not keep a file descriptor open or prevent later mutation; actual model loading must copy or lock immutable verified bytes before inference, and repeat verification at load time.

Native acceptance tests use synthetic files only, never real weights. Next step: pin a compatible llama.cpp revision and iOS XCFramework with a reproducible signed build, connect a trusted immutable model store, then verify physical-device memory/performance and review all tool proposals against an independent approval gate.


## Open native JSON admission parity gap

**Must resolve before merge or production use:** the Swift verifier currently validates the six keys of the *decoded JSON object* using `JSONSerialization` and `JSONDecoder`. Unlike Python verifier PR #383, this does **not** establish that the raw input contained unique keys. Duplicate JSON object members may be normalized/overwritten before the strict key-set check. The native format therefore **does not yet match** the Python verifier's duplicate-key rejection. Add an unambiguous top-level member parser (including escaped member names) and a regression asserting that even identical duplicate keys are rejected before upgrading this native verifier to full parity. A SHA-256 match by itself also cannot authenticate untrusted manifest provenance.
