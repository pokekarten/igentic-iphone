# API-freier iGentic-Status-Loop über Kurzbefehle

**Stand:** Offline-Implementierung zur Review, auf dem nativen Read-only-Runner aus PR #421 gestapelt. Nicht auf einem echten iPhone, in Siri oder mit dem ChatGPT-Erweiterungsmodell abgenommen.

## Ein tatsächlich implementierter Gerätebaustein – ohne OpenAI API

Die eigene iGentic-iPhone-App bietet zwei **zusätzliche** Systemaktionen als `AppIntent`: **„iGentic Status-Loop starten“** und **„iGentic Status-Loop fortsetzen“**. Ein Benutzer kann diese im iOS-Kurzbefehle-Editor zu einem Ablauf verbinden:

1. `Start` legt einen zufälligen, lokalen Auftrag mit maximal fünf Minuten Gültigkeit an. Das Ergebnis ist JSON mit `schema`, `taskId` und einem **festen, personenbezugsfreien** `prompt`.
2. Kurzbefehle kann **nur das Feld `prompt`** an „Modell verwenden“ weitergeben: ChatGPT-Erweiterung, anderes Modell oder für Tests fester JSON-Text. Die ID ist lediglich Korrelation, keine Identität oder Freigabe.
3. `Fortsetzen(taskId, modelReply)` prüft den rohen Modellvorschlag mit dem bestehenden `AgentLoopModelHandoff.review`. Erlaubt ist anfangs ausschließlich `{"action":"status.read"}`. Fremde Schlüssel, doppelte Schlüssel, falsche Reihenfolge und ein Modell-`approved` werden zurückgewiesen.
4. Nach PolicyEngine-`localOnly/read` schreibt iGentic **vor** der Statusabfrage einen `readAttempted`-Marker in `Application Support/iGentic/shortcuts-status-loop-v1.json`. Erst danach liest die eigene App Akku, Stromsparmodus und iOS-Version. Nach erfolgreicher Persistierung der Phase `awaitingFinish` liefert die App eine **lokale** Antwort inklusive Beobachtung an Kurzbefehle zurück.
5. Der Eigentümer kann diese Beobachtung lokal anzeigen. **Nur sein selbst konfigurierter Kurzbefehl** kann sie an ein externes Modell weitergeben, wenn er diese bewusste Datenweitergabe wünscht. iGentic ruft selbst weder ChatGPT noch andere Anbieter auf.
6. Zweite Runde: `{"action":"finish"}` an dieselbe `taskId` übergeben. Nur dadurch wird `finished` gespeichert; die Schlussantwort enthält keine Observation. Ohne Cloud-Modell lässt sich dieser Abschluss direkt mit festem JSON aus Kurzbefehle auslösen.

## Ergebnisvertrag

Nach einer lokalen Abfrage: `stage=awaitingFinish`, `localStatusRead=true`, `remoteActionExecuted=false`, `ownerApproved=false`, `observation=<grober Status>`. Nach Abschluss: `stage=finished` mit `observation` ausgelassen. **Das ist kein kryptographischer Gerätebeweis oder eine unabhängig verifizierte iPhone-Ausführung**. Die Statusausgabe entsteht in der eigenen App und darf von einem entfernten ChatGPT-Plugin nicht als Attestation verwendet werden.

Das JSON enthält keine Fotos, Nachrichten, Kontakte, Credential, Listen von Apps oder Geräte-IDs. `taskId` ist keine Authentifizierung: Der Ablauf bleibt ein lokal vom Eigentümer gestarteter Kurzbefehle-Flow, **kein** externes Task-Submission-API.

## Fail-closed-Regeln

- Genau **eine** lokale Statusabfrage und ein Abschluss; keine automatischen Wiederholungen, keine Schreibaktionen, kein Siri- oder Fremd-App-Zugriff.
- Die beiden Systemaktionen sind lokale App-Intents; nicht über einen ChatGPT-Site-MCP-Endpunkt veröffentlicht.
- Das iGentic-Journal wird mit atomarem Replace und iOS Complete Data Protection geschrieben (POSIX `0600`). Ein atomar erzeugtes `.claim`-Verzeichnis sperrt konkurrierende App-Intent-Prozesse. Ein Prozessabbruch während dieser Sperre hinterlässt **bewusst** eine Blockierung: noch kein sicherer automatischer Lock-Recovery-Pfad. Die separate Eigentümer-Recovery muss vor Produktionsfreigabe entworfen werden.
- `readAttempted` wird vor der Statusabfrage persistiert; bleibt die Ausführung ungewiss, wird sie nicht spekulativ wiederholt. Nach regulärem Abschluss/Abbruch oder Ablauf kann eine neue zufällige Aufgaben-ID beginnen, **sofern keine zurückgebliebene Sperre existiert**.
- Die JSON-Datei enthält keinen Eigentümer-Schlüssel und ist nicht gegen Manipulation durch einen lokalen Prozess mit demselben App-Sandbox-Zugriff kryptographisch versiegelt. Das Sicherheitsmodell setzt das isolierte, signierte iOS-App-Sandbox-Vertrauensniveau voraus; ein späterer Fernkanal muss die Replay-/Authentifizierungs-PRs #411–#420 gesondert integrieren.
- Das erste Feld `observation` ist sichtbar in der Kurzbefehle-Rückgabe. Ob der Eigentümer diese an ChatGPT weiterleitet, entscheidet ausschließlich die von ihm eingerichtete Shortcut-Kette. **Local Only in PolicyEngine verhindert nicht, dass ein anschließend unabhängig konfigurierter Kurzbefehl dieselben Daten extern weitergibt.**

## Testmatrix ohne iPhone

Swift-Tests prüfen über mehrere neue Store-Instanzen (simulierte Prozessgrenzen): Status lesen → Ende, erneuter Leseversuch, falsche Task-ID, ungültige und gefälschte Modellantworten, Zeitablauf, zukünftigen Zeitstempel, persistierten `readAttempted`-Marker, defekte oder übergroße JSON-Dateien, Symbolic Links und konkurrierenden `.claim`-Status. Xcode-27-Simulator-Build prüft die AppIntents-Kompilierung; er ersetzt **keine** reale Kurzbefehle-/Siri-/ChatGPT-Abnahme.

## Nächste Integration

Erst die Schnittstelle in einem **signierten iOS-27-Build** auf einem echten iPhone installieren und zwei reale Aufrufe der beiden App Intents in Kurzbefehle nachweisen. Getrennt testen: mit festem JSON, danach – optional und bewusst – mit der ChatGPT-Systemerweiterung. Anschließend native Beobachtungen und die signierten Remote-Receipt-Verträge aus #413–#420 in einem unabhängigen Integrations-PR verbinden. Niemals einen Modellvorschlag als Autorisierung oder eine lokale Test-Observation als Geräteattestation übernehmen.

Referenzen: [Apple App Intents](https://developer.apple.com/documentation/appintents/appintent), [App Intent supportedModes](https://developer.apple.com/documentation/appintents/appintent/supportedmodes).
