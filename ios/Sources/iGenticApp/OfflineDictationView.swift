#if os(iOS) && canImport(AVFoundation) && canImport(Speech) && canImport(SwiftUI)
import AVFoundation
import Speech
import SwiftUI
import UIKit

/// Deliberately restricted to one user-started, device-local German dictation.
/// No background task, audio file, network API, model gateway or auto-dispatch.
@MainActor
private final class OfflineDictationController: ObservableObject {
    @Published private(set) var transcript = ""
    @Published private(set) var status = "Bereit für lokale deutsche Spracheingabe."
    @Published private(set) var recording = false
    @Published private(set) var starting = false

    private var engine: AVAudioEngine?
    private var speechRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var timeoutTask: Task<Void, Never>?
    private var generation = UUID()

    func start() async {
        guard !recording, !starting else { return }
        starting = true
        let id = UUID()
        generation = id
        defer { starting = false }

        // This guard MUST precede microphone authorization. Never let the
        // Speech framework use a network recognizer as a "helpful" fallback.
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE")),
              recognizer.supportsOnDeviceRecognition, recognizer.isAvailable else {
            status = "Deutsche Offline-Spracherkennung auf diesem Gerät derzeit nicht verfügbar."
            return
        }

        let permission = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { value in
                continuation.resume(returning: value)
            }
        }
        guard generation == id, !Task.isCancelled else { return }
        guard permission == .authorized else {
            status = "Spracherkennung nicht freigegeben."
            return
        }

        let microphoneAllowed = await AVAudioApplication.requestRecordPermission()
        guard generation == id, !Task.isCancelled else { return }
        guard microphoneAllowed else {
            status = "Mikrofon nicht freigegeben."
            return
        }
        // Even after permission prompts, read the live support flags again.
        // The deterministic policy never treats a permitted *network* model
        // as an acceptable fallback for the native offline microphone.
        let admission = OfflineDictationGate.decide(
            supportsOnDevice: recognizer.supportsOnDeviceRecognition,
            recognizerAvailable: recognizer.isAvailable,
            speechAuthorized: permission == .authorized,
            microphoneAuthorized: microphoneAllowed,
            busy: recording
        )
        guard admission == .admitted else {
            status = "Offline-Spracherkennung inzwischen nicht verfügbar."
            return
        }

        let session = AVAudioSession.sharedInstance()
        let newEngine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        transcript = ""
        status = "Mikrofon wird gestartet."
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true)
            let input = newEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                throw OfflineDictationError.audioFormatUnavailable
            }

            // Capture only to memory, never write an audio recording.
            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let words = result?.bestTranscription.formattedString ?? ""
                let isFinal = result?.isFinal ?? false
                let failed = error != nil
                Task { @MainActor [weak self] in
                    self?.receive(words: words, isFinal: isFinal, failed: failed, for: id)
                }
            }
            speechRequest = request
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }
            engine = newEngine
            try newEngine.start()
            guard generation == id else {
                stop()
                return
            }
            recording = true
            status = "Lokale Aufnahme läuft – maximal 30 Sekunden."
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { return }
                self?.stop()
            }
        } catch {
            stop()
            status = "Lokale Aufnahme nicht gestartet. Bitte Mikrofon und Offline-Sprachpaket prüfen."
        }
    }

    private func receive(words: String, isFinal: Bool, failed: Bool, for id: UUID) {
        guard id == generation, recording else { return }
        transcript = String(words.prefix(3_000))
        if failed || isFinal {
            stop()
            status = failed ? "Spracherkennung beendet oder fehlgeschlagen." : "Lokale Transkription abgeschlossen."
        }
    }

    /// Scene backgrounding does not necessarily remove a navigation view.
    /// Stop the microphone even if the view is still retained in the stack.
    /// Do not deactivate an unrelated idle audio session.
    func stopOnBackground() {
        guard recording || starting || engine != nil || recognitionTask != nil else {
            return
        }
        stop()
        status = "Aufnahme beim Wechsel in den Hintergrund beendet."
    }

    func stop() {
        // Invalidate late recognition callbacks, including post-stop final text.
        generation = UUID()
        timeoutTask?.cancel()
        timeoutTask = nil
        if let engine {
            if engine.isRunning { engine.stop() }
            engine.inputNode.removeTap(onBus: 0)
        }
        speechRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        speechRequest = nil
        engine = nil
        recording = false
        starting = false
        try? AVAudioSession.sharedInstance().setActive(
            false, options: .notifyOthersOnDeactivation
        )
        status = transcript.isEmpty ? "Aufnahme beendet – kein Text erkannt." : "Aufnahme beendet. Text kann kopiert werden."
    }

    private enum OfflineDictationError: Error {
        case audioFormatUnavailable
    }
}

public struct OfflineDictationView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var dictation = OfflineDictationController()
    public init() {}

    public var body: some View {
        Form {
            Section("Lokale Spracheingabe") {
                Text(dictation.status)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("igentic-dictation-status")

                HStack {
                    Button(dictation.starting ? "Wird gestartet …" : "Aufnahme starten") {
                        Task { await dictation.start() }
                    }
                    .disabled(dictation.starting || dictation.recording)
                    .accessibilityIdentifier("igentic-dictation-start")

                    Button("Stoppen") { dictation.stop() }
                        .disabled(!dictation.recording && !dictation.starting)
                        .accessibilityIdentifier("igentic-dictation-stop")
                }
                ScrollView {
                    Text(dictation.transcript.isEmpty ? "Noch kein Text erkannt." : dictation.transcript)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(minHeight: 110)
                .accessibilityIdentifier("igentic-dictation-result")
                Button("Text kopieren") {
                    UIPasteboard.general.string = dictation.transcript
                }
                .disabled(dictation.transcript.isEmpty)
                .accessibilityIdentifier("igentic-dictation-copy")
            }
            Section("Datenschutz und Grenzen") {
                Text("Nur nach Tippen wird das Mikrofon verwendet. Erkennung ist auf Deutsch (de-DE) und auf das Gerät beschränkt; keine Cloud-Ausweichroute. Wenn kein Offline-Sprachpaket verfügbar ist, bleibt die Aufnahme aus.")
                Text("Die Aufnahme endet nach spätestens 30 Sekunden oder beim Verlassen der Ansicht. Audio wird nicht als Datei gespeichert. Der Text bleibt bis zum Verlassen der Ansicht im Arbeitsspeicher; Kopieren ist eine bewusste Aktion.")
            }
            .font(.footnote)
        }
        .navigationTitle("Sprache offline")
        .onDisappear { dictation.stop() }
        .onChange(of: scenePhase) { _, next in
            // A permission alert can temporarily set .inactive; only a
            // genuine background transition should cancel that consent flow.
            if next == .background { dictation.stopOnBackground() }
        }
    }
}
#endif
