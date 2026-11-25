#if os(iOS) && canImport(SwiftUI) && canImport(PhotosUI) && canImport(Vision) && canImport(FoundationModels)
import SwiftUI
import PhotosUI

public struct AgentLoopDocumentView: View {
    @State private var selection: PhotosPickerItem?
    @State private var job: Task<Void, Never>?
    @State private var result: AgentLoopDocumentResult?
    @State private var generation = UUID()
    @Environment(\.scenePhase) private var scenePhase

    public init() {}
    public var body: some View {
        Form {
            Section("Lokaler Dokumenten-Agent") {
                Text("Wähle ein Bild und starte den Agenten. Er erkennt Text, lässt die lokale KI wichtige Zeilen auswählen und übernimmt ausschließlich unveränderte OCR-Quellzeilen. Prüfe diese am Original. Keine Speicherung oder Cloud-Übertragung durch iGentic; iOS kann das gewählte Bild aus deiner Fotomediathek nachladen.")
                PhotosPicker(selection: $selection, matching: .images) {
                    Label("Bild auswählen", systemImage: "doc.viewfinder")
                }.disabled(job != nil)
                Button("Dokument lokal auswerten") { start() }
                    .disabled(selection == nil || job != nil)
                    .accessibilityIdentifier("igentic-document-agent-start")
                if job != nil {
                    ProgressView("OCR und lokale KI laufen")
                    Button("Abbrechen") { stop() }
                }
            }
            if let result {
                Section("Ergebnis") {
                    Text(result.outcome == .completed ? "Quellzeilen aus \(result.sourceLineCount) erkannten Zeilen" : "Gestoppt: \(result.outcome.rawValue)")
                    ForEach(Array(result.excerpts.enumerated()), id: \.offset) { _, excerpt in
                        Text(excerpt).textSelection(.enabled)
                    }
                    Text("Die Auswahl ist keine vollständige Zusammenfassung; OCR und Relevanz können fehlerhaft sein.").font(.caption)
                }
            }
        }
        .navigationTitle("Dokumenten-Agent")
        .onChange(of: selection) { _, _ in stop(); result = nil }
        .onChange(of: scenePhase) { _, phase in if phase != .active { stop(); result = nil } }
        .onDisappear { stop(); result = nil }
    }
    private func stop() {
        generation = UUID()
        job?.cancel()
        job = nil
    }
    private func start() {
        guard job == nil, let item = selection else { return }
        result = nil
        let token = UUID()
        generation = token
        job = Task { @MainActor in
            let outcome: AgentLoopDocumentResult
            if let data = try? await item.loadTransferable(type: Data.self) {
                if Task.isCancelled || generation != token { return }
                outcome = await AgentLoopDocumentWorkflow.runOnDevice(image: data)
            } else {
                outcome = .init(outcome: .inputRejected, sourceLineCount: 0, excerpts: [])
            }
            guard !Task.isCancelled, generation == token else { return }
            result = outcome
            job = nil
        }
    }
}
#endif
