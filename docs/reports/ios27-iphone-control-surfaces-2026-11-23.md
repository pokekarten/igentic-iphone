# iOS 27: Wege zu echter iPhone-Steuerung aus ChatGPT (Research und Testplan)

Stand: 2026-11-23. **Research, kein Hardware-Abnahmetest.** Dieses Dokument
trennt *offiziell unterstützte Funktionen*, *Entwickler-/Teststeuerung* und
*experimentelle iOS-27-Privatprotokolle*. Das bestehende ChatGPT-MCP-Handoff
in PR #406 ist Navigation, **keine** Fernsteuerung.

## Kernaussage

Ein ChatGPT-MCP-Server liefert Werkzeuge, aber weder iOS-Berechtigungen noch
Bildschirmkontrolle. Für unser Ziel braucht es einen eigenen, autorisierten
iGentic-Control-Treiber und unabhängig davon ChatGPT als optionalen Client.
Der Treiber kann drei getrennte Modi anbieten:

1. **native/official:** App Intents, eigene App, Shortcuts, vom System freigegebene Aktionen.
2. **hosted/physical:** Mac/PC/Linux + gekoppeltes iPhone; Xcode/Device Hub,
   XCUITest/WDA oder iOS-27-CoreDevice-Bildschirm/HID/Accessibility.
3. **on-device/experimental:** iOS-27-Loopback/VPN + gepaarte Entwicklerdienste
   direkt auf dem iPhone, ohne ständig laufenden Mac; nicht produktionsreif
   und teilweise von privater Apple-ABI und Vordergrund-/Hintergrund-Limits abhängig.

## Kontrollmatrix

| Weg | Kann | Braucht | Hauptgrenze | Priorität |
| --- | --- | --- | --- | --- |
| App Intents / App Shortcuts | Eigene definierte Aktionen, strukturierte Parameter, Siri/Shortcuts/Widgets | Signierte iGentic-App, passende Berechtigungen | Kein generisches Tippen in anderen Apps | P0 offiziell |
| Shortcuts-App + persönliche Automationen | Vorab konfigurierte System-/App-Aktionen, Auslöser, Share Sheet, Siri | Lokaler Shortcut, je nach Aktion Bestätigung | Verfügbare Aktionen und iOS-Ausführungsregeln | P0 offiziell |
| `shortcuts://run-shortcut?name=...` | Vom Nutzer geöffneten benannten Shortcut anfordern | Vorab erstellter Shortcut, lokaler Start | URL weder geheime Autorisierung noch allgemeiner Remote-Trigger | P1 manuell |
| Voice Control | Sichtbare UI-Elemente per Sprache, Nummern, eigene Gesten/Befehle | Aktivierte Bedienungshilfe, Spracheingabe | Nicht als allgemeine Remote-App-API angeboten | P2 Nutzerassistenz |
| Externe Bluetooth-/USB-HID, Switch Control | Tastatur/Schalter, teilweise Zeiger- und Systemnavigation | Gekoppeltes HID-Gerät/Host, Einstellungen | Rückmeldung/Screenshot separat nötig; keine reine App-Permission | P2 Alternative |
| XCUITest / WebDriverAgent | UI-Baum, Screenshot, Tap, Swipe, Text | Signierter Runner, Developer Mode, Testfreigabe, Host/Verbindung | Testinfrastruktur, Laufzeit/Runner kann scheitern | P0 echter UI-Test |
| Xcode 27 Device Hub / devicectl | iPhone anzeigen, App starten, Gerät diagnostizieren, UI prüfen | Xcode 27, gepaartes iPhone, aktiver Tunnel | Host-gebunden, nicht ChatGPT-native Fernsteuerung | P0 hardwaregate |
| iOS 27 CoreDevice HID + Display/AX | Cross-App-Taps, Wischen, Tasten, Screenstream, Accessibility | iOS 27, passende DDI und Kopplung/Tunnel; oft Host | Private und instabile ABI; keine iOS-App-Store-Garantie | **P0 Forschung** |
| iOS 27 On-device Loopback / LocalDevVPN | Experimentelle lokale Screen/AX/Touch-Kette ohne dauerhaften Mac | Eigenes signiertes App-/VPN-Setup, Pairing, DDI | Private APIs, begrenzte Hintergrundlaufzeit, App-Store-Risiko | **P1 Forschung** |
| AirPlay-Ansicht + Bluetooth-HID | Bildschirm ansehen und Touch-/Tastatur-Ersatz über separates HID | Empfangender Host und HID-Kopplung | Zwei getrennte Wege, zeit-/zustandsabhängig | P2 Fallback |
| iPhone Mirroring auf Mac | Vision/Tap/Type über Spiegel-Fenster | Gleicher Apple Account und Apple Mirroring | In der EU aktuell offiziell nicht verfügbar | Nicht primär in DE |

## Verifizierte upstreams und was wir daraus lernen

1. **ipb** — https://github.com/ipbtools/ipb — iOS 27, CoreDevice HID,
   Screensharing, native AX und v0.6 MCP, Host macOS. Das Repo kennzeichnet
   die ABI als privat und die neueste breite Hardware-Abnahme als offen.
   *Lernen:* getrennte Bestätigung `sent`/`unknown`, AX vor Koordinaten,
   Support-Inventory und sauberes Stoppen.
2. **iphone-cli** — https://github.com/HyunSeob/iphone-cli — macOS/Windows
   mit iOS 27, AX-Baum, Elementaktion, verifizierte Ergebnisse, USB/WLAN,
   ohne WDA. Einzelgeräte-/Buildnachweise, kein Ersatz für unsere Abnahme.
   *Lernen:* `doctor` mit klarer Nutzeraktion pro fehlender Voraussetzung,
   `done/not_sent/unknown` und keine Wiederholung bei `unknown`. MIT.
3. **mgcrea/mcp-ios-device** — https://github.com/mgcrea/mcp-ios-device —
   Mac, devicectl plus optional WDA für Touch/UI. Read-only standardmäßig;
   Schreibwerkzeuge nur nach Opt-in. Offene persönliche Apps werden beim
   Einschalten der Schreibfunktion tatsächlich bedienbar. MIT.
4. **Derrors/iphone-control-toolkit** —
   https://github.com/Derrors/iphone-control-toolkit — Linux+USB,
   WebDriverAgent, iOS-27-HID-Fallback, Screenshots und Agent MCP.
   *Lernen:* Diagnose/Verbindungsreparatur, aber ein PC/Host bleibt nötig.
5. **Actell** — https://github.com/ja1chen/actell — iOS-27-App mit eigenem
   Loopback-VPN oder ESP32-NCM, experimentellem CoreDevice-Screenshot/Touch/AX.
   Entwickler selbst nennen es Frühprototyp; Langzeit-Betrieb und allgemeines
   MCP sind nicht gesichert. GPL-3.0; **nicht kopieren**.
6. **Pinky on-device study** —
   https://github.com/DIYgod/pinky/blob/main/docs/notes/standalone-phone.md —
   beschreibt iOS-27-Phone-only-Prototyp, lokale Paarung/DDI und frühe
   Hintergrundversuche. Die Studie nennt laufende App-/VPN-/Store- und
   Zuverlässigkeitsgrenzen; keine belastbare 24/7-Zusage.
7. **device-hub-ios** —
   https://github.com/JaviSoto/device-hub-ios — Port des iOS-27-Device-Hubs
   auf iOS; Steuerung eines *anderen* iPhone/iPad übers LAN. Braucht
   Entwicklerfreigabe, Signierung und Netzwerk; kein Beleg für Self-Control
   auf genau einem Gerät. MIT.
8. **lxe/phoneuse** — https://github.com/lxe/phoneuse —
   separates AirPlay-Bild plus Bluetooth-HID-Eingaben von Linux; Alternative
   ohne iOS-Entwicklerdienste, braucht aber Host und HID-Pairing. MIT.

Andere bekannte Wege: Appium XCUITest/WDA, `mobile-mcp`, `mcp-ios-device`,
Xcode-Device-Hub, Apple Voice Control. Keine dieser Möglichkeiten darf mit
einer automatisch installierten ChatGPT-Plugin-Verbindung verwechselt werden.

## API-Vertrag für eigenen iGentic-Treiber

**Nicht** ein blindes `iphone_tap` mit allmächtigem Token ins öffentliche
ChatGPT-Plugin stellen. Stattdessen:

- `iphone_connection_status`: Host/Tunnel/Device/App/Runner getrennt,
  frische Messung, keine veralteten Verbindungserfolge.
- `iphone_observe_ui`: minimale, vom Gerät verifizierte AX-Zusammenfassung
  oder nach ausdrücklicher Zustimmung ein geschützter Screenshot. Nicht
  automatisch persönliche Inhalte an öffentliche Modelle senden.
- `iphone_prepare_action`: erlaubtes Ziel, UI-Fingerprint, Risiko,
  Gültigkeitsdauer, keine Ausführung.
- `iphone_request_approval`: Auftragsbindung; Entscheidung durch Menschen
  bzw. lokale Richtlinie, niemals Modell-Selbstfreigabe.
- `iphone_execute_once`: nur autorisierter, unveränderter Auftrag;
  (idempotency key), keine automatische Wiederholung bei unbekanntem Ausgang.
- `iphone_verify_result`: frische Nachbeobachtung, `verified`,
  `not_sent`, `unknown_outcome` getrennt.
- `iphone_stop`: Unterbrechen, Lease freigeben, bei unklarem Zustand
  Quarantäne statt unsichtbarer Wiederaufnahme.

Ein späteres Sites-/MCP-Frontend ist nur der Broker. Geheimnisse, Pairing,
Geräteberechtigungen und Freigaben dürfen **nicht** aus einem ChatGPT-Tool
allein entstehen. Eigene Geräteaktion erfordert zulässigen Scope und
verlässliche Bestätigung; Kauf, Senden, Lösch- oder Sicherheitsaktionen
erfordern besonders strenge lokale Freigabe.

## Testreihenfolge, mit echten Abnahmekriterien

**Phase A: sofort, stabilste Hardwarebasis (Mac + vorhandenes iOS 27)**

1. `xcrun devicectl list devices`: aktives gepaartes physisches iPhone
   eindeutig von Simulator/erinnerter Verbindung trennen.
2. Own-App starten; frischen `igentic-plugin-receipt` vergleichen.
   Read-only Status ist noch keine Cross-App-Steuerung.
3. Einen **harmlosen**, benutzerbestätigten AX-/HID-Test auf einer
   vorab gewählten Testansicht durchführen (keine Nachrichten/Käufe).
   Erst UI lesen, Element wählen, *einmal* tippen, UI wieder lesen.
4. Für jeden Versuch USB und WLAN getrennt dokumentieren: Verbindung,
   sichtbarer View, Aktion, Ergebnis; niemals nur eine erfolgreiche
   Kommando-Rückgabe als UI-Erfolg werten.

**Phase B: offizieller iPhone-only-Pfad**

5. App Intent + Shortcut für `open-discovery` auf dem physischen
   iPhone über den System-Dispatcher ausführen. Nutzerinteraktion,
   Ablehnung und Permission-Grenzen messen.
6. Voice-Control/Shortcuts als explizit vom Nutzer aktivierte Alternative
   prüfen; keine Sprachinjektion oder unkontrollierte Befehlsausführung.

**Phase C: Mac-freier iOS-27-Forschungspfad**

7. Actell/Pinky nur in isolierter Entwicklungsumgebung erforschen:
   Pairing/DDI, lokale Screen- und AX-Beobachtung, genau eine erlaubte
   Testgeste und Verlustrisiko bei App-Wechsel/gesperrtem Telefon.
8. Neben dem Vordergrund auch Unterbrechungen/Neustarts und echtes WLAN-Aus
   bzw. Mobilfunk separat messen. Ein erfolgreicher Vordergrund-Tap
   ist **kein** Beweis für dauerhaftes Mobilfunk-Remote-Control.
9. Lizenz- und App-Store-Freigabefähigkeit unabhängig prüfen. Private
   Systemdienste bleiben experimentell, nicht unbemerkt in den Default.

## Entscheidung für iGentic

**Zuerst eigene First-Party-CoreDevice-Grenze aus PR #401 und den auf iOS 27
wirklich verfügbaren UI-/HID-Pfad prüfen.** Als unabhängige
Vergleichsimplementierungen dienen `iphone-cli`, `ipb` und WDA-MCP
— nicht als Pflichtabhängigkeiten. Parallel weiterhin offizielle App
Intents/Shortcuts für dauerhaft nutzbare App-Funktionen ausbauen.

**Kein dauerhaft laufender Mac** bleibt unser Ziel, nicht der heutige
Hardware-Beweis. Die Mac-freie iOS-27-Schiene gehört in einen separaten,
opt-in Research-Branch, bevor private CoreDevice-Schnittstellen überhaupt
als Produktionslösung erwogen werden.

## Primärquellen (Stand 2026-11-23)

- https://developer.apple.com/documentation/appintents
- https://developer.apple.com/documentation/updates/appintents
- https://developer.apple.com/documentation/xcode/device-hub/
- https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes
- https://support.apple.com/en-ie/guide/shortcuts/apd624386f42/10.0/ios/27
- https://support.apple.com/en-om/guide/shortcuts/apdfbdbd7123/10.0/ios/27
- https://support.apple.com/guide/iphone/use-voice-control-iph2c21a3c88/27/ios/27
- https://support.apple.com/en-gb/118275
- https://support.apple.com/en-euro/120421
- https://appium.github.io/appium-xcuitest-driver/latest/guides/troubleshooting/
