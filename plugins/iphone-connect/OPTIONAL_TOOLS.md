# Optional tools, first-party minimum, and honest fallbacks

This is a capability registry, **not** a claim that third-party tools have
been installed, copied or successfully connected. iGentic does not silently
install other projects or execute a different backend when the selected path
fails. Tools can be enabled separately; none is a dependency of the native
minimum. A fallback is explicitly selected and its verification is separate.

## What works without a Mac, cloud provider or ChatGPT

With an **updated, installed and signed iGentic iPhone app**, the user may
manually open `Offline-Werkzeuge` for these first-party iOS functions:

| First-party capability | Native implementation | External counterpart (optional) |
| --- | --- | --- |
| Diagnostics | Existing iGentic Diagnostics view | ChatGPT / generic MCP |
| Discovery | Bundled Explore content | Web-based agent research |
| Text draft and explicit copy | Local SwiftUI editor + iOS clipboard | Fieldglass text workspace |
| Read aloud | Apple's `AVSpeechSynthesizer`, user-initiated | Cloud text-to-speech |
| OCR from an explicitly chosen photo | PhotosPicker + native Vision; no photo-library blanket permission | Fieldglass OCR / external OCR |
| Reminder draft, review, approval | Existing EventKit-backed reminder flow | Shortcut, cloud reminder service |

Text and OCR results are temporary view state, not sent to a remote agent,
written to a file or logged. Clipboard export is a separate user button;
anything copied is subject to normal iOS clipboard semantics. Speech is
stopped on leaving the screen. Only a manually selected image is loaded;
image inputs over 12 MB are rejected and extracted text is capped to
3,000 characters. Native reminders require user permission and separate
explicit approval. They may sync according to the chosen Apple Reminders
storage destination; **do not** describe that write as an offline-only write
unless the destination is local.

These native functions do not grant access to other apps' private screens,
allow unrestricted taps or provide an iOS shell. They are not remotely
callable merely because the plugin prepared a task.

## Plugin core when the iPhone is unreachable

Both the desktop stdio server and the isolated loopback portable MCP preview
expose two shared, zero-provider tools:

- `iphone_tool_catalog`: read-only, constant list of native implementations
  and optional providers. Provider installation and connection states are
  **not checked**. No background probing, token collection or process launch.
- `iphone_prepare_local_task`: prepares a *manual, non-executing* task
  for diagnostics, discovery, text draft, speech, one-picture OCR or reminder.
  It never claims that an iPhone was connected, that a task ran or that an
  app is installed. The optional bounded text is caller-supplied and returned
  only as copyable draft; it is not stored or encoded into a deep link.

They are useful for other clients as well as ChatGPT. The portable preview
still binds only to localhost, contains no physical-driver credentials and
cannot execute iPhone commands. A third-party model or hosted connector is
not necessary for either pure function. The native app is independent of
the MCP client; the plugin is not installed inside the native ChatGPT iOS app
just by building a local Node package.

## Integration coverage and selected fallbacks

| External tool category | Optional integration boundary | First-party minimum if absent |
| --- | --- | --- |
| ChatGPT / Codex / other MCP clients | Client protocol; account connection separate | Native iGentic iOS app |
| Fieldglass | Separate workbench and image experiment protocols | Own manual text editor, speech and Vision OCR |
| MobileCLI | Opt-in legacy physical-device driver | Native CoreDevice for our app only |
| pymobiledevice3 / libimobiledevice | External developer-device utilities, not bundled | Native Apple devicectl / CoreDevice |
| Tailscale or other VPN | Opt-in private IP network, not device control | Native local tasks; independent USB/Wi-Fi route |
| Remote Desktop Commander | Optional Mac operation, not phone UI authority | Native iOS user actions |
| Playwright / XCTest | Optional developer and simulator workflows | Manual native app actions, not equivalent test automation |
| MLX Swift LM / llama.cpp / other open weights | Optional model inference adapters, separate model licensing | Manual local editor and user-reviewed reminder draft |
| Apple Foundation Models | Optional device-dependent proposal generation | Manual reminder form |

**Known non-equivalences:** Manual editing does not replace arbitrary UI
automation. Apple CoreDevice cannot bypass provisioning or control every iOS
app. The built-in editor does not replicate all Fieldglass research/test tools.
The pure offline handoff is an instruction receipt, not an action receipt.
A cellular HTTPS readiness ping is not remote control; no phone session is
ever inferred from a VPN or from the portable MCP preview.

## Acceptance gates

1. Run Mac Node MCP and offline-core tests (strict input and fail-closed).
2. Build the current iOS scheme with Xcode 27.2.
3. Install the signed updated app via owner-controlled provisioning.
4. On the **physical** iPhone, with Mac disconnected and Wi-Fi off if desired,
   manually open Offline-Werkzeuge and test editor, speech and one chosen
   photo; verify no network is required for these tasks.
5. Separately validate user-approved reminder writes, including storage
   destination and duplicate protection.
6. Validate USB-C, Wi-Fi, cellular and ChatGPT connector one at a time.
   Never transfer results or readiness between routes.

See `FIRST_PARTY_COREDEVICE.md`, `CELLULAR_COMPANION.md`,
`PORTABLE_MCP.md` and the independent Fieldglass PR for those separate
integration tracks.
