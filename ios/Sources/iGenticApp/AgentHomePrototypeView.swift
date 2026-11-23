#if os(iOS) && canImport(SwiftUI)
import SwiftUI

/// An honest chat-shaped entry point for existing, owner-controlled tools.
/// No LLM calls, cross-app automation, background control or fake receipts.
public struct AgentHomePrototypeView: View {
    @State private var input = ""
    @State private var submitted = ""
    @State private var proposal: AgentHomeProposal?
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Lokal · Prototyp", systemImage: "iphone")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Was möchtest du auf deinem iPhone tun?")
                        .font(.title2).bold()
                    Text("Ein gemeinsamer Einstieg für unsere eigenen Werkzeuge. Vorschläge sind noch keine Ausführung.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    TextField("Zum Beispiel: Erinnere mich morgen an die Pflanze", text: $input, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("igentic-agent-prompt")
                    Button("Lokalen Vorschlag prüfen") {
                        let bounded = String(input.prefix(512))
                        submitted = bounded
                        proposal = AgentHomeCommandRouter.preview(bounded)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("igentic-agent-preview")
                    Text("Nur regelbasierte Vorschau. Kein Sprachmodell, kein Netzwerk, kein App Intent und keine Systemaktion werden durch diesen Knopf ausgeführt.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(14)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))

                if let proposal {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(submitted)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .accessibilityIdentifier("igentic-agent-user-message")
                        Text(proposal.title).font(.headline)
                        Text(proposal.explanation).font(.subheadline)
                        if proposal.canOpenOwnedScreen {
                            destinationLink(for: proposal.destination)
                        } else {
                            Label("Nicht ausgeführt", systemImage: "lock.shield")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityIdentifier("igentic-agent-proposal")
                }

                Text("Direkt öffnen").font(.headline)
                VStack(alignment: .leading, spacing: 12) {
                    NavigationLink("Offline-Werkzeuge") { OfflineToolsView() }
                    #if canImport(EventKit)
                    NavigationLink("Erinnerungsentwurf") { CreateReminderTaskView() }
                    #endif
                    NavigationLink("Entdecken") { ExploreView() }
                    Button("Diagnose") { dismiss() }
                }
                .buttonStyle(.bordered)
                Text("iGentic führt Aktionen ausschließlich über die bestehenden App- und Policy-Grenzen aus. Freigaben, Berechtigungen und Erfolgsnachweise bleiben an den jeweiligen Funktionen.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("iGentic Agent")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func destinationLink(for destination: AgentHomeDestination) -> some View {
        switch destination {
        case .offlineTools:
            NavigationLink("Werkzeug öffnen") { OfflineToolsView() }
        case .reminderDraft:
            #if canImport(EventKit)
            NavigationLink("Entwurf öffnen") { CreateReminderTaskView() }
            #else
            Text("Erinnerungen sind hier nicht verfügbar.")
            #endif
        case .discovery:
            NavigationLink("Entdecken öffnen") { ExploreView() }
        case .diagnostics:
            Button("Zur Diagnose") { dismiss() }
        case .unsupported:
            EmptyView()
        }
    }
}
#endif
