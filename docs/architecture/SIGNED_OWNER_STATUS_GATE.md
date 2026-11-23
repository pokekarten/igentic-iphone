# Signierter iPhone-Auftrag → native Freigabegrenze → lokale Statusabfrage

**Status:** isolierter Integrations-Prototyp der vorhandenen PRs #416 und #422, einschließlich einer lokalen SwiftUI-Prüfansicht. Noch **keine** echte ChatGPT-Site→iPhone-Verbindung, keine Provisionierung für den Besitzer-Button, kein durchlaufener iPhone-/Siri-/Shortcuts-Test und keine unabhängige Geräteattestation.

## Die tatsächlich integrierten Bausteine

`AgentLoopSignedOwnerStatusGate` verbindet bereits bestehende eigene Swift-Komponenten ohne fremden Bibliothekscode zu kopieren:

1. Der künftige native Transport übergibt einen *kanonischen* begrenzten `read-only-task-proposal`-Envelope und einen vorher sicher im eigenen iOS-Kontext provisionierten 32-Byte-Owner-Relay-Key. **Diese Integration provisioniert keinen Schlüssel und bietet keinen neuen Remote-Eingang.**
2. `AgentLoopRemoteTaskVerifier` prüft die exakten HMAC-SHA256-Bytes, die Request-ID, den erlaubten Namen `igentic.own_app.status.read`, leere Parameter, max. 60-Sekunden-TTL und zulässige Systemzeit. Fremde, doppelte oder veränderte JSON-Felder sind unzulässig.
3. `AgentLoopNativePolicyPreflight` bewertet eine mögliche **externe Statusweitergabe** ausdrücklich als `externalShare` und verlangt eine lokale Eigentümerprüfung. `localOnly` sperrt diesen Pfad, statt ihn über die separate rein lokale Leseerlaubnis zu umgehen.
4. `AgentLoopLocalReplayJournal` reserviert den Request-Identifier dauerhaft vor jeder möglichen Folgeaktion. Ein erneuter Signatur-Envelope mit derselben ID wird auch nach neuer Instanziierung gesperrt. Es ist keine synchrone Remote-Transaktion oder bestätigte Zustellung.
5. Die Sitzung wird `awaitingOwnerReview`. Der eigenständige Übergang `readAfterLocalReviewAction()` ist in der **isolierten nativen SwiftUI-Prüfansicht** `AgentLoopSignedOwnerReviewView` mit einem expliziten Button verbunden. Ein Modell, App Intent, Plugin oder Relay darf ihn **nicht** direkt auslösen. Noch fehlt die Anbindung der Ansicht an einen sicher provisionierten Eingang und Keychain-Schlüsselspeicher; die Ansicht ist somit nicht als Remote-Funktion nutzbar.
6. Die read-only `PolicyEngine` erlaubt erst dann die begrenzte lokale Abfrage über den bestehenden `AgentLoopLocalStatus`-Leser. Nach der Statusabfrage werden Zeitfenster und Ausführungszustand nochmals geprüft. Eine verspätete Beobachtung wird verworfen.
7. Das Ergebnis ist nur ein **lokales In-App-Objekt**. Es enthält den groben Status nach erfolgreicher lokaler Abfrage; ein externer Versand oder eine signierte, unabhängige Gerätebestätigung ist nicht implementiert.

## Wahrheitsgetreuer Beleg

Alle Ausgaben melden `externalDataShared=false`, `ownerConsentAttested=false`, `remoteActionExecuted=false` und `independentDeviceReceipt="none"`. Selbst wenn ein synthetischer Test den Methodenübergang ausführt, ist das **kein Nachweis eines menschlichen Zustimmungstaps**, keiner realen Geräteausführung und keiner bestätigten Plugin-Antwort. Die HMAC-Signatur beweist nur Kenntnis des vorgegebenen Relay-Schlüssels, keine Identität eines physischen iPhones.

Die `ownerAppObservation` verbleibt in dieser Swift-Sitzung. Ein späterer Transport darf sie nicht ohne separate owner-spezifische externe Freigabe, echten Ergebnisbeleg, Schlüsselschutz und Replay-/Timeout-Abnahme übertragen. Der Benutzer kann eigene Kurzbefehle gesondert zum Teilen anleiten, aber dieser Gate-Typ führt sie nicht aus.

## Offline-Sicherheitstests

Die Swift-XCTest-Suite `AgentLoopSignedOwnerStatusGateTests` prüft: signierter/paritätskompatibler Test-Envelope, dauerhafte Replay-Sperre über neue Sitzungen, native localOnly-Policy vor Reservation, manipulierte Signaturen und unbekannte Tools, fehlende Eigentümer-Freigabe, Ablauf vor und während Status-Lesen und verschachtelte Callback-Reentrancy. Alle Tests benutzen synthetische Statuswerte und einen veröffentlichten **Test-Key**, keine produktiven Zugangsdaten.

**Offene P0-Abnahme:** Sicheres Geräte-/Keychain-Enrolment, die vorhandene SwiftUI-Owner-Review auf dem signierten physischen Gerät mit echter Besitzerinteraktion testen, getrennte echte Eigentümerbestätigung, freigabegesteuerte Antwort/Rückgabe an das Plugin, unabhängig überprüfbare signierte Device Receipts mit Nonce-Challenge, tatsächliches iPhone im WLAN/Mobilfunk/USB-C und iOS 27 Kurzbefehle-/Siri-Tests. Bis dahin kein Remote-Execution-Flag auf `true` setzen.

Stacking: Ausgangszweig PR #422 + Merge der nicht gemergten PR-#416-Entwicklung, separate Draft-Integration. Kein Merge nach `main` und keine Veröffentlichung der privaten ChatGPT-Site.
