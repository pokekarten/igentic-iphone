# iGentic Agent Loop – transportneutraler Vertrag v0

**Status: offline testbarer Protokoll-Baukasten. Kein Live-Transport, keine
iPhone-Ausführung, kein neuer Site-Toolaufruf und keine OpenAI API.**
Alle Tests sind mit abgezogenem USB-C und ohne iPhone-WLAN ausführbar.

## Zielbild für alle Richtungen

iGentic ist für Aufgabenstatus, Berechtigungen und Ausführungsbelege zuständig;
der KI-Anbieter bleibt austauschbar. Unterschiedliche Einstiegspunkte nutzen
denselben engen, sicheren Zulässigkeitsvertrag, aber **keine gemeinsamen
automatischen Privilegien**.

| Einstieg | Aufgabe des Bausteins | Nicht automatisch vorhanden |
| --- | --- | --- |
| ChatGPT-Site-Plugin | MCP-Auftrag an getrenntes Owner-Relay | iOS-Rechte, Geräteverbindung |
| Kurzbefehle mit ChatGPT | Apple Modell verwenden → iGentic-Antwort-Intent | MCP-Site-Tools innerhalb des Kurzbefehls |
| Siri | Nutzer → App Shortcut / App Intent | Siri-Kontrolle durch Drittanbieter |
| iGentic Agent Home | Lokale Vorschau, Policy und Einwilligung | Remote-Ausführung |
| Lokales Modell | Foundation Models oder zugelassene Open Weights | Vertrauenswürdige Modell-Befehle |
| Anderer KI-/Manuell-Client | Gleicher signierter Aufgabenvertrag | Eigenständige Freigaberechte |

Verbindungswege sind separat: foreground HTTPS über Mobilfunk, Apple CoreDevice
über USB-C/WLAN mit aktivem Tunnel, und lokale App Intents/Kurzbefehle. Ein
funktionierendes ChatGPT-Plugin beweist keinerlei Erreichbarkeit des Telefons.

## Implementierter offline Protokoll-Baukasten

Die Datei plugins/iphone-connect/src/agent-loop-protocol.mjs enthält eine
Single-Task-Zustandsmaschine ohne Netzwerk, Worker, iOS-Aufrufe, Shell oder
Task-Queue. Sie nutzt einen bereits authentifizierten read-only Owner-Auftrag
und unterstützt ausschließlich die Capability igentic.own_app.status.read.

Der Integrationstest verwendet den versiegelten, persistenten SQLite-Ledger
aus PR #412 und dieselben drei statischen Site-Werkzeuge aus PR #410.

Zustandsfolge:

    empty
      -> awaiting-manual-delivery
      -> delivery-prepared-not-sent
           -> not-sent
           -> outcome-unknown (unklarer Versand / Timeout nach Versuch)
           -> awaiting-key-authenticated-receipt
                -> receipt-key-authenticated

Ein lokal abgebrochener Auftrag ist nur cancelled-local, **nicht** auf einem
iPhone widerrufen. Es gibt keine automatische Wiederholung, insbesondere nicht
nach unklarem Empfang. Ablauf vor einem Versand heißt expired-before-send,
Ablauf nach einem möglichen Versand heißt outcome-unknown.

## Device-Receipt ist mehr als ein HMAC

Es gibt einen vom Owner-Auftrag getrennten HMAC-SHA256-Antwortvertrag mit
exakter Anfragekennung, Capability, Zeitstempel und Nonce. Beim Übergang
\`prepareDelivery\` erzeugt der Protokollzustand einen frischen, zufälligen
\`receiptNonce\`. Eine signierte Rückmeldung wird nur angenommen, wenn der
Nonce genau zur zuvor vorbereiteten Lieferung gehört. Der Nonce erscheint
nicht im öffentlich lesbaren Status-Snapshot und gehört nur in den späteren
separat authentifizierten Geräte-Adapter, nicht in einen Modell-Prompt oder
einen öffentlichen Site-Tool-Aufruf. Dadurch kann ein beliebiger, zwar gültig
signierter, aber nicht zur Lieferung gehörender Beleg nicht akzeptiert werden.
Der Test kann eine synthetische Antwort mit einem lokalen Schlüssel erzeugen.
Erfolgreiche Prüfung
beweist **nur Schlüsselbesitz, keine physische Geräte-Identität und keine
tatsächliche iOS-Aktion**. Die Anzeige bleibt deshalb bewusst:

- actionExecuted = false
- ownerApproved = false
- iPhoneConnected = not-checked
- deviceReceipt = key-authenticated-not-device-attested

Ein späterer Produkt-Relay darf den Geräte-Antwortschlüssel niemals der
ChatGPT-Site, einem Modell-Prompt oder einem unautorisierten Client geben.
Keine Wiederverwendung des bisherigen Mobilfunk-readiness-Schlüssels.
Schlüssel-Enrollment, Keychain-Sicherung, Rotation und Revocation fehlen.

## Nächste technische Gates

1. Die konkurrierenden Replay-Implementierungen aus PR #411 und #412
   konsolidieren. Für einen späteren Server keinen unversiegelten Fallback.
2. Einen eigenen, owner-autorisierten HTTPS-Relay mit fester read-only
   Capability, Identitätsbindung, Mandantentrennung, Audit, Timeouts und
   persistentem Task-Status aufbauen. Kein generischer iPhone-Befehlsserver.
3. Einen freiwillig aktivierten iGentic-Foreground-Poll über Mobilfunk
   implementieren; das bestehende Mobilfunkmodul in PR #402 ist bislang
   ausdrücklich nur ein manueller Bereitschaftstest.
4. Den Device-Receipt aus der tatsächlichen nativen iOS-Lesefunktion
   erzeugen. Unabhängig prüfen: Gerätescope, Apple-Policy und gegebenenfalls
   explizite Nutzerzustimmung. Schlüsselbesitz allein genügt nicht.
5. Beide API-freien ChatGPT-Wege getrennt abnehmen:
   a) Siri/Kurzbefehle → Modell verwenden → iGentic-Intent → lokale Rückgabe;
   b) ChatGPT-Site → Relay → iPhone-Foreground-Poll → geprüfte Rückmeldung.
6. Auf physischer Hardware unabhängig via Mobilfunk, WLAN und USB-C testen:
   Anmeldung, Sperrbildschirm, Fehler, Unterbrechung, Replay, Löschen,
   Timeout, abgebrochene Aufgaben, fehlende Einwilligung und Serverneustart.
7. Erst nach Security-Review, exaktem CI, iOS-Build und verifiziertem
   Gerätetest in eine signierte Release-Basis integrieren.

Die ChatGPT-Site wird **nicht** verändert oder veröffentlicht. Ein späteres
MCP-Werkzeug zum Anlegen von Aufgaben braucht separate Authentisierung,
nicht einfach die bisherigen manuellen Handoff-Links.

## Ohne Gerät testen

    cd plugins/iphone-connect
    npm ci --ignore-scripts --no-audit --no-fund
    node --test test/agent-loop-protocol.test.mjs
    npm test

Getestet werden sechs Einstiege, vier Routen, Replay/TTL, gesperrte
Schreibaktionen, manipulierte Antworten, unbekannte Zustellung, Storno,
signierte Schlüsselbelege und die realen Quellverträge von PR #410/#412.
Das ist **keine** reale ChatGPT-, Siri- oder iPhone-Ausführung.

## Plattformreferenzen

- https://developer.apple.com/documentation/appintents
- https://developer.apple.com/documentation/appintents/verifying-your-app-intents-implementation
- https://support.apple.com/guide/shortcuts/use-apple-intelligence-in-shortcuts-tpg3vrvwmclv/ios
- https://developer.apple.com/videos/play/wwdc2026/310/
- docs/architecture/API_FREE_CHATGPT_SHORTCUTS_LOOP.md auf PR #409
