# Read-only physical iPhone readiness

`scripts/check-physical-iphone-readiness.py` uses structured CoreDevice JSON to check for a physical iOS iPhone with a paired and connected or available tunnel on the same device. Simulators and other Apple hardware do not count. Its output does not include device
identifiers, hostnames, serial numbers, Apple IDs, contacts, or files.

This is a diagnostic check, not a pairing, signing or deployment workflow.
It never runs `simctl install`, launches apps, modifies iOS settings, or
requests data from a device.

## Run on the authorized Mac

```bash
python3 scripts/check-physical-iphone-readiness.py
python3 scripts/check-physical-iphone-readiness.py --json
python3 -m unittest discover -s tests -p 'test_physical_iphone_readiness.py'
```

Exit code 0 means a paired physical iPhone has an available or connected tunnel: **ready for
a test attempt**, not proof that deployment signing, device trust,
Developer Mode or App Intents will work. Exit code 2 means no qualifying
physical iPhone; exit code 3 means the local diagnostic command or
saved input failed.

For offline, synthetic reproduction without contacting the phone:

```bash
python3 scripts/check-physical-iphone-readiness.py --fixture example.json
```

If the physical phone does not have an available tunnel, first check the USB-C
cable/connection, unlock the phone, respond to any visible **Trust This
Computer** prompt, and examine Xcode's **Window > Devices and
Simulators** panel for an explanatory pairing or Developer Mode message.
These require the owner's participation and must not be bypassed by scripts.
After the owner resolves any device-side prompt, rerun the readiness
check, then separately attempt a **signed** development-device build.

All examples/tests use synthetic identifiers and do not capture raw
`devicectl` output in repo artifacts. CI may run the parser tests on
Linux or macOS without attached iPhone hardware.
