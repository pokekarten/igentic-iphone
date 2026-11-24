#if os(iOS) && canImport(SwiftUI) && canImport(CryptoKit)
import SwiftUI

/// This screen is constructed only by native app code after securely receiving
/// and verifying a task. It is NOT reachable via model text, MCP or App Intents.
@available(iOS 27.0, *)
@MainActor
public struct AgentLoopSignedOwnerReviewView: View {
    private let gate: AgentLoopSignedOwnerStatusGate
    @State private var refreshCounter = 0

    public init(gate: AgentLoopSignedOwnerStatusGate) {
        self.gate = gate
    }

    public var body: some View {
        // Refresh only the visible owner review while it is on screen. A
        // cached SwiftUI @State receipt must not continue displaying a
        // coarse observation after the signed task's 60-second deadline.
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let receipt = gate.snapshot()
            ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Label("Signierte Statusanfrage", systemImage: "checkmark.shield")
                    .font(.title3.bold())
                Text("Die Signatur kennzeichnet einen Relay-Schlüssel, nicht ein verifiziertes iPhone oder deine Einwilligung.")
                    .font(.subheadline)

                if let id = receipt.requestID {
                    Text("Auftrags-ID")
                        .font(.headline)
                    Text(id)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                        .accessibilityIdentifier("signed-status-request-id")
                }
                Text("Angefragte Funktion: ausschließlich Akku, Stromsparmodus und iOS-Version aus der eigenen iGentic-App.")
                Text("Es findet keine automatische Datenweitergabe an ChatGPT oder das Plugin statt. Der Button liest nur lokal; eine gesonderte externe Freigabe existiert hier nicht.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    _ = gate.readAfterLocalReviewAction()
                    refreshCounter &+= 1
                } label: {
                    Label("Einmalig nur lokal lesen", systemImage: "iphone.gen3")
                }
                .disabled(receipt.stage != .awaitingOwnerReview)
                .accessibilityIdentifier("signed-status-owner-local-read")

                Text("Lokaler Zustand: \(receipt.stage.rawValue)")
                    .font(.caption.monospaced())
                    .accessibilityIdentifier("signed-status-local-stage")

                if let observation = receipt.ownerAppObservation,
                   receipt.stage == .locallyRead {
                    Text(observation)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("signed-status-local-observation")
                }

                Text("Kein fern ausgeführter Befehl. Keine unabhängige Gerätebestätigung.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
            .navigationTitle("Anfrage lokal prüfen")
            .id(refreshCounter)
        }
    }
}
#endif
