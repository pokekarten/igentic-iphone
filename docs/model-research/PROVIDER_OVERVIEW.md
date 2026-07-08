# iGentic — Anbieter-Übersicht für LocalModelRuntime & Cloud-Fallback

**Stand:** Juli 2026  
**Status:** Research-Part / Arbeitsdokument  
**Kontext:** Bewertung von KI-Anbietern für die iGentic-Architektur (`AgentKernel` → `TaskRouter` → `PolicyEngine` → `ApprovalManager` → `LocalModelRuntime`) mit Fokus auf Privacy-Kriterien, Free-Tier-Verfügbarkeit, API-Zugang und Kostenmodell.

Diese Datei ist ein Research-Part, keine Integrationsfreigabe. Vor jeder Implementierung müssen die aktuellen Anbieter-Dokumente, ToS, Privacy-Policies und Pricing-Seiten erneut geprüft werden.

## 1. Architektur-Einordnung

```text
iPhone App
    |
AgentKernel
    |
PolicyEngine
    |
LocalModelRuntime
    |
--------------------------------
| Tier 0: On-Device            |
| Tier 1: Private Local Runtime |
| Tier 2: Private Knowledge     |
| Tier 3: Privacy Cloud         |
| Tier 4: Experimentell        |
--------------------------------
```

Grundprinzip der `PolicyEngine`:

```text
Private/sensible Daten? → JA → Local only (Tier 0/1)
Öffentliche/unkritische Daten? → Cloud erlaubt (Tier 3, mit Approval + AuditLog)
```

## 2. Tier 0 — On-Device

Kein Netzwerk. Höchste Priorität.

| Technologie | Rolle | API vorhanden | Kosten | Privacy-Bewertung |
|---|---|---:|---:|---|
| CoreML | Apple-natives On-Device-Framework | Ja | Kostenlos | Höchste Privacy; läuft vollständig auf dem Gerät |
| MLX | Lokales Inferenz-Framework | Ja | Kostenlos | Vollständig lokal |
| llama.cpp / GGUF | Lokaler Inferenz-Runtime | Ja | Kostenlos | Quelloffen, keine Telemetrie standardmäßig |

## 3. Tier 1 — Private Local Runtime

Cloud-fähig, aber lokal betreibbar.

| Anbieter | Rolle | Free Tier / API | Kosten | Privacy-Bewertung |
|---|---|---|---|---|
| Ollama | Lokale Modellverwaltung | Lokal unbegrenzt, REST-API nativ | Kostenlos lokal | Sehr hoch, wenn lokal betrieben |
| LocalAI | OpenAI-kompatible lokale API | Lokal unbegrenzt | Kostenlos self-hosted | Sehr hoch |
| LM Studio | Entwickler-/Consumer-Testumgebung | Lokal kostenlos, lokaler API-Server | Kostenlos | Hoch; lokale Inferenz, aber geschlossene UI |
| Jan AI | Lokaler Desktop-Assistent | Lokal kostenlos, OpenAI-kompatibel | Kostenlos | Hoch, lokal-first |
| GPT4All | Offline-Client | Lokal kostenlos | Kostenlos | Mittel bis hoch, je nach Use Case |
| AnythingLLM | Lokales RAG / Wissensspeicher | Lokal kostenlos, Desktop + API-Modus | Kostenlos self-hosted | Sehr hoch als Knowledge-Backend |

## 4. Tier 2 — Private Knowledge Layer

| Komponente | Rolle | Kosten | Privacy-Bewertung |
|---|---|---|---|
| AnythingLLM | RAG / Vektorspeicher-Backend | Kostenlos self-hosted | Sehr hoch |
| Encrypted Memory / Vector DB | Architektur-Option | Offen | Ziel: sensible Daten lokal und verschlüsselt halten |

## 5. Tier 3 — Privacy Cloud

Nur nach explizitem Approval und mit AuditLog.

### Bewertungskriterien

- Jurisdiktion, möglichst EU/DE-nah
- Vertragliche No-Training-Zusage
- Zero Data Retention (ZDR), falls verfügbar
- Reale Developer-API, nicht nur Consumer-Wrapper
- Free Tier ohne harte Hürden, wenn möglich

### Anbieter-Tabelle

| Anbieter | Free Tier | API | Jurisdiktion | Training-Policy | ZDR | Kosten ab | Privacy-Bewertung |
|---|---|---|---|---|---|---|---|
| Mistral AI (La Plateforme) | Ja | Ja | EU, Frankreich | API-/Enterprise-Bedingungen mit No-Training-Position | Ja | Nutzungsbasiert | Sehr hoch; primärer Cloud-Fallback-Kandidat |
| Groq | Ja | Ja | USA | Keine Nutzung der Inputs/Outputs zum Training ohne explizite Erlaubnis | Zuschaltbar | Nutzungsbasiert | Hoch; nur mit aktivem ZDR-Flag für sensiblere Fälle |
| OpenRouter | Ja | Ja | Variiert | Abhängig vom Downstream-Provider | Als Filter einstellbar | Nutzungsbasiert | Mittel; nur mit explizitem ZDR-/Provider-Filter |
| Google AI Studio (Gemini) | Ja | Ja | USA / globale Infrastruktur | Policies und Regionseinschränkungen vor Einsatz schriftlich verifizieren | Nein im Free Tier | Kostenpflichtige Tiers verfügbar | Mittel; vor Produktivnutzung gesondert prüfen |
| NVIDIA NIM | Ja | Ja | USA | Keine belastbare No-Training-Garantie in Standardbedingungen | Nein (Standard) | Nutzungsbasiert | Mittel |
| HuggingFace Inference API | Ja (rate-limitiert) | Ja | USA / EU je nach Host | Hängt vom jeweiligen Modell-Anbieter ab | Nein (Standard) | Volumenabhängig | Mittel; pro Modell prüfen |
| Venice.ai | Ja, knapp | Ja | USA | Uncensored-/Governance-lückig positioniert | Unklar dokumentiert | Abonnement / Nutzungsmodell | Niedrig bis mittel; nur mit zusätzlichen Guardrails |
| Proton Lumo | Consumer-Free-Tier vorhanden | Derzeit keine offizielle API | Schweiz | Zero-Access-Encryption im Consumer-Produkt beworben | — | API laut Roadmap in Entwicklung | Hoch als Produktkonzept, derzeit nicht integrierbar |
| Aleph Alpha (PhariaAI) | Kein klassischer Self-Service-Tier | Ja | Deutschland | Auditierbarkeit und On-Premise-Optionen im Fokus | Ja, on-prem de facto vollständig | Enterprise | Sehr hoch, aber enterprise-lastig |

## 6. Tier 4 — Experimentell

Nur beobachten, nicht als Backend standardisieren.

| Anbieter | Status | Anmerkung |
|---|---|---|
| Duck.ai | Kein Developer-API | Gut als UX-Referenz, nicht als Runtime-Baustein |
| Brave Leo | Kein eigenständiges Developer-API | Interessant für Privacy-UX, nicht als Agent-Runtime |
| Xprivo / Ask Safely / Confer.to / Ellydee.ai | Technisch ungeklärt | Vor jeder Integration: API, Audit und Privacy prüfen |

## 7. Governance-Layer

| Konzept | Rolle in iGentic |
|---|---|
| Tailscale Aperture | Kontrollschicht-Idee, kein Modell-Provider |
| `ModelProvider`-Protokoll (Swift) | Vereinheitlichung aller Adapter |

Vorschlag:

```swift
func generate(request: ModelRequest) async throws -> ModelResponse
```

## 8. Empfohlene Provider-Kette für `LocalModelRuntime`

```text
1. Lokal (Tier 0/1): CoreML / Ollama / LocalAI — immer erste Wahl
2. Falls Cloud nötig UND Daten als "öffentlich/unkritisch" klassifiziert:
   a) Mistral AI — primärer Cloud-Fallback
   b) Groq — sekundärer Cloud-Fallback, nur mit ZDR-Flag
3. Alles andere nur für explizit unkritische Testfälle
4. Proton Lumo: aktuell nicht integrierbar, da keine stabile API
5. Aleph Alpha: interessant für regulierte/Enterprise-Anwendungsfälle
```

## 9. AuditLog-Minimalschema

Jede Eskalation in Tier 3 sollte protokolliert werden:

```text
Request
Provider
Data Classification (privat/öffentlich)
ZDR-Status (aktiv/inaktiv/nicht verfügbar)
Approval (wer/wann)
Result Hash
Timestamp
```

## 10. Offene Prüfpunkte

- Google AI Studio: EU/EEA-Trainingsausnahme vor Produktivnutzung schriftlich bestätigen lassen.
- OpenRouter: Downstream-Provider-Policy pro Modell einzeln prüfen.
- Proton Lumo: API-Launch und Datenschutz-Garantien regelmäßig neu prüfen.
- Venice.ai: Zero-Data-Retention und Governance vor jeder Nutzung erneut verifizieren.

## 11. Einordnung für iGentic

Diese Übersicht unterstützt die Architekturentscheidung für `LocalModelRuntime` und Cloud-Fallbacks. Die Prioritätslogik bleibt:

- private/sensible Daten → lokal;
- öffentliche/unkritische Daten → Cloud nur mit Approval;
- alles andere → nicht automatisieren.

Vor einer Implementierung sollten die Provider in kleine, testbare Adapter geschnitten werden, damit Policy, Approval und Audit unabhängig von der Backend-Wahl bleiben.
