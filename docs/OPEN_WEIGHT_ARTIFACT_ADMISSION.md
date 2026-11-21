# Offline open-weight artifact admission — initial safety contract

This is a **host-side prerequisite**, not an inference integration or proof
that Qwen/LFM runs on an iPhone. No weights, network downloads, license grants,
or model execution are included. The verifier accepts only single-file artifacts.

Create a JSON manifest with exactly these six keys:

```json
{
  "model_id": "publisher/model-family",
  "filename": "model-q4.gguf",
  "sha256": "<64 lowercase hex characters from the independently verified upstream artifact>",
  "size_bytes": 123456789,
  "source_revision": "<40 lowercase hex characters from pinned source commit>",
  "license_reviewed": true
}
```

The placeholders in this example are **not** a valid manifest. Do not set
`license_reviewed` without an actual human license and usage-terms review.
Check the upstream quantized artifact's provenance and redistribution terms.

```sh
python3 scripts/verify_open_weight_artifact.py \
  --manifest /path/to/model-manifest.json \
  --model-directory /path/to/model-directory
python3 -m unittest discover -s scripts -p 'test_verify_open_weight_artifact.py'
```

The JSON parser **rejects duplicate object keys** even when repeated values match. A manifest with duplicate member names is not an unambiguous six-field contract; do not rely on parser-specific first-value/last-value behavior.

Refuse invalid identity, unpinned revision, missing license review, nonregular
or symlinked model file, unexpected filename/size, or SHA-256 mismatch.
A passed verifier proves **only** that the local bytes match the supplied
manifest; it does not prove the upstream origin of the supplied hash, license
validity, model trustworthiness, compatibility, device RAM feasibility, or
inference safety. A hostile writer changing the model file during verification
is not covered; production loading must use an immutable staged verified copy.

Next PR: implement a real iOS GGUF runtime behind `LocalModelRuntime` with an
explicit model store, immutable pinned artifact loading, native device smoke
benchmarks and preview-only output sent through the proposal gate. No automatic
model download or user-data access without separate permission.
