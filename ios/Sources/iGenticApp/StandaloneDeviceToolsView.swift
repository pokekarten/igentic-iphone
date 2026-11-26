#if os(iOS) && canImport(SwiftUI) && canImport(AVFoundation)
import SwiftUI
import UIKit

/// Local owner-facing control surface. A remote/model caller has no route to it.
struct StandaloneDeviceToolsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var report: String?
    @State private var confirmation = false
    @State private var run: Task<Void, Never>?
    @State private var outcome: StandaloneTorchOutcome?
    @State private var backend = NativeStandaloneDeviceBackend()

    var body: some View {
        Form {
            Section("iPhone lokal prüfen") {
                Button("Status, Speicher und Taschenlampe lesen") {
                    report = StandaloneDeviceTools.readReport(backend: backend)
                }
                .disabled(run != nil || scenePhase != .active)
                .accessibilityIdentifier("igentic-device-tools-read")
                if let report { Text(report).accessibilityIdentifier("igentic-device-tools-report") }
                Text("Direkte iOS-Schnittstellen. Kein ChatGPT, Siri, Mac oder Sprachmodell notwendig.")
                    .font(.footnote)
            }
            Section("Native Geräteaktion") {
                Button("Taschenlampe kurz einschalten") { confirmation = true }
                    .disabled(run != nil || scenePhase != .active || outcome == .uncertain)
                    .accessibilityIdentifier("igentic-device-tools-pulse")
                if run != nil { Button("Abbrechen") { run?.cancel() } }
                if let outcome {
                    Text(message(outcome)).accessibilityIdentifier("igentic-device-tools-outcome")
                }
                Text("Nur wenn die Lampe zuvor aus ist; ca. drei Sekunden bei niedriger Intensität. Bei Abbruch wird das Ausschalten versucht. Keine Kameraaufnahme. Ein Prozessabbruch durch iOS kann nicht garantiert abgefangen werden.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Gerätesteuerung")
        .confirmationDialog("Taschenlampe für ca. drei Sekunden einschalten?",
                            isPresented: $confirmation, titleVisibility: .visible) {
            Button("Jetzt lokal ausführen") { start() }
            Button("Abbrechen", role: .cancel) {}
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { confirmation = false; run?.cancel() }
        }
        .onDisappear { confirmation = false; run?.cancel() }
    }

    private func start() {
        guard run == nil, scenePhase == .active, outcome != .uncertain else { return }
        outcome = nil
        run = Task { @MainActor in
            defer { run = nil }
            outcome = await StandaloneDeviceTools.pulse(backend: backend, ownerConfirmed: true,
                foreground: { scenePhase == .active && UIApplication.shared.applicationState == .active },
                wait: { try await Task.sleep(for: .seconds(3)) })
            report = StandaloneDeviceTools.readReport(backend: backend)
        }
    }

    private func message(_ outcome: StandaloneTorchOutcome) -> String {
        switch outcome {
        case .verified: "iOS meldete die Taschenlampe aktiv und anschließend aus."
        case .blocked: "Nicht gestartet. Zustand, Freigabe oder Gerätefunktion nicht verfügbar."
        case .cancelledAndOff: "Abgebrochen; iOS meldet die Taschenlampe aus."
        case .notObservedAndOff: "Aktivierung nicht beobachtet; iOS meldet die Taschenlampe aus."
        case .uncertain: "Zustand nicht sicher überprüft. Bitte Taschenlampe im Kontrollzentrum kontrollieren. Keine automatische Wiederholung."
        }
    }
}
#endif
