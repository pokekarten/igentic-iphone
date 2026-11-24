#if os(iOS) && canImport(SwiftUI)
import SwiftUI

/// The sole iPhone-side review UI for a result returned through Shortcuts.
/// Model text is displayed as untrusted data and never dispatched as a command.
public struct AgentLoopInboxView: View {
    @State private var exchange: AgentLoopExchange?
    @State private var errorMessage: String?
    @State private var confirmingClear = false
    private let store = AgentLoopShortcutExchangeStore()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Label("KI-Loop – lokale Rückgabe", systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)
                Text("Die Modellantwort bleibt in iGentic, bis du sie prüfst oder löschst. Es wird kein iPhone-Befehl automatisch ausgeführt.")
                    .font(.subheadline).foregroundStyle(.secondary)

                if let exchange {
                    Text("Dein Auftrag").font(.headline)
                    Text(exchange.task)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("igentic-loop-task")
                    if let answer = exchange.answer {
                        Text("KI-Antwort – noch nicht freigegeben").font(.headline)
                        Text(answer)
                            .textSelection(.enabled)
                            .accessibilityIdentifier("igentic-loop-received-answer")
                        Label("Nur Textvorschlag, kein Befehl und keine Freigabe",
                              systemImage: "lock.shield")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Label("Warte auf die Rückgabe durch Kurzbefehle",
                              systemImage: "clock")
                            .accessibilityIdentifier("igentic-loop-awaiting-answer")
                        Text("Starte den auf deinem iPhone eingerichteten Kurzbefehl „iGentic KI Loop“. Er nutzt bei Bedarf die ChatGPT-Erweiterung und übergibt das Ergebnis wieder an iGentic.")
                            .font(.footnote)
                    }
                    Button("Auftrag und Antwort löschen", role: .destructive) {
                        confirmingClear = true
                    }
                    .accessibilityIdentifier("igentic-loop-clear")
                } else {
                    Label("Kein offener KI-Auftrag", systemImage: "tray")
                        .accessibilityIdentifier("igentic-loop-empty")
                }

                if let errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(.red)
                }
                Button("Status aktualisieren") { refresh() }
                    .accessibilityIdentifier("igentic-loop-refresh")
            }
            .padding()
        }
        .navigationTitle("KI-Antwort prüfen")
        .onAppear { refresh() }
        .confirmationDialog(
            "Auftrag und Antwort endgültig lokal löschen?",
            isPresented: $confirmingClear
        ) {
            Button("Löschen", role: .destructive) {
                do { try store.clear(); refresh() }
                catch { errorMessage = "Löschen fehlgeschlagen. Bitte erneut versuchen." }
            }
        }
    }

    private func refresh() {
        do { exchange = try store.snapshot(); errorMessage = nil }
        catch {
            exchange = nil
            errorMessage = "Lokale KI-Antwort nicht lesbar. Es wurde nichts ausgeführt."
        }
    }
}
#endif
