# iGentic: Konsolidierung der 56 offenen PRs — 23.11.2026

> **Review-Stand:** Alle zum Audit-Zeitpunkt offenen 56 Draft-PRs wurden anhand von Base/Head, Dateilisten (vollständig, 677 PR-Dateieinträge mit Wiederholungen), Beschreibungen, gemeinsamer Commit-Ancestry und CI erfasst. Kritische Sicherheitskonflikte wurden zusätzlich anhand realer Code-Diffs verglichen. Diese Triage ersetzt **keine** unabhängige zeilenweise Sicherheitsfreigabe aller PRs.

## Ziel: saubere `main` statt 56 konkurrierender Drafts

- `main` hat aktuell `0bb24b7` als Ausgangsstand; **keine** automatische Übernahme ohne unabhängige Review-Freigabe.
- 56 Drafts, 10 unmittelbar auf `main`, 4 alte Konflikt-PRs: #409, #420, #421, #425. Ein Integrations-PR #436 enthält bereits wesentliche Agent-Loop-Ketten und erhält gezielte Safety-Nachträge.
- **Begriffe trennen:** Signierter Task ≠ echte Besitzerfreigabe ≠ auf dem iPhone ausgeführte Aktion ≠ Geräteattestation. Das `actionExecuted`-Flag darf nicht aus Linköffnung, Prozessstart, einem HMAC-Relay-Beleg oder einer lokalen Vorschau abgeleitet werden.
- **Kanonischer Kern:** iOS27-Basis → Native CoreDevice/WLAN → Agent Home / Shortcuts → read-only signed owner review → authentifizierter MCP-Task-/Replay-/Delivery-Loop. Site und Mobilfunk bleiben getrennte optionale Adapter, nicht Autoritätsquelle.

## Aufgedeckte Widersprüche und Entscheidungen

1. **#425 vs. #428 / Core Journal:** #425 führt beim Journal-Lesezugriff einen Pfad-Metadatencheck und `Data(contentsOf:)` statt eines gepinnten `open(O_NOFOLLOW)` + `fstat` + begrenztem FD-Read ein. Das ist eine unnötige TOCTOU-/Hardlink-Schwächung. Den nicht unsicheren Timeout-Teil prüfen; **#425 nicht direkt mergen**. #436 behält den gesicherten Dateideskriptor-Pfad.
2. **#417 vs. #420 Delivery Marker:** Zwei verschiedene persistente Schlüsselbindungsdateien (`.key-binding` und `.delivery-key-seal`) sind ohne Migration inkompatibel. #420 als kanonisch behalten, die zusätzlichen Hardlink- und unbekannte-Dateien-Abwehrtests aus #417 in denselben Vertrag einarbeiten. Keine stille Schlüsselrotation oder automatische Wiederholung nach unklarer Zustellung.
3. **#394 vs. #395:** Alternative komplette Produktbasis. #394 bringt eigenständige Fieldglass-App plus Plugin, #395 zentrale iOS-/Modell-/Acceptance-Tests. Die beiden Heads sind keine Vorfahren voneinander, direkten Baumvergleich mit 136 abweichenden Pfaden durchgeführt. Fieldglass **nicht** verdeckt als parallele Telefon-Steuerungsinstanz in den Kern mergen.
4. **#409 vs. #404/#432:** Alte UI-/Shortcuts-Äste haben Merge-Konflikte; #432 hat den Agent-Home-PR bereits integriert. #436 bewahrt den leicht auffindbaren Statusknopf, die sichere Prompt-Anzeige und den nativen read-only Test, ohne das Status-Panel zu duplizieren.
5. **#410 Plugin/Site vs. #406/#408:** Der echte lokale MCP/WLAN-Handoff und die Site-Discovery sind verschiedene Schichten. Kein aktiver ChatGPT-Account-Remote-Execution-Beleg nur aus dem lokalen SDK-Test. Der neue Site-Operator-Console-Zweig ist noch gesondert zu prüfen/veröffentlichen.
6. **#402/#426/#430 Mobilfunk:** HTTPS-Readiness und Profil-Prüfung sind keine bestätigte 4G/5G-Route. Optionale Mobilfunkfunktion nicht in den kritischen Release-Gate hineininterpretieren.
7. **#427/#433 Speech:** Opt-in 30-Sekunden-Diktat und AVAudioSession-Restore gehören zusammen; nicht einzeln in eine Release-App aufnehmen.
8. **#389 CI:** Aktueller Head entfernt allein `workflow_dispatch` aus Phase-0-Validierung. Die Möglichkeit manueller Testläufe ist nützlich; vor Übernahme die organisatorischen Risiken/Auswirkungen gezielt entscheiden, nicht pauschal einen Workflow verlieren.

## Physische iPhone-Abnahme dieser Prüfrunde

Der Mac ist über CoreDevice `localNetwork` mit einem **physischen iPhone Air/iOS 27.2.1** verbunden. Für den **vorherigen exakt bekannten #436-Source-Head** `292b703` wurde eine passende vorhandene Team-Signatur samt Provisioning-Profil genutzt, die App mit derselben Bundle-ID signiert gebaut und per WLAN ohne USB-C aktualisiert. Danach öffnete iOS `igentic://handoff/v1/diagnostics`, `/discovery`, `/reminder-draft`; jedes Mal erzeugte die App einen frischen eigenen Vorschau-Receipt. Eine ungültige Route erzeugte keinen neuen Receipt. Erster vollständiger lokaler MCP-SDK/Native-Handoff-WLAN-Smoke **PASS**, inklusive drei Routen und ungültiger Route; keine Erinnerung erstellt, keine fremde App ferngesteuert und keine Besitzerfreigabe behauptet. **Kein** Beleg für eine eingehende ChatGPT-Account-Nachricht und kein echter Siri-/Kurzbefehle-Projekt-Loop. Neuere lokale Sicherheitsänderungen sind nicht Teil dieses bereits installierten Binärstands.

## Jeder offene PR – aktuelle Head-Ancestry und inhaltliche Empfehlung

`Ja` bedeutet: **exakter PR-Head ist als Git-Vorfahre in der lokalen Integrationskopie vorhanden**, nicht unabhängig sicherheitsfreigegeben. `Nein*` bedeutet: neuere Commits oder ein separater Zweig sind noch nicht exakt integriert; älterer Funktionscode kann trotzdem enthalten sein.

| PR | Head im Integrationsbaum | Dateien | Entscheidung | Inhaltlicher Grund |
|---|---|---:|---|---|
| [#378](https://github.com/pokekarten/igentic-iphone/pull/378) | Nein* | 4 | separat | ARTEMIS-Pin/Host-Anbindung nur optional; keine Voraussetzung für eigenen Agent-Loop. |
| [#379](https://github.com/pokekarten/igentic-iphone/pull/379) | Nein* | 15 | dokumentation | Ältere Forschungs-/Architekturübersicht aktualisieren, nicht über neuere Abnahmen schreiben. |
| [#380](https://github.com/pokekarten/igentic-iphone/pull/380) | Ja | 6 | kern | Nur statische, datensparsame App-Intent-Demo, keine echte Geräteauskunft. |
| [#381](https://github.com/pokekarten/igentic-iphone/pull/381) | Ja | 3 | kern | Untrusted-Model-Proposals mit Fail-Closed-Policy vor Aktionen. |
| [#382](https://github.com/pokekarten/igentic-iphone/pull/382) | Ja | 3 | kern | Apple Foundation Models nur Vorschau, keine automatische Ausführung. |
| [#383](https://github.com/pokekarten/igentic-iphone/pull/383) | Ja | 3 | optional | Open-Weight-Dateiprüfung; kein Modell- oder Aktionsbeleg. |
| [#384](https://github.com/pokekarten/igentic-iphone/pull/384) | Ja | 6 | test | Lokaler Foundation-Models-Probe, Hardwarefreigabe unabhängig. |
| [#385](https://github.com/pokekarten/igentic-iphone/pull/385) | Ja | 3 | optional | GGUF-SHA und Symlink-Prüfungen; Modellbetrieb separat. |
| [#386](https://github.com/pokekarten/igentic-iphone/pull/386) | Nein* | 6 | prüfen | Neue isolierte iOS-Abnahmen und Testverträge gegen #436 vergleichen. |
| [#387](https://github.com/pokekarten/igentic-iphone/pull/387) | Nein* | 3 | später | Optionaler Qwen-Smoke; Prompt-/Schlüsselgrenzen prüfen, keine Voraussetzung. |
| [#388](https://github.com/pokekarten/igentic-iphone/pull/388) | Nein* | 4 | prüfen | Physische Readiness-Diagnostik gegen reale WLAN-/Signaturbelege und #430 abgleichen. |
| [#389](https://github.com/pokekarten/igentic-iphone/pull/389) | Nein* | 14 | prüfen | Einzig neuer CI-Delta entfernt workflow_dispatch; manuelle CI-Abnahme nicht blind verlieren. |
| [#390](https://github.com/pokekarten/igentic-iphone/pull/390) | Nein* | 18 | später | EventKit-Erinnerungsentwurf ist Schreibpfad: Besitzerfreigabe und reale Device-Tests nötig. |
| [#391](https://github.com/pokekarten/igentic-iphone/pull/391) | Nein* | 4 | später | Mac/Xcode/Open-Weight-Vorprüfung, kein MVP-Blocker. |
| [#392](https://github.com/pokekarten/igentic-iphone/pull/392) | Ja | 6 | kern | Älterer MobileCLI/Hardware-Nachweis: nur historisch, kein heutiger Agent-Loop-Beleg. |
| [#393](https://github.com/pokekarten/igentic-iphone/pull/393) | Ja | 5 | kern | Nur synthetisches MCP-Labor; muss strikt vom physischen Gerät getrennt bleiben. |
| [#394](https://github.com/pokekarten/igentic-iphone/pull/394) | Nein* | 84 | separat | Eigenständige Fieldglass-App/Plugin und alternative iPhone-Connect-Basis; nicht pauschal mit #395 mergen. |
| [#395](https://github.com/pokekarten/igentic-iphone/pull/395) | Nein* | 93 | prüfen | Gemeinsame iOS-27-Basis enthalten, aber spätere sechs Dateipfade/Tests am aktuellen Head nachholen. |
| [#398](https://github.com/pokekarten/igentic-iphone/pull/398) | Ja | 5 | kern | Sanitisierte Verbindungsstatus-Meldungen, keine generische Gerätesteuerung. |
| [#399](https://github.com/pokekarten/igentic-iphone/pull/399) | Nein* | 6 | später | Lesender lokal-AI-Shortcut, nur Bereitschaftsdiagnostik. |
| [#400](https://github.com/pokekarten/igentic-iphone/pull/400) | Ja | 18 | kern | Client-neutraler MCP-iPhone-Verbindungsbericht. |
| [#401](https://github.com/pokekarten/igentic-iphone/pull/401) | Ja | 17 | kern | CoreDevice-Transport; Appstart und Prozess-Beleg auf physischem WLAN geprüft. |
| [#402](https://github.com/pokekarten/igentic-iphone/pull/402) | Nein* | 23 | später | Aktuelle Mobilfunk-Companion-Authentisierung und Retry-Details noch nicht im kombinierten Head. |
| [#403](https://github.com/pokekarten/igentic-iphone/pull/403) | Ja | 13 | kern | Native Offline-Basics mit optionalem Capability-Katalog. |
| [#404](https://github.com/pokekarten/igentic-iphone/pull/404) | Ja | 6 | kern | Agent-Home-Prototyp mit Navigation/regelbasierter Vorschau, nicht allgemeine UI-Kontrolle. |
| [#405](https://github.com/pokekarten/igentic-iphone/pull/405) | Nein* | 2 | dokumentation | 107-Recherchequellen: nur geprüfte Fähigkeiten als Implementierung einstufen. |
| [#406](https://github.com/pokekarten/igentic-iphone/pull/406) | Ja | 41 | kern | Lesender Site/MCP-Handoff, keine Eigentümerfreigabe oder Remote-Aktion. |
| [#407](https://github.com/pokekarten/igentic-iphone/pull/407) | Nein* | 1 | dokumentation | iOS-27-Steuerungsoptionen als Research, nicht als getestete Fähigkeiten. |
| [#408](https://github.com/pokekarten/igentic-iphone/pull/408) | Ja | 5 | kern | MCP-Handoff-Smoke: auf physischem Gerät nach App-Signing nachgeprüft. |
| [#409](https://github.com/pokekarten/igentic-iphone/pull/409) | Ja | 20 | kern | Kurzbefehle/Projektchat manuell; alter PR zeigt Konflikt, #432 löst App-Home-Seite. |
| [#410](https://github.com/pokekarten/igentic-iphone/pull/410) | Nein* | 13 | später | Neuere Site-Discovery/Operator-Konsole noch nicht in privater Site abgenommen. |
| [#411](https://github.com/pokekarten/igentic-iphone/pull/411) | Ja | 6 | kern | Signierte read-only Task-Annahme, keine generischen iPhone-Befehle. |
| [#412](https://github.com/pokekarten/igentic-iphone/pull/412) | Ja | 7 | kern | Dauerhafter SQLite-Replay-Schutz auf einem Host. |
| [#413](https://github.com/pokekarten/igentic-iphone/pull/413) | Ja | 4 | kern | Transportneutraler Task-/Receipt-Lebenszyklus, keine Geräte-Attestation. |
| [#414](https://github.com/pokekarten/igentic-iphone/pull/414) | Ja | 3 | kern | Replay-Zeilenintegrität und Manipulationsabwehr. |
| [#415](https://github.com/pokekarten/igentic-iphone/pull/415) | Ja | 3 | kern | Späte signierte Quittung behandelt outcome-unknown konservativ. |
| [#416](https://github.com/pokekarten/igentic-iphone/pull/416) | Ja | 13 | kern | Neuester Owner-Keychain-Replay-Vault lokal nachgezogen; nur explizites Enrollment. |
| [#417](https://github.com/pokekarten/igentic-iphone/pull/417) | Nein* | 8 | konflikt | Alternatives .key-binding statt #420 .delivery-key-seal: inkompatibel; nur Hardlink-Härtung übertragen. |
| [#419](https://github.com/pokekarten/igentic-iphone/pull/419) | Nein* | 10 | später | Lokaler Besitzer-Workspace/Entwürfe; erst nach Policy- und Datenspeicherprüfung. |
| [#420](https://github.com/pokekarten/igentic-iphone/pull/420) | Ja | 5 | kern | Kanonisches .delivery-key-seal für Zustellmarker, keine stille Key-Rotation. |
| [#421](https://github.com/pokekarten/igentic-iphone/pull/421) | Ja | 4 | kern | Begrenzter lokaler read-only Zwei-Schritt-Test, keine Cloud-Ausführung. |
| [#422](https://github.com/pokekarten/igentic-iphone/pull/422) | Ja | 6 | kern | Persistenter Status-Loop; Linux 0600-Test-Fixture über #435 korrigiert. |
| [#423](https://github.com/pokekarten/igentic-iphone/pull/423) | Ja | 3 | kern | Lokale Read-only-Session-Expiration beim Snapshot. |
| [#424](https://github.com/pokekarten/igentic-iphone/pull/424) | Ja | 3 | kern | Serieller Kurzbefehle-Zugriff über OS-Dateisperre. |
| [#425](https://github.com/pokekarten/igentic-iphone/pull/425) | Nein* | 3 | blockiert | Timeout-Fix enthält Rückfall von O_NOFOLLOW/fstat auf pfadbasiertes Data(contentsOf:); nicht mergen. |
| [#426](https://github.com/pokekarten/igentic-iphone/pull/426) | Nein* | 7 | später | Mobilfunk HTTPS-Readiness: kein echter Mobilfunk-Beleg. |
| [#427](https://github.com/pokekarten/igentic-iphone/pull/427) | Nein* | 12 | später | Lokale deutsche Spracheingabe nur Opt-in; im Core-Zweig bewusst nicht nötig. |
| [#428](https://github.com/pokekarten/igentic-iphone/pull/428) | Ja | 4 | kern | Unklarer Status nach Crash bleibt ungewiss, nicht als sicher abgelaufen umetikettieren. |
| [#429](https://github.com/pokekarten/igentic-iphone/pull/429) | Ja | 74 | kern | Owner-Review + signierte Proposal-Prüfung; ist keine echte Besitzer-Tap-Attestation. |
| [#430](https://github.com/pokekarten/igentic-iphone/pull/430) | Nein* | 6 | später | Signatur/Mobilfunk-Preflight (alt); reales Signieren erfolgte inzwischen extern. |
| [#431](https://github.com/pokekarten/igentic-iphone/pull/431) | Ja | 3 | kern | Veraltete Statusbeobachtungen bei Ablauf ausgeblendet. |
| [#432](https://github.com/pokekarten/igentic-iphone/pull/432) | Ja | 4 | kern | Agent-Home-Integration mit Shortcuts; Konflikt in #436 sauber aufgelöst. |
| [#433](https://github.com/pokekarten/igentic-iphone/pull/433) | Nein* | 4 | später | Offline-Diktat-Audiosession-Härtung nur zusammen mit #427 übernehmen. |
| [#434](https://github.com/pokekarten/igentic-iphone/pull/434) | Ja | 4 | kern | Owner-Review gegen erneute abgelaufene Leseaufrufe geschützt. |
| [#435](https://github.com/pokekarten/igentic-iphone/pull/435) | Ja | 1 | kern | Linux-Testjournale bleiben privat (0600); CI Linux grün. |
| [#436](https://github.com/pokekarten/igentic-iphone/pull/436) | Ja | 30 | kern | Konsolidierter Integrationszweig; noch nicht nach main gemergt. |
## Geordneter Weg nach `main`

1. **Safety-Cut:** #436 als Review-Basis; Keychain-Enrollment nur explizit; kanonischen Zustellmarker gegen Hardlinks und unbekannte Einträge härten; #425-Dateilese-Rückschritt nicht übernehmen. Vollständige JS-/Swift-/iOS-Simulator-Tests und genaue GitHub-Head-CI, danach unabhängige Security Review.
2. **Main-Baseline:** Nach Code-Review einen einzigen `main`-gerichteten Release-/Integrations-PR aus exakten auditierten Commits statt 56 Einzel-Merges herstellen. Root-Pfade mit alten Rückständen (#389/#395) prüfen; unabhängiges Fieldglass/ARTEMIS nicht implizit mitliefern.
3. **Device-Gate:** Aktuelle signierte App nach Änderungen neu installieren, Native App Intents in Siri/Kurzbefehle tatsächlich ausführen und Owner-Tap getrennt bestätigen. Device-Receipt muss an Task-ID, Nonce und Policy gebunden sein. Der lokale Handoff-Vorschau-Receipt attestiert nur Sichtbarkeit, keine Systemaktion.
4. **Site/Relay-Gate:** Plugin-/Site-Werkzeugregistrierung und Auth, lokale Keychain-Owner-/Device-Einrichtung, Schutz gegen Replay, Timeouts, Neustart und unbekannte Zustellung. Erst dann kann ein eingegrenzter read-only Task vom echten ChatGPT-Chat angenommen und zurückgemeldet werden. Keine OpenAI-Modell-API voraussetzen.
5. **Nachgelagerte Optionen:** #390 Owner-genehmigte Erinnerungen, #419 Workspace, #427/#433 Sprache, #399/#387 lokale Modelle, #402/#426/#430 Mobilfunk, #394 Fieldglass. Diese behalten getrennte Review- und Geräteabnahmen.

**Status:** Prüfung und Integrationsarbeiten laufen; `main` ist bewusst **nicht** unkontrolliert verändert worden. Das Release ist erst sauber, wenn derselbe veröffentlichte SHA Code-Review, hosted CI, Signed-Device- und ChatGPT-Site-Checks überstanden hat.
