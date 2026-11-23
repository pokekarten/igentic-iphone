# Offline German dictation v0 — iGentic iOS 27

**Goal:** Close the native speech-input gap identified by the 107-upstream research audit, with **no model vendor, ChatGPT API, Mac or internet**.

## Implementation boundary

- `Offline-Werkzeuge → Deutsch lokal diktieren` is an opt-in SwiftUI screen.
- `SFSpeechRecognizer(locale: de-DE)` must report both `supportsOnDeviceRecognition` and `isAvailable` *before* requesting permissions and again before recording. Absence of local German support fails closed.
- `SFSpeechAudioBufferRecognitionRequest.requiresOnDeviceRecognition = true`, with **no** network recognizer/provider fallback.
- Microphone and speech-recognition authorization are requested only after an explicit button tap. Denial never starts capture.
- `AVAudioEngine` streams audio in-memory into Apple's local recognizer; **no audio file, server or device listener** is created.
- The user can stop immediately; recording auto-stops after 30 seconds, on screen exit, on entering background, or when a running capture becomes inactive (e.g. screen lock or Control Center). A permission sheet can temporarily make the app inactive without cancelling a pending authorization flow.
- `stop()` is intentionally a no-op when neither capture nor permission request was started. In particular, viewing and dismissing the page without recording must not deactivate another use of the process-wide audio session. Only a session activated by this dictation controller is deactivated.
- Successful category change records the previous app-global audio category, mode and options and restores them on cleanup **only if** the dictation-specific `.record/.measurement` configuration is still current. This prevents later text-to-speech from inheriting a recording-only audio category, without overwriting a newer component's configuration. Audio-session ownership and live TTS playback still require physical acceptance.
- Captured text stays in transient view state, capped at 3,000 characters, and reaches the iOS clipboard only via a separate user tap.
- Session UUID invalidation rejects late transcript callbacks and async permissions completed after cancellation. `OfflineDictationGate` deterministically validates all five prerequisites.
- Both iOS Debug and Release targets declare `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription`; no background recording entitlement.
- The optional MCP `dictate-text` handoff returns **instructions only**, never an executed-action or microphone/device attestation. No transcript travels through it.

## Not yet implemented or proven

This is **single-turn German speech-to-text**, not a multi-turn voice agent: no streaming VAD/diarization, wake word, barge-in, voice interruption of model replies or persistent transcript context. Source compilation is not proof of actual recognition on the owner's physical iPhone.

Before merge or claiming physical readiness, separately test on a **signed** owned iPhone:
1. Permissions only after an explicit tap, and denial/unavailable locale remains offline and fails closed.
2. Microphone capture and on-device recognition with Wi-Fi and mobile data disabled, when the required language assets exist.
3. Stop, app exit, timeout, interrupted permission prompt and rapid restart do not retain audio or revive a session.
4. No transcript is automatically copied, persisted, uploaded to ChatGPT, shared with Shortcuts or exposed to plugins.
5. Record independent physical acceptance rather than upgrading a simulator result.

Apple references: [local-recognizer support](https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportsondevicerecognition), [request must stay on-device](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition), [microphone authorization](https://developer.apple.com/documentation/avfaudio/avaudioapplication/requestrecordpermission%28completionhandler%3A%29).


## Hintergrundwechsel – Datenschutzgrenze

Auch wenn die Diktieransicht beim App-Wechsel im Navigationsstapel bleibt,
stoppt der iOS-Scene-Observer die gestartete oder auf Berechtigungen wartende
Aufnahme beim Übergang zu background, entwertet die Sessionkennung und
verwirft verspätete Recognition-Callbacks. Der Zwischenzustand inactive
(z. B. systemeigene Berechtigungsabfrage) stoppt absichtlich nicht, damit
das erstmalige Einholen der Einwilligung nicht allein durch die Apple-UI
abgebrochen wird. Die App startet bei der Rückkehr nie automatisch neu.
Ein sichtbarer Hinweis erklärt das Ende der Aufnahme. Eine echte
Hintergrund-Unterbrechung muss nach Installation auf einem signierten iPhone
noch separat geprüft werden; ein Simulator-Build beweist keine Laufzeitwirkung.
