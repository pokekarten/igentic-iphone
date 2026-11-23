#if os(iOS) && canImport(SwiftUI) && canImport(PhotosUI) && canImport(Vision) && canImport(AVFoundation)
import AVFoundation
import PhotosUI
import SwiftUI
import UIKit
import Vision

/// User-controlled, on-device fallbacks. No network, agent, Mac, plugin,
/// model provider or persistent text store is required.
public struct OfflineToolsView: View {
    @State private var draft = ""
    @State private var recognizedText = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoGeneration = UUID()
    @State private var photoStatus = "Noch kein Bild ausgewählt."
    @State private var speech = AVSpeechSynthesizer()

    public init() {}

    public var body: some View {
        Form {
            Section("Lokaler Arbeitsbereich") {
                NavigationLink("Notizen lokal verwalten") {
                    LocalWorkspaceView()
                }
                .accessibilityIdentifier("igentic-local-workspace")
                Text("Textdateien nur im App-Sandbox speichern, mit Vorschau und ausdrücklicher Bestätigung.")
                    .font(.footnote)
            }

            Section("Text ohne KI-Dienst") {
                TextEditor(text: $draft)
                    .frame(minHeight: 110)
                    .accessibilityIdentifier("igentic-offline-text-editor")
                    .onChange(of: draft) { _, value in
                        if value.count > 3_000 { draft = String(value.prefix(3_000)) }
                    }
                HStack {
                    Button("Text kopieren") {
                        UIPasteboard.general.string = draft
                    }
                    .disabled(draft.isEmpty)
                    .accessibilityIdentifier("igentic-offline-copy")

                    Button("Vorlesen") {
                        speech.stopSpeaking(at: .immediate)
                        let utterance = AVSpeechUtterance(string: draft)
                        utterance.voice = AVSpeechSynthesisVoice(language: "de-DE")
                        speech.speak(utterance)
                    }
                    .disabled(draft.isEmpty)
                    .accessibilityIdentifier("igentic-offline-speak")

                    Button("Stopp") { speech.stopSpeaking(at: .immediate) }
                }
                Text("Entwurf und Sprachausgabe bleiben in der App. Kopieren ist eine bewusste Aktion.")
                    .font(.footnote)
            }

            Section("Bildtext ohne Cloud-Dienst") {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Eigenes Bild auswählen", systemImage: "photo")
                }
                .accessibilityIdentifier("igentic-offline-photo")
                Text(photoStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("igentic-offline-ocr-status")
                if !recognizedText.isEmpty {
                    TextEditor(text: $recognizedText)
                        .frame(minHeight: 100)
                        .accessibilityIdentifier("igentic-offline-ocr-result")
                    Button("Erkannten Text kopieren") {
                        UIPasteboard.general.string = recognizedText
                    }
                    .accessibilityIdentifier("igentic-offline-ocr-copy")
                }
                Text("Apple Vision verarbeitet nur das manuell gewählte Bild lokal. Bilder und Ergebnisse werden nicht gespeichert oder an das Plugin übertragen.")
                    .font(.footnote)
            }

            #if canImport(EventKit)
            Section("Erinnerung") {
                NavigationLink("Erinnerung manuell vorbereiten") {
                    CreateReminderTaskView()
                }
                Text("Eintrag erst nach Prüfung, Geräteberechtigung und ausdrücklicher Freigabe.")
                    .font(.footnote)
            }
            #endif
        }
        .navigationTitle("Offline-Werkzeuge")
        .onChange(of: selectedPhoto) { _, value in
            guard let value else { return }
            let generation = UUID()
            photoGeneration = generation
            recognizedText = ""
            photoStatus = "Bild wird auf dem Gerät ausgewertet."
            Task { await recognize(value, generation: generation) }
        }
        .onDisappear { speech.stopSpeaking(at: .immediate) }
    }

    @MainActor
    private func recognize(_ item: PhotosPickerItem, generation: UUID) async {
        do {
            guard let image = try await item.loadTransferable(type: Data.self),
                  !image.isEmpty, image.count <= 12_000_000 else {
                photoStatus = "Bild nicht lesbar oder größer als 12 MB."
                return
            }
            let text = try await Task.detached(priority: .userInitiated) {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = false
                try VNImageRequestHandler(data: image).perform([request])
                return request.results?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n") ?? ""
            }.value
            guard !Task.isCancelled, generation == photoGeneration else { return }
            recognizedText = String(text.prefix(3_000))
            photoStatus = recognizedText.isEmpty
                ? "Kein Text erkannt."
                : "Text lokal erkannt. Nur durch Kopieren wird er weitergegeben."
        } catch {
            guard generation == photoGeneration else { return }
            recognizedText = ""
            photoStatus = "Lokale Texterkennung fehlgeschlagen."
        }
    }
}
#endif
