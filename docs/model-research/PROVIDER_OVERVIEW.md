# iGentic — Anbieter-Übersicht für LocalModelRuntime & Cloud-Fallback

**Stand:** Juli 2026  
**Letzte Verifizierung:** 2026-07-08  
**Status:** Research-Part / Arbeitsdokument  
**Kontext:** Bewertung von KI-Anbietern für die iGentic-Architektur (`AgentKernel` → `TaskRouter` → `PolicyEngine` → `ApprovalManager` → `LocalModelRuntime`) mit Fokus auf Privacy-Kriterien, Free-/Scale-Tier-Verfügbarkeit, API-Zugang, Datenresidenz und Kostenmodell.

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
| Ollama | Lokale Modellverwaltung | Lokal unbegrenzt, REST-API nativ | Kostenlos lokal; Cloud separat | Lokal-first; Cloud-Option vorhanden |
| LocalAI | OpenAI-kompatible lokale API | Lokal unbegrenzt | Kostenlos self-hosted | Lokale OpenAI-kompatible API; Privacy-fokussiert |
| LM Studio | Lokale Entwickler-/Testumgebung | Lokal kostenlos; OpenAI-Kompatibilitäts-API und Headless-Deployments | Kostenlos für Home und Work | Lokale und private Ausführung, zusätzlich SDKs und API-Kompatibilität |
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
- Vertragliche No-Training-Zusage oder klar kontrollierbare Training-Opt-outs
- Zero Data Retention (ZDR), falls verfügbar
- Reale Developer-API, nicht nur Consumer-Wrapper
- Free-/Scale-Tier sauber voneinander getrennt

### Anbieter-Tabelle

| Anbieter | Free Tier | API | Jurisdiktion | Training / Retention | ZDR | Kosten ab | Verifizierungsstand |
|---|---|---|---|---|---|---|---|
| Mistral AI (La Plateforme / Studio) | Ja | Ja | Frankreich / EU; EU-Hosting ist Standard, US-Endpoint optional | API-Daten werden laut Doku nicht für Training verwendet; Vibe Free kann für Modellverbesserung genutzt werden, Opt-out ist im Admin Panel möglich; Labs-Modelle können davon abweichen | Ja, aber nur Scale plan und nur für stateless API calls | Nutzungsbasiert | Starker EU-Fallback; für iGentic sehr relevant |
| Groq | Ja | Ja | USA | Inference-Daten werden standardmäßig nicht aufbewahrt; Logging kann für Reliability/Abuse zeitlich begrenzt erfolgen | Ja | Nutzungsbasiert | Sehr stark, wenn ZDR aktiv gesetzt ist |
| OpenRouter | Ja | Ja | Variiert nach Route | ZDR kann je nach Route/Policy steuerbar sein; Downstream-Policy pro Endpoint prüfen | Ja | Nutzungsbasiert | Als Routing-Layer brauchbar, aber nicht als alleinige Datenschutzgarantie |
| Google AI Studio / Gemini API | Ja | Ja | USA / globale Infrastruktur | API- und Regionseigenschaften sind dokumentiert; Trainings- und Regionsregeln für Produktivbetrieb separat verifizieren | Nein im Free-Tier-Kontext | Kostenpflichtige Tiers verfügbar | API ist real; Privacy-/Regionenregeln müssen vor Produktivnutzung gesondert geprüft werden |
| NVIDIA NIM / build.nvidia.com | Ja | Ja | USA | Free inference mit führenden Modellen wird beworben; Datenschutz- und Logging-Details vor Produktivnutzung separat prüfen | Nicht verifiziert | Nutzungsbasiert / planabhängig | Eher Test- und Experiment-Option als Default-Fallback |
| Hugging Face Inference Endpoints / Providers | Teilweise / modellabhängig | Ja | USA / EU je nach Host | API- und Endpoint-Layer vorhanden; Free-Tier und Privacy sind modell- bzw. providerabhängig | Nicht verifiziert | Volumen-/Endpoint-abhängig | Heterogen; pro Modell und Provider separat bewerten |
| Venice.ai | Ja | Ja | USA | OpenAI-kompatible API, private Positionierung, viele Text-Modelle und Tools; ZDR und Governance müssen vor Einsatz separat geprüft werden | Unklar | Abonnement / Nutzungsmodell | Nur mit zusätzlichen Guardrails sinnvoll |
| Proton Lumo | Consumer-Free-Tier vorhanden | Keine verifizierte offizielle API im aktuellen Stand | Schweiz / EU-naher Datenschutzansatz | Consumer-Produkt mit Privacy-Fokus; API-Integration derzeit nicht belastbar verifiziert | — | Roadmap / unklar | Derzeit nicht als Produktions-Backend einplanen |
| Aleph Alpha (PhariaAI) | Kein klassischer Self-Service-Tier | Ja | Deutschland / Europa | Souveräne KI, europäische Infrastruktur, DPA/Privacy vorhanden; enterprise-lastig | On-Prem de facto sehr stark | Enterprise | Sehr gut für regulierte Szenarien, aber Einstieg schwerer |

## 6. Tier 4 — Experimentell

Nur beobachten, nicht als Backend standardisieren.

| Anbieter | Status | Anmerkung |
|---|---|---|
| Duck.ai | Kein Developer-API | Gut als UX-Referenz, nicht als Runtime-Baustein |
| Brave Leo | Kein eigenständiges Developer-API | Interessant für Privacy-UX, nicht als Agent-Runtime |
| Xprivo / Ask Safely / Confer.to / Ellydee.ai | Technisch ungeklärt | Vor jeder Integration: API, Audit und Privacy prüfen |

## 7. Mistral AI — Kurzbewertung

Mistral ist für iGentic ein starker Tier-3-Kandidat mit klarer API, EU-Hosting als Standard und belastbaren Privacy-Controls. Wichtig ist die saubere Trennung zwischen API, Studio und Consumer-Produkten.

### Für iGentic relevant

- API-Daten werden laut Doku nicht für Training verwendet.
- ZDR ist nur im Scale-Plan und nur für stateless API-Calls verfügbar.
- ZDR gilt nicht für stateful Produkte wie Agents, Batch Files, Conversations, Libraries oder `/v1/files`.
- Für EU-Transfers verweist Mistral auf SCCs; zusätzliche Feature-Transfers können organisationsseitig begrenzt werden.
- Labs-Modelle können Trainingseinstellungen übersteuern und müssen im Adapter separat behandelt werden.

### Kurzfazit

Mistral ist als Cloud-Fallback gut geeignet, aber nur mit planabhängiger Prüfung von ZDR, Training-Opt-outs und Statefulness. Für diese Übersichtsdatei reicht die Kurzbewertung; Detailanalyse, Pricing-Details und Adapterfragen sollten in ein separates Research-Dokument ausgelagert werden.

## 8. iGentic-Eignung

**Tier-Einordnung:** Tier 3 (Cloud-Fallback). Die offen lizenzierten Modelle könnten bei Self-Hosting theoretisch Richtung Tier 1 rücken, wenn die Infrastruktur lokal betrieben wird.

**Passung zu Architekturkomponenten:**
- `PolicyEngine`: Geeignet als primärer Cloud-Fallback für als öffentlich/unkritisch klassifizierte Daten; EU-Jurisdiktion, DPA und Privacy Controls sprechen dafür.
- `ApprovalManager`: ZDR muss im Flow als explizite Voraussetzung für Tier-3-Eskalationen abgebildet werden.
- `AuditLog`: DPA, Trust Center und Audit-Log-Features liefern die passende Grundlage für Audit-Einträge.

**Risiken:**
1. Labs-Modelle können Training-Opt-outs übersteuern; das muss im Provider-Adapter sichtbar gemacht werden.
2. ZDR gilt nur für stateless API-Endpunkte und nicht für stateful Produkte.
3. Reranking ist hier nicht als eigener, zentraler Mistral-Endpoint verifiziert; falls iGentic Reranking für RAG braucht, sollte das separat gelöst werden.

## 9. Adapter-Design (Vorschlag)

```swift
protocol ModelProvider {
    func generate(request: ModelRequest) async throws -> ModelResponse
}

struct MistralProvider: ModelProvider {
    let apiKey: String
    let plan: MistralPlan // .free oder .scale
    let zeroDataRetention: Bool // nur auf .scale gültig; PolicyEngine muss das prüfen

    func generate(request: ModelRequest) async throws -> ModelResponse {
        // POST https://api.mistral.ai/v1/chat/completions
        // Normalisieren: response_format (JSON/Structured), tools[], stream,
        // parallel_tool_calls, model selection, audit metadata.
    }
}
```

**Zu normalisieren:**
- `tools`-Unterstützung und integrierte Werkzeuge getrennt von externen Tools behandeln.
- Plan-abhängige Features wie ZDR im Adapter prüfen und im `AuditLog` vermerken.
- Der `DelegationBroker` sollte entscheiden können, was lokal und was remote ausgeführt wird.

## 10. Gesamtbewertung

| Kriterium | Bewertung |
|---|---|
| Privacy | ★★★★☆ |
| API | ★★★★★ |
| Dokumentation | ★★★★★ |
| Stabilität | ★★★★☆ |
| Kosten | ★★★★☆ |
| Entwicklerfreundlichkeit | ★★★★★ |
| Zukunftssicherheit | ★★★★☆ |
| **Gesamteignung für iGentic** | **★★★★☆** |

**Fazit:** Mistral bleibt ein sehr starker Tier-3-Kandidat für iGentic: europäische Jurisdiktion, klare API, formale Datenschutz-Controls, Enterprise-Optionen und gute Entwicklerdokumentation. Die wichtigste Regel für iGentic ist die saubere Trennung von Free, Pro/Team und Scale, weil Training-Controls, ZDR und Statefulness dort unterschiedlich behandelt werden.

## Vollständige Quellenliste

**Primärquellen (Mistral AI offiziell):**
- https://docs.mistral.ai/
- https://docs.mistral.ai/api
- https://docs.mistral.ai/api/endpoint/chat
- https://docs.mistral.ai/studio-api/overview
- https://docs.mistral.ai/resources/known-limitations
- https://docs.mistral.ai/admin/monitor-comply/privacy-data-controls
- https://mistral.ai/pricing/
- https://legal.mistral.ai/terms/privacy-policy
- https://legal.mistral.ai/terms/data-processing-addendum
- https://trust.mistral.ai/
- https://help.mistral.ai/en/articles/347638-do-you-have-soc-2-or-iso-27001-certification
- https://help.mistral.ai/en/articles/347629-where-do-you-store-my-data-or-my-organization-s-data
- https://help.mistral.ai/en/articles/347612-can-i-activate-zero-data-retention-zdr
- https://help.mistral.ai/en/articles/455207-can-i-opt-out-of-my-input-or-output-data-being-used-for-training
- https://help.mistral.ai/en/articles/698531-why-am-i-hitting-api-rate-limits-and-how-do-i-increase-them
- https://help.mistral.ai/en/collections/789666-trust-security-compliance
- https://help.mistral.ai/en/collections/789670-regulatory-compliance-and-certification

**Drittquellen (nur zur Einordnung, wenn nötig):**
- https://meetily.ai/llm-privacy/mistral
- https://anarlog.so/blog/mistral-api-key/
- https://freellm.net/providers/mistral-ai
- https://pricepertoken.com/endpoints/mistral/free
- https://pricepertoken.com/pricing-page/provider/mistral-ai
- https://www.cloudzero.com/blog/mistral-api-pricing/
- https://www.aipricing.guru/mistral-ai-pricing/
- https://tickerr.ai/pricing/mistral
- https://tickerr.ai/limits/mistral
- https://comparedge.com/tools/mistral-ai/pricing
- https://www.grizzlypeaksoftware.com/articles/p/mistral-ai-pricing-in-2026-pro-costs-free-tier-limits-and-api-rates-lx4o2n2v
- https://apidog.com/blog/mistra-ai-api/
- https://www.promptfoo.dev/docs/providers/mistral/
- https://deviniti.com/services/mistral-ai-integration-services