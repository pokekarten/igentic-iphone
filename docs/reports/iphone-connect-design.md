# iPhone Connect – Produktentwurf

**Historischer Entwurf aus PR #394 (November 2026).** Dieser Bericht dokumentiert frühere Vorschläge und Quellen, nicht den aktuellen Implementierungsstand oder eine Freigabe für den gemeinsamen iPhone-Connect-Plugin. Die ursprünglichen Änderungen am gemeinsamen Plugin bleiben im Commit `e2e26d5` erhalten und sind separat zu bewerten.

## Ein vollständiger erster Auftrag

„Zeige mir die lokale Entdeckungsseite auf meinem iPhone.“ ChatGPT zeigt das Zielgerät, der Mac startet eine kurze Sitzung, Diagnostics öffnet die Seite und eine zweite Beobachtung bestätigt den sichtbaren Zustand. Die Karte nennt Gerät, Ergebnis und Zeitpunkt. Bei Verbindungsverlust bleibt der letzte bestätigte Zustand mit seinem Alter sichtbar. Erfolg bedeutet, dass der Nutzer die Seite auf seinem Gerät sehen kann und versteht, ob die Sitzung noch läuft.

## Architektur und Prioritäten

| Reihenfolge | Entscheidung und Anlass | Abnahme |
| --- | --- | --- |
| 1. Bekannten Zustand binden | PhoneService speichert beim Vorbereiten die observationId, prüft beim Ausführen aber das Alter der letzten Sitzungsbeobachtung. Ein Refresh mit gleichem Fingerabdruck kann einen alten Vorschlag wieder frisch erscheinen lassen. Vorschlag an ursprüngliche Beobachtung und eigene Frist binden. | Vorbereiten, Zeit verstreichen lassen, identisch neu beobachten und alten Vorschlag senden. Der Treiber erhält keinen Auftrag. |
| 2. Unterbrechung verständlich machen | Stop kann pendingOperation melden, während die Karte bereits „Session stopped“ anzeigt. Karte soll zwischen Stop angefordert und Sitzung beendet unterscheiden. Späte Antworten einer alten Sitzung dürfen die neue Karte nicht überschreiben. | Während einer laufenden Navigation stoppen, Antwortreihenfolge umkehren und Verbindung trennen. Die Karte zeigt weder vorzeitigen Erfolg noch erneut aktive Bedienelemente. |
| 3. Erste reale Strecke abnehmen | Lokales stdio, USB und ChatGPT-Webverbindung einzeln prüfen. Das Dashboard soll für jede Stufe den letzten erfolgreichen Schritt und eine konkrete Abhilfe nennen. | Auf dem entsperrten, gekoppelten Gerät einmal öffnen, navigieren, Ergebnis zurücklesen und stoppen. Danach denselben Auftrag aus dem privaten ChatGPT-Client auslösen. Sitzung und Testergebnis ohne Gerätekennung dokumentieren. |
| 4. Fähigkeiten gezielt erweitern | Eigene Diagnostics-Oberfläche über feste öffentliche Marker bedienen. Für fachliche Schreibaktionen native App Intents mit lokaler Bestätigung des exakten Ziels verwenden. MobileCLI separat installieren. WDA oder iCTRL erst als alternative Treiber aufnehmen, wenn sie denselben Vertrag einschließlich Abbruch und Ergebnisprüfung bestehen. | Jeder Adapter liefert für denselben Testfall dieselbe Bedeutung von „bestätigt“, „abgelehnt“ und „Ausgang unbekannt“. Nach Versand erfolgt kein automatischer Wechsel zu einem anderen Treiber. |
| 5. Betrieb auf fremden Macs vorbereiten | Versionen von Mac-Helfer, iOS-App und Werkzeugvertrag beim Start abgleichen. Einrichtung, Update, Widerruf und Deinstallation gehören zum Produkt. Für eine öffentliche Ausgabe zuerst Abhängigkeiten, Lizenz und Verteilungsweg prüfen. | Auf einem frischen Mac installieren, inkompatible App-Version erklären, Zugriff lokal widerrufen und erneut verbinden. Der alte Client kann anschließend keine Sitzung starten. |

## Grenzen für spätere Ausgaben

Ein Einzelplatz-Mac kann die vorhandene lokale Gerätesperre verwenden. Sobald ein zweiter Nutzer oder ein zweites iPhone hinzukommt, müssen Nutzer, Sitzung, Gerät und Berechtigung durchgehend zusammengehören. Das Gerät bleibt für die Sitzungsdauer fest zugeordnet. Der Test dafür ist ein Gerätewechsel bei laufender Sitzung.

Für eine optionale Liveansicht braucht es vor dem ersten Bild eine sichtbare Freigabe am Gerät, eine klar erkennbare Übertragungsanzeige, einen lokalen Stop und eine definierte Regel für Sperrbildschirm und App-Wechsel. Für die erste Ausgabe reichen öffentliche Zustandsmarker. Das reduziert die Daten, die das Gerät verlassen, und macht die Abnahme reproduzierbar.

Ergebnisse liegen derzeit im Prozessspeicher. Vor der ersten dauerhaften Schreibaktion muss ein Neustart zwischen Versand und Rückmeldung abgedeckt sein. Ein lokales, kurzlebiges Protokoll aus Auftragskennung, Aktionstyp und Status ermöglicht den Abgleich ohne persönliche Inhalte. Bei unklarem Ausgang bleibt die Wiederholung gesperrt, bis das Ergebnis geklärt ist.

## Grundlage

Dieser Entwurf beschreibt geplante Änderungen. Der vorhandene Umfang und die bisherigen Nachweise stehen im [Implementierungsbericht](chatgpt-iphone-plugin-2026-11-22.md). Die ersten beiden Befunde stammen aus [Sitzungsdienst](../../plugins/iphone-connect/src/service.mjs) und [Dashboard](../../plugins/iphone-connect/ui/dashboard.mjs).
