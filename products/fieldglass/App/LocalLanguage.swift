import SwiftUI
import Speech
import UniformTypeIdentifiers
import FoundationModels

struct LocalLanguage: View {
    @Binding var text: String
    @State private var importer = false
    @State private var message: String?
    @State private var generated: String?
    @State private var running = false
    @State private var revision = UUID()
    @State private var recognition: SFSpeechRecognitionTask?
    @State private var generation: Task<Void, Never>?
    @State private var audioAccess: URL?

    var body: some View {
        Section("Lokal bearbeiten") {
            Button("Deutsche Audiodatei transkribieren") { importer = true }.disabled(running)
            Button("Text zusammenfassen") { summarize() }
                .disabled(running || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if running { Button("Bearbeitung stoppen") { cancel(); message = "Bearbeitung gestoppt." } }
            if let message { Text(message).foregroundStyle(.secondary) }
            if let generated {
                Text(generated).textSelection(.enabled)
                Button("Als Entwurf übernehmen") { text = generated; self.generated = nil }
                ShareLink("Ergebnis teilen", item: generated)
            }
        }
        .fileImporter(isPresented: $importer, allowedContentTypes: [.audio]) { result in
            if case let .success(url) = result { transcribe(url) }
        }
        .onDisappear { cancel() }
    }

    private func cancel() {
        revision = UUID(); recognition?.cancel(); recognition = nil
        generation?.cancel(); generation = nil; running = false
        if let audioAccess { audioAccess.stopAccessingSecurityScopedResource(); self.audioAccess = nil }
    }

    private func summarize() {
        cancel(); generated = nil
        guard #available(iOS 26.0, *), case .available = SystemLanguageModel.default.availability else {
            message = "Das lokale Apple-Sprachmodell ist auf diesem Gerät derzeit nicht verfügbar."; return
        }
        let token = revision, input = text
        running = true; message = "Lokales Modell arbeitet …"
        generation = Task {
            do {
                let session = LanguageModelSession(instructions: "Fasse den eingegebenen Text kurz auf Deutsch zusammen. Gib nur den Entwurf zurück.")
                let output = try await session.respond(to: input)
                guard revision == token else { return }
                generated = output.content; message = "Zusammenfassung bereit."
            } catch {
                guard revision == token else { return }
                message = "Die lokale Zusammenfassung konnte nicht erstellt werden."
            }
            running = false
        }
    }

    private func transcribe(_ url: URL) {
        cancel(); generated = nil
        guard let engine = SFSpeechRecognizer(locale: Locale(identifier: "de-DE")),
              engine.supportsOnDeviceRecognition else {
            message = "Lokale deutsche Spracherkennung ist derzeit nicht verfügbar."; return
        }
        let token = revision
        running = true; message = "Spracherkennung vorbereiten …"
        Task { @MainActor in
            let permission = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
            }
            guard revision == token else { return }
            guard permission == .authorized else { running = false; message = "Zugriff auf Spracherkennung fehlt."; return }
            let access = url.startAccessingSecurityScopedResource()
            if access { audioAccess = url }
            do {
                guard let size = try url.resourceValues(forKeys:[.fileSizeKey]).fileSize, size <= 32*1024*1024 else {
                    throw CocoaError(.fileReadTooLarge)
                }
            } catch {
                cancel(); message = "Audiodatei nicht lesbar (maximal 32 MiB)."; return
            }
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = false
            message = "Audiodatei wird lokal gelesen …"
            recognition = engine.recognitionTask(with: request) { result,error in
                Task { @MainActor in
                    guard revision == token, error != nil || result?.isFinal == true else { return }
                    if let result, result.isFinal { generated = result.bestTranscription.formattedString; message = "Transkript bereit." }
                    else { message = "Lokale Spracherkennung fehlgeschlagen." }
                    cancel()
                }
            }
        }
    }
}
