# iGentic Cellular Companion — own code, opt-in

This is an **additional** route alongside USB-C, Wi-Fi, App Intents/Shortcuts, local on-device models and optional ChatGPT/MCP clients. It does **not** depend on MobileCLI, iph, Tailscale, a running Mac, or any third-party mobile automation runtime. The iPhone can send an outbound HTTPS request to an owner-operated, Internet-reachable server over its cellular data connection.

## Current bounded capability

**Readiness-only, no remote control.** In the native iGentic Diagnostics app, open **Mobilfunk Companion (optional)**, enter your own HTTPS endpoint ending with `/v1/companion/readiness`, enter the 32-byte Base64 pairing secret, and explicitly tap Save. The secret and URL are stored only in the **iOS Keychain**, this-device-only and available while unlocked. No user records, device identifiers or app contents are transmitted. Each readiness check is initiated manually in the foreground, not as a background daemon.

The iOS client uses Apple's URLSession and CryptoKit. It allows cellular data, requires the system's normal TLS server validation, rejects HTTP, URL credentials, redirects, wrong paths and malformed responses, does not set cookies or cache responses. It sends one fixed JSON body:

`{"schema":1,"kind":"readiness"}`

Request headers: `x-igentic-timestamp` (Unix seconds), `x-igentic-nonce` (fresh lowercase UUID), `x-igentic-signature` (HMAC-SHA256 hex over the exact versioned method, path, timestamp, nonce and SHA-256 body digest). No raw secret crosses the network.

The Node HTTPS host, implemented **in this repository**, validates the exact method/body/path/signature and content type, a 60-second timestamp window, and one-time nonce within a bounded in-memory cache. It limits header bytes, request bytes, simultaneous connections and requests per connection. No remote action, arbitrary iOS command, UI tap, shell, persistent user-data write, session approval or third-party tool is included. A valid response explicitly says `deviceControl=not-enabled` and `backgroundExecution=not-guaranteed`. Replay cache is per running process, so it must not be mistaken for persistent protection across server restarts; only a harmless readiness check is implemented.

## Owner-operated server deployment

1. Choose your own HTTPS host with a publicly trusted TLS certificate and a DNS name reachable from the iPhone over 4G/5G. A Mac is **not required if this server is hosted elsewhere**. This repository does **not** provision a public hostname, HTTPS certificate, firewall, port forwarding or hosting automatically.
2. Generate one pairing secret **locally**:
   `node plugins/iphone-connect/scripts/init-cellular.mjs`
   The private 0600 key file is created once under the local user's `~/Library/Application Support/iGentic/iphone-cellular/` folder, not committed or printed.
3. Use the private key in your own iGentic HTTPS server environment, together with the TLS key and certificate:
   - `IGENTIC_CELLULAR_SHARED_KEY_FILE`: path to the locally stored 0600 Base64 key
   - `IGENTIC_CELLULAR_TLS_KEY_FILE`: path to your TLS private key
   - `IGENTIC_CELLULAR_TLS_CERT_FILE`: path to your TLS certificate
   - `IGENTIC_CELLULAR_LISTEN_HOST`: defaults to `127.0.0.1`
   - `IGENTIC_CELLULAR_LISTEN_PORT`: defaults to `37866`
   - `npm run serve:cellular` in `plugins/iphone-connect`
4. For an explicit public interface bind, the host refuses to start unless `IGENTIC_CELLULAR_PUBLIC_BIND_ACK=I_ACCEPT_PUBLIC_HTTPS_EXPOSURE` is set. Prefer a private reverse proxy and access rules. No cleartext HTTP mode or unauthenticated public listener exists.
5. Reveal the key only from an **interactive private terminal** using `node plugins/iphone-connect/scripts/init-cellular.mjs --show-key`. Enter it into the native app's SecureField, then clear it from the field. Don't paste it into chats, GitHub PRs, logs or public screenshots.

The shared secret proves possession of that secret, **not hardware attestation
or the identity of a specific iPhone**. Rotate the secret if it may have been
copied. While no user data, hardware identifier or raw GPS coordinate appears
in the payload, normal network transport exposes connection metadata (such
as an IP address) to the host and any configured reverse proxy. Our gateway
does not deliberately print or persist that address. A hosting provider or
proxy may have its own logs and retention policies.

Both the iOS Keychain credential replacement and the Mac server key
initialization preserve existing credentials if a write fails. The server
requires privately readable (0600) files for the pairing secret and TLS private
key; symlinked pairing-secret paths are rejected. If using a TLS certificate
manager, supply the actual secure private-key file rather than a symlinked
path. Private key files are never bundled or committed.

Pairing remains **manual** in this version; there is no automatic credential enrollment, QR provisioning or hosted relay. Do not start public service without reviewing firewall, TLS certificate and key policies.

## Reality checks

- A unit/loopback HTTPS success is **not proof of physical cellular connectivity**. A simulator request also is not a 4G/5G test.
- To verify 4G/5G on a physical iPhone, install a properly signed app version with this screen, unplug USB-C, turn **Wi-Fi off**, leave mobile data enabled, and tap the signed readiness check. Confirm the server's accepted response. Do not claim route verification when Wi-Fi is still available.
- iOS does **not** allow us to promise an always-running background socket or unrestricted control over system settings and other applications. This first version is foreground-only and requires an explicit tap.
- To disable the route, delete the stored Keychain connection in the app and stop the own HTTPS service. The other iGentic interfaces continue working.
- A successful heartbeat does **not** authorize new commands. Any future action proposal must be separately designed with signed scope, explicit per-action approval, expiry, replay protection and independent device-side receipts.

## Tests

The first-party Node protocol has unit and live **TLS loopback** tests for signature verification, invalid methods/body/path, timestamp expiry, wrong key, nonce replay, public-bind guard and exact fixed response. Swift tests include an exact Node/Swift HMAC test vector. iOS simulator build tests ensure the optional UI compiles. A physical mobile-data test cannot be completed until the newly signed app can be installed and a trusted reachable HTTPS endpoint is configured.
