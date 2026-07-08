# iGentic — Anbieter-Übersicht für LocalModelRuntime & Cloud-Fallback

**Stand:** Juli 2026  
**Letzte Verifizierung:** 2026-07-08  
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
| Tier 4: Experimentell         |
--------------------------------
```

Grundprinzip der `PolicyEngine`:

```text
Private/sensible Daten? → JA → Local only (Tier 0/1)
Öffentliche/unkritische Daten? → Cloud erlaubt (Tier 3, mit Approval + AuditLog)
```

## 2. Tier 0 — On-Device

Kein Netzwerk. Höchste Priorität.

| Technologie | Rolle | API vorhanden | Kosten | Verifizierungsstand |
|---|---|---:|---:|---|
| CoreML | Apple-natives On-Device-Framework | Ja | Kostenlos | Plattform-nativ, auf Gerätenetzwerk nicht angewiesen |
| MLX | Lokales Inferenz-Framework | Ja | Kostenlos | Apple-silicon-orientiert, lokal ausführbar |
| llama.cpp / GGUF | Lokaler Inferenz-Runtime | Ja | Kostenlos | Open-Source, lokaler Server und OpenAI-kompatible HTTP-API verfügbar |

## 3. Tier 1 — Private Local Runtime

Cloud-fähig, aber lokal betreibbar.

| Anbieter | Rolle | Free Tier / API | Kosten | Verifizierungsstand |
|---|---|---|---|---|
| Ollama | Lokale Modellverwaltung | Lokal unbegrenzt, REST-API nativ | Kostenlos lokal; Cloud separat | Lokal-first; Cloud-Option vorhanden, Daten sollen nicht zum Training verwendet werden |
| LocalAI | OpenAI-kompatible lokale API | Lokal unbegrenzt | Kostenlos self-hosted | Lokale OpenAI-kompatible API; Privacy-fokussiert |
| LM Studio | Lokale Entwickler-/Testumgebung | Lokal kostenlos; OpenAI-Compatibility-API und Headless-Deployments | Kostenlos für Home und Work | Lokale und private Ausführung, zusätzlich SDKs und API-Kompatibilität |
| Jan | Lokaler Desktop-Assistent | Free & open source; API-Reference vorhanden | Kostenlos | Fokus auf personal intelligence; lokale Modelle plus optionale Online-Modelle |
| GPT4All | Offline-Client | Lokal kostenlos | Kostenlos | Weiter als optionaler Offline-Client beobachtet |
| AnythingLLM | Lokales RAG / Wissensspeicher | Desktop kostenlos; self-hosted und cloud verfügbar | Kostenlos self-hosted; Cloud separat | Geeignet als Knowledge-Backend und für Multi-User-/Admin-Szenarien |

## 4. Tier 2 — Private Knowledge Layer

| Komponente | Rolle | Kosten | Verifizierungsstand |
|---|---|---|---|
| AnythingLLM | RAG / Wissens-Backend | Kostenlos self-hosted | Geeignet als lokale Wissensschicht; Cloud-Variante existiert |
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

| Anbieter | Free Tier | API | Jurisdiktion | Training / Retention | ZDR | Kosten ab | Verifizierungsstand |
|---|---|---|---|---|---|---|---|
| Mistral AI (La Plateforme) | Ja | Ja | EU; Mistral nennt EU-gehostete Server | API, Docs, Pricing und DPA sind öffentlich verlinkt; konkrete No-Training-Regeln vor der Integration im Legal-Set prüfen | Ja / legal zu prüfen | Nutzungsbasiert | Starkes EU-Fallback; Self-hosted und Mistral-Cloud-Optionen vorhanden |
| Groq | Ja | Ja | USA | Inference-Daten werden standardmäßig nicht aufbewahrt; Logging kann für Reliability/Abuse bis zu 30 Tage greifen | Ja | Nutzungsbasiert | Sehr stark, wenn ZDR aktiv gesetzt ist |
| OpenRouter | Ja | Ja | Variiert nach Route | ZDR kann global, pro Modellgruppe, pro Guardrail oder pro Request erzwungen werden; Prompt-Retention ist opt-in | Ja | Nutzungsbasiert | Als Routing-Layer brauchbar, aber Downstream-Policy je Endpoint prüfen |
| Google AI Studio / Gemini API | Ja | Ja | USA / globale Infrastruktur | API, REST, OpenAI-Kompatibilität, Terms, Privacy, Logging und Regions sind dokumentiert; Trainings-/Regionenfrage für Produktivbetrieb separat verifizieren | Nein im Free-Tier-Kontext | Kostenpflichtige Tiers verfügbar | API ist real; Privacy-/Regionenregeln müssen vor Produktivnutzung gesondert geprüft werden |
| NVIDIA NIM / build.nvidia.com | Ja | Ja | USA | Free inference mit führenden Modellen wird beworben; Datenschutz- und Logging-Details vor Produktivnutzung separat prüfen | Nicht verifiziert | Nutzungsbasiert / planabhängig | Eher Test- und Experiment-Option als Default-Fallback |
| Hugging Face Inference Endpoints / Providers | Teilweise / modellabhängig | Ja | USA / EU je nach Host | API- und Endpoint-Layer vorhanden; Free-Tier und Privacy sind modell- bzw. providerabhängig | Nicht verifiziert | Volumen-/Endpoint-abhängig | Heterogen; pro Modell und Provider separat bewerten |
| Venice.ai | Ja | Ja | USA | OpenAI-kompatible API, private/unrestricted Positionierung, 100+ Text-Modelle und Tools; ZDR und Governance müssen vor Einsatz separat geprüft werden | Unklar | Abonnement / Nutzungsmodell | Nur mit zusätzlichen Guardrails sinnvoll |
| Proton Lumo | Consumer-Free-Tier vorhanden | Keine verifizierte offizielle API im aktuellen Stand | Schweiz / EU-naher Datenschutzansatz | Consumer-Produkt mit Privacy-Fokus; API-Integration derzeit nicht als belastbar verifiziert | — | Roadmap / unklar | Derzeit nicht als Produktions-Backend einplanen |
| Aleph Alpha (PhariaAI) | Kein klassischer Self-Service-Tier | Ja | Deutschland / Europa | Souveräne KI, europäische Infrastruktur, DPA/Privacy vorhanden; enterprise-lastig | On-Prem de facto sehr stark | Enterprise | Sehr gut für regulierte Szenarien, aber Einstieg schwerer |

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
1. Lokal (Tier 0/1): CoreML / Ollama / LocalAI / LM Studio — immer erste Wahl
2. Falls Cloud nötig UND Daten als "öffentlich/unkritisch" klassifiziert:
   a) Mistral AI — primärer Cloud-Fallback
   b) Groq — sekundärer Cloud-Fallback, nur mit ZDR aktiv
3. OpenRouter nur als Routing-Schicht mit explizitem ZDR-Filter und pro-Endpoint-Prüfung
4. Google AI Studio / NVIDIA / Hugging Face / Venice / Proton Lumo nur nach zusätzlicher Prüfung
5. Aleph Alpha: interessant für regulierte / Enterprise-Anwendungsfälle
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

- Google AI Studio: Trainings- und Regionsregeln vor Produktivnutzung direkt aus den aktuellen Terms/Privacy-/Regionen-Seiten festziehen.
- Hugging Face: Free-Tier- und Datenschutzannahmen immer pro Endpoint und Provider prüfen.
- Proton Lumo: offizielle API- und Governance-Situation weiter beobachten; derzeit nicht als stabile Integration behandeln.
- Venice.ai: ZDR und Retention vor jeder Nutzung erneut verifizieren.

## 11. Einordnung für iGentic

Diese Übersicht unterstützt die Architekturentscheidung für `LocalModelRuntime` und Cloud-Fallbacks. Die Prioritätslogik bleibt:

- private/sensible Daten → lokal;
- öffentliche/unkritische Daten → Cloud nur mit Approval;
- alles andere → nicht automatisieren.

Vor einer Implementierung sollten die Provider in kleine, testbare Adapter geschnitten werden, damit Policy, Approval und Audit unabhängig von der Backend-Wahl bleiben.
