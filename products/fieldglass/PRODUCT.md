# Fieldglass – Produkt und Abnahme

Das Produkt soll einer Person erlauben, eine Frage an ihr Gerät zu stellen, etwas auszuprobieren und selbst zu beurteilen, was sich verändert hat. Ein einfacher Auftrag ist ein frei editierbares Experiment. Wer Tests entwickelt, kann mehrere Schritte zu einem Versuch zusammensetzen. Die ersten beiden Kundengruppen sind Personen mit persönlichen Aufgaben am iPhone und Entwickler mit einem eigenen Testgerät.

## Von der Aufgabe zur Implementierung

| Bedarf | Eigene Implementierung | Erfolg aus Sicht des Nutzers |
| --- | --- | --- |
| Bild oder Screenshot prüfen | Native Bildauswahl, orientierungsrichtige Vorschau für Vision, Bereichsauswahl, deutscher und englischer OCR-Vergleich | Ein anderer Bildbereich oder ein anderes Bild liefert einen nachvollziehbar anderen Befund. |
| Vom Chat aufs Gerät wechseln | Versionierte Links, manueller Import, optionale Übergabe über CoreDevice oder CoreSimulator | Der Auftrag erscheint mit denselben Parametern im eigenen iPhone-Arbeitsbereich. |
| Text entwerfen, anhören, erinnern | Native Textbearbeitung, Share Sheet, AVSpeechSynthesizer, EventKit, Bestätigung und lokaler Marker vor der Speicherung | Vor dem Ausführen kann der Nutzer Inhalt korrigieren, abbrechen oder teilen. |
| Sprache und lokales Modell | AVSpeechSynthesizer für Ausgabe, Speech für eine ausgewählte deutsche Audiodatei, Foundation Models für Zusammenfassungen | Nutzer können ein Ergebnis erst lesen, dann übernehmen oder teilen. Fehlende Modelle werden angezeigt. |
| Aus einem Kurzbefehl arbeiten | App Intent mit Bild und Experiment-Link | Ein Workflow kann denselben Ergebnisbericht erhalten, ohne eine Chat-Sitzung offen zu halten. |
| Frei im Labor navigieren | Eigener XCTest-Runner, typisierte Eingaben, Sequenzen, explizites Zielgerät und Ziel-App | Der Nutzer kann die Elementkennungen beobachten, ein Ziel bedienen und den resultierenden Zustand prüfen. |
| Einen Versuch festhalten | Bildschirmfoto und begrenzte Videoaufnahme über Apples Simulator-I/O | Die Dateien bleiben lokal und können gezielt betrachtet oder geteilt werden. |
| Den Ausgang vergleichen | Gleiche Auftragskennung, zwei verschiedene Messkennungen, gleicher Bildbereich, Geräteklasse pro Ergebnis | Chat und App unterscheiden Treffer, ausbleibenden Treffer, Werkzeugfehler und unbestätigte Übergabe. |

## Welche Versuche die Auswahl tragen

- **Auf realem iPhone früher ausprobiert:** MobileCLI/Mobile MCP über USB, einschließlich UI-Beobachtung und Navigation. WDA/PhoneUse lief in einem früheren Setup. iCTRL lieferte Geräteinformationen und Konfiguration. Das sind verschiedene Nachweise. MobileCLI wird separat lizenziert. Fieldglass verwendet für seine eigene Zustellung und Laborbedienung Apple-Werkzeuge. [Physischer Versuchsbericht](https://github.com/pokekarten/igentic-iphone/pull/392), [Research-Atlas](https://github.com/pokekarten/igentic-iphone/blob/3e6f2c2/docs/research/IPHONE_AGENT_PROJECT_ATLAS.md)
- **Native Bildauswertung:** Der vorhandene Mac-Vision-Prototyp zeigte eine geeignete Apple-Schnittstelle. Fieldglass implementiert Bildquelle, Zuschnitt und Ergebnisaustausch selbst auf iOS. [Neo-Research](https://github.com/pokekarten/Mac-book-neo/blob/b601e61d0b5370d1408da54387257270f9c759ba/scripts/apple_vision_ocr.swift), [Apple Vision](https://developer.apple.com/documentation/vision/recognizing-text-in-images)
- **Architekturvergleiche:** agent-device für aktuelle Elemente und Ergebnisprüfung, Appium für Aktionsbefunde, Pinky für menschliche Übernahme. Die eigenen Adapter verwenden Swift/XCTest und einen lokalen Node-Prozess. [agent-device](https://github.com/callstack/agent-device), [Appium MCP](https://github.com/appium/appium-mcp), [Pinky](https://github.com/DIYgod/pinky)
- **Weitere Vergleichskandidaten:** LiveKit und Twilio für eine widerrufbare Liveansicht, FluidAudio und whisper.cpp für deutsche Spracheingabe, Resident und loopl für lokale Modellschleifen, iCTRL und cell-use für abgekoppelten Betrieb. Eine Übernahme ihrer Laufzeiten ist bislang offen. [Quelleninventar und Auswahl](https://github.com/pokekarten/igentic-iphone/blob/9b39a24/docs/reports/iphone-product-landscape.md)

## Abnahme vom 22. November 2026

| Einstieg | Beobachtung |
| --- | --- |
| Interaktive Chat-Oberfläche | Ein lokaler Chromium-Host öffnete die vom MCP-Server gelieferte Karte. Über die offiziellen Bridge-Aufrufe erstellte sie einen Auftrag mit Sonderzeichen, übergab ihn an den Simulator und verglich zwei synthetische Berichte. Ein ungültiger Bericht lieferte eine sichtbare Fehlermeldung. |
| MCP und native Oberfläche auf einem iPhone-Air-Simulator, iOS 27.2 | Der MCP-Client bereitete den ORBIT-Auftrag vor. Vision meldete für das erste Beispielbild einen Treffer, nach dem Bildwechsel keinen Treffer. Der MCP-Client las beide aus der App exportierten Berichte und bestätigte den Wechsel. |
| Drei UI-Tests und drei native Modultests | Bereichswechsel, Gerätestatus, Textentwurf, Abbruch vor dem Speichern einer Erinnerung, ungültige Links und die dauerhafte Reservierung eines Erinnerungsauftrags bestanden. Die native Kurzbefehle-Aktion lieferte für das Beispielbild einen gültigen Bericht. Der Aufruf erfolgte im Testprozess. |
| Eigener Labortreiber und Aufzeichnung | Der Treiber beobachtete die Oberfläche, betätigte „Jetzt prüfen“ und fand die Ergebnisanzeige in derselben Sitzung. Der Medienadapter speicherte ein Bildschirmfoto und einen zweisekündigen Clip lokal. |
| Build und Hardware | Der Build für das generische iOS-Gerät gelang ohne Signierung. CoreDevice führte das gekoppelte physische iPhone Air mit Verbindungsstatus `unavailable`. Signierte Installation, Hardware-Spracherkennung, hörbare Ausgabe, Modellantwort, Kurzbefehle-App und ChatGPT-Web-Aufruf bleiben offen. |

## Vom getesteten Kern zur Ausgabe für andere Nutzer

1. **Lokale private Ausgabe.** Ein Paket vom frischen Checkout bauen. OCR, Übergabe, Vergleich, lokale Werkzeuge und Laborsteuerung durch ihre regulären Einstiegspunkte prüfen. Die Ergebnisse nach Simulator, Hardware und Chat-Host benennen.
2. **Physische Abnahme.** Fieldglass signieren, auf einem verfügbaren Test-iPhone installieren, eine reale Beispielaufnahme und die Kurzbefehle-Aktion prüfen. Kabelzug vor und nach Zustellung, Gerätesperre, Widerruf und Neustart testen. Eine Test-Erinnerung nur für den konkret vereinbarten Titel und die vereinbarte Liste speichern.
3. **ChatGPT und zweites Gerät.** Privaten MCP-Kanal mit konkretem Konto verbinden. Falsches Ziel, getrennte Nutzer, abgelaufene Anmeldung und Widerruf testen. Erster Abnahmesatz: „Prüfe ORBIT im oberen Bildbereich und vergleiche zwei Messungen.“
4. **Physische Liveansicht und Spracheingabe.** Zuerst eine lokal sichtbare Freigabe mit sofortigem Stop auf dem Gerät bauen. Startzeit, Ende nach Widerruf, Bildalter, CPU, Temperatur und Akku messen. Spracheingabe anhand eines festen deutschen Korpus mit Unterbrechungen und Hintergrundgeräuschen vergleichen.
5. **Geräteverwaltung und Veröffentlichung.** Installation, Update, Wiederherstellung, App-Verzeichnis, Crashberichte und optionaler Gerätepool gehören in eine eigene Admin-Oberfläche. Für signierte Binärdateien, Modellgewichte, Zugriff auf Logs, Datenaufbewahrung und Store-Verteilung die jeweils eingesetzte Variante freigeben. WLAN, Mobilfunk, Inferenz ohne Mac und Multiuserbetrieb erhalten eigene physische Abnahmen.

Einige Vorbilder decken Android-Emulator-Funktionen, externe Cloud-Gerätepools oder fremde Desktop-Apps ab. Diese Fähigkeiten bleiben als eigene Erweiterungsziele im Inventar. Einrichtung und tatsächliche Verfügbarkeit werden getrennt angezeigt. Für das lokale Produkt sind die hier implementierten Adapter ohne MobileCLI, Appium, WDA und iGentic installierbar.
