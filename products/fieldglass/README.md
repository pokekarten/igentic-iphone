# Fieldglass

**Integrationsgrenze:** eigenständiges experimentelles Produkt, nicht die iGentic-Agent-Runtime. Der Standardkanal bleibt manuell; Mac- und Simulatorlabore sind getrennte, explizit konfigurierte Testwege. Links mit Suchtext oder Entwürfen sind nicht verschlüsselt und können in Chat-, Prozess- oder Systemverläufen erscheinen. Für diese Übergabe nur synthetische oder ausdrücklich zur Weitergabe freigegebene Inhalte verwenden. Die neue Integration aktiviert keine Geräteverbindung, keinen Capture-Modus und keinen externen Provider. Die iGentic-Kern-App behält ihre iOS-27-Plattformvorgabe; Fieldglass ist ein separates Projekt mit eigener Kompatibilitätsangabe.

Fieldglass ist eine eigenständige iOS-Werkbank mit lokalem MCP-Plugin. Ein Experiment beginnt auf dem iPhone oder im Chat. Die App verarbeitet ausgewählte Bilder, das Plugin bereitet Aufgaben vor und vergleicht zurückgegebene Ergebnisse. Für das Entwicklerlabor bietet der Mac zusätzliche Simulatorwerkzeuge. App, Server und XCTest-Treiber liegen in diesem Verzeichnis. Die gemeinsame technische Basis sind Apple-Frameworks, das MCP-SDK und Zod.

## Erster Versuch

1. Die App öffnen. Das Beispielbild enthält oben **ORBIT** und unten **HAFEN**.
2. ORBIT im oberen Bereich prüfen. Dann „Beispiel wechseln“ und erneut prüfen.
3. Unter „Letzte Ergebnisse“ die zwei Berichte ansehen oder teilen. Im Plugin vergleicht `compare_results` die beiden JSON-Berichte in der angegebenen Reihenfolge. Ein Bericht enthält Laufkennung, Quelle, Geräteklasse, Bereich und OCR-Ausgang. Der Suchtext und das Foto bleiben außerhalb des Berichts.
4. Für ein eigenes Bild „Bild auswählen“ verwenden. Der System-Picker übergibt das ausgewählte Bild. „Werkzeuge öffnen“ bietet Gerätestatus, Textentwurf, Vorlesen und Erinnerungen.

Im Chat kann man mit `prepare_experiment` einen beliebigen Suchtext mit ganzem Bild, oberer oder unterer Hälfte kombinieren. Den erzeugten Link auf dem iPhone öffnen oder in „Auftrag laden“ einfügen. Die App startet die Bildprüfung über „Jetzt prüfen“ oder über die Suchtaste der Bildschirmtastatur. Suchtext und Entwurf stehen im Link im Klartext. Für persönliche Inhalte kann man beides direkt in der App eingeben. Die letzten zwei OCR-Ergebnisse bleiben im Arbeitsspeicher. Geteilte JSON-Berichte sind Angaben des Absenders und enthalten keine Signatur.

Im Textentwurf lassen sich ausgewählte deutsche Audiodateien über Speech transkribieren. Der Auftrag verwendet ausschließlich lokale Spracherkennung. „Text zusammenfassen“ verwendet ab iOS 26 das verfügbare Apple-Systemmodell. Transkript und Zusammenfassung werden zur Übernahme oder zum Teilen angezeigt. Die App erklärt fehlende Geräteunterstützung direkt im Entwurf.

Die App bietet ab iOS 18 die Kurzbefehle-Aktion **Bild für Fieldglass prüfen**. Eingaben sind der Experiment-Link und ein Bild, Ausgabe ist derselbe Bericht. Für Erinnerungen zeigt die App vor dem Schreiben den Titel und verwendet die Standardliste. iOS kann für den Schreibzugriff die Berechtigung für Erinnerungen anfordern. Ein lokaler Marker pro Auftrag sperrt einen zweiten Speicherversuch mit derselben Kennung auch nach einem Neustart.

## Im Chat bedienen

In einem MCP-Apps-fähigen Chat öffnet `get_channels` die interaktive Fieldglass-Oberfläche. Dort einen Suchtext und Bildbereich wählen und **Auftrag erstellen** betätigen. Der Link lässt sich in der iPhone-App unter „Auftrag laden“ einfügen. Bei eingerichtetem Simulator- oder Gerätekanal ist auch „Auftrag übergeben“ verfügbar. Zwei aus der App geteilte JSON-Berichte lassen sich in derselben Oberfläche vergleichen. Die Oberfläche lädt ihre Schrift, Skripte und Styles lokal. Im Browser-Abnahmetest spricht sie über die offizielle MCP-Apps-Bridge mit dem echten Fieldglass-Server. [OpenAI-Dokumentation zur Chat-Oberfläche](https://developers.openai.com/plugins/build/chatgpt-ui#embed-the-component-in-the-server-response)

## Installation

Vorausgesetzt werden Node 22+, Xcode mit passender iOS-Laufzeit und XcodeGen. Vom Verzeichnis dieser README aus:

```sh
npm ci --prefix plugin --ignore-scripts
npm test --prefix plugin
codex plugin marketplace add .
codex plugin add fieldglass@fieldglass-local
xcodegen generate
open Fieldglass.xcodeproj
```

In Xcode das Scheme Fieldglass auswählen und auf einem Simulator starten. Die Hardware-Installation braucht eine eigene gültige Signierung für den Bundle Identifier. Der Code lässt sich mit `products/fieldglass` als eigenständigem Projektstamm verwenden. Zur direkten Anbindung an andere lokale MCP-Clients genügt `node /absoluter/pfad/plugin/src/server.mjs`. Für ChatGPT Web ist zusätzlich eine vom Konto autorisierte Verbindung zum Server erforderlich.

Für die Weitergabe aus einem Git-Checkout erzeugt `scripts/package-source.sh` ein ZIP der eingecheckten Produktquellen und eine SHA-256-Prüfsumme unter `dist/`. Das entpackte Verzeichnis enthält App, Plugin, Tests und Marketplace-Manifest. Dort gelten die gleichen Installationsschritte.

## Ohne WLAN

Der Mac kann einen Auftrag per USB-Datenkabel an die installierte App übergeben, sobald Apple das entsperrte, gekoppelte iPhone erreicht. Prüfe dafür im Gerätekanal `device_status`. Der manuelle Import eines bereits vorhandenen Links und Vision-OCR laufen in der installierten App auch offline. Ein Link kann über einen vom Nutzer gewählten Kanal zum Telefon gelangen. Eine Fernsitzung über Mobilfunk würde einen eigenen, authentifizierten Internetkanal erfordern und ist noch offen.

## Kanäle und Werkzeuge

| Kanal | Einrichtung | Werkzeuge |
| --- | --- | --- |
| Manuelle Übergabe | Standard, auch ohne Xcode am MCP-Host | get_channels (interaktive Oberfläche), prepare_experiment, prepare_workspace, read_result, compare_results |
| Mac → Simulator / iPhone | Im MCP-Serverprozess FIELDGLASS_CHANNEL auf simulator oder device setzen und FIELDGLASS_TARGET auf die lokale Geräte-ID. Die App muss installiert sein. | deliver_experiment und deliver_workspace öffnen den Link. `submitted` bedeutet, dass Apples Werkzeug die Öffnung angenommen hat; `delivery-unconfirmed` bedeutet, dass der Aufruf kein bestätigtes Ergebnis lieferte und der Gerätezustand geprüft werden muss. |
| Physische Verbindung | Konfiguriertes iPhone am Mac. | device_status prüft, ob Apple das ausgewählte physische iPhone als verbunden meldet. |
| Simulatorlabor | Simulatorziel wie oben. | simulator_status, simulator_app zum Starten und Beenden von Fieldglass |
| Lokale Medien | Zusätzlich FIELDGLASS_CAPTURE=local. | simulator_screenshot, simulator_record_clip (2–10 Sekunden). Die gesamte Simulatoranzeige wird aufgenommen. Der Server liefert Pfad und Größe. Dateien liegen in ~/Library/Application Support/Fieldglass/Captures und bleiben bis zur lokalen Löschung erhalten. |
| Eigener XCTest-Treiber | Zusätzlich FIELDGLASS_XCTESTRUN auf die absolute lokale, vertrauenswürdige .xctestrun-Datei des Build-for-testing setzen. Optional FIELDGLASS_LAB_BUNDLE auf die Bundle-ID einer installierten Test-App setzen. | simulator_interact und simulator_workflow für Inspektion, Tap, Doppeltap, Halten, Wischen, Ziehen, Texteingabe und Warten auf ein Element. |

Beispiel für `simulator_workflow`:

```json
{"commands":[{"action":"inspect"},{"action":"tap","target":{"identifier":"run"}},{"action":"wait-for","identifier":"reading-ready"}]}
```

Zusammengehörige Schritte in einen Workflow legen. Das Öffnen einer XCTest-Sitzung aktiviert die konfigurierte App und kann ihren Zustand verändern. Ein Workflow führt höchstens acht Schritte aus und stoppt bei fehlendem Ziel. Die Inspektion gibt Accessibility-IDs zurück. Test-Apps sollten darin öffentliche, stabile Namen verwenden. Koordinaten liegen zwischen 0 und 1 relativ zum App-Fenster. Xcode-Startzeiten variieren, für Labortests sollte der MCP-Client ein Zeitlimit von mindestens 135 Sekunden unterstützen. Bei unklarem Ausgang zuerst den Zustand prüfen.

## Reproduzieren

```sh
xcrun simctl list devices available
scripts/acceptance.sh SIMULATOR_UUID
```

Der Test erstellt per SDK-Client einen Auftrag, öffnet ihn im Simulator, prüft zwei Bilder mit Apple Vision, exportiert die realen UI-Testberichte und vergleicht sie per MCP. Er prüft außerdem die Bereichsauswahl, den Gerätestatus, einen Entwurf und den Abbruch einer Erinnerung. FIELDGLASS_TEST_CAPTURE=1 ergänzt beim letzten Schritt einen lokalen Screenshot und Clip. Den Build-Ordner steuert FIELDGLASS_DERIVED_DATA.

Für den eigenen Treiber nach dem Build die erzeugte .xctestrun-Datei unter Build/Products auswählen und den Workflow separat ausführen:

```sh
FIELDGLASS_SMOKE_TARGET=SIMULATOR_UUID FIELDGLASS_XCTESTRUN=/absoluter/pfad/Fieldglass.xctestrun node plugin/scripts/acceptance-client.mjs lab
```

Mit der Option `lab-inputs` anstelle von `lab` prüft derselbe Client Doppeltap, Halten, Ziehen, Wischen, Texteingabe mit Suchtaste und den Abbruch bei einem fehlenden Ziel in der Fieldglass-App.

Produktentscheidungen, Quellen und ausstehende Abnahmen stehen in [PRODUCT.md](PRODUCT.md).

Für einen dauerhaft gewählten lokalen Kanal speichert der Einrichtungsbefehl ausschließlich Geräteauswahl und Laboroptionen unter ~/Library/Application Support/Fieldglass/channel.json (0600). Beispiel im Plugin-Verzeichnis:

```sh
node scripts/configure.mjs --mode simulator --target SIMULATOR_UUID --driver /absoluter/pfad/Fieldglass.xctestrun --capture
node scripts/configure.mjs --mode manual
```

Nach einer Änderung eine neue Plugin-Sitzung öffnen. Explizite Server-Umgebungsvariablen überschreiben die lokale Kanalauswahl. Der manuelle Modus funktioniert ohne Gerätekennung. Die Befehle sind alternative Einstellungen.
