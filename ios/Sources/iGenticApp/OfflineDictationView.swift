#if os(iOS) && canImport(AVFoundation) && canImport(Speech) && canImport(SwiftUI)
import AVFoundation
import Combine
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
    // Deactivate the shared app audio session only when our own capture
    // actually activated it. Visiting a screen must not disturb other audio.
    private var audioSessionActivated = false
    private var previousAudioConfiguration: (
        category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    )?

    func start() async {
        guard !recording, !starting, !Task.isCancelled,
              UIApplication.shared.applicationState == .active else { return }
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
        guard OfflineDictationGate.mayActivateCapture(
            isCurrentAttempt: generation == id,
            cancelled: Task.isCancelled,
            foregroundActive: UIApplication.shared.applicationState == .active
        ) else { return }
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
            let previous = (
                category: session.category,
                mode: session.mode,
                options: session.categoryOptions
            )
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            previousAudioConfiguration = previous
            try session.setActive(true)
            audioSessionActivated = true
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
        guard OfflineDictationGate.requiresStop(
            recording: recording,
            starting: starting,
            hasEngine: engine != nil,
            hasRecognitionTask: recognitionTask != nil,
            hasRequest: speechRequest != nil,
            ownsAudioSession: audioSessionActivated
        ) else { return }
        stop()
        status = "Aufnahme bei Unterbrechung der App beendet."
    }

    func stop() {
        // A view dismissal, idle stop button or SwiftUI navigation can occur
        // without our microphone ever having been started.
        guard OfflineDictationGate.requiresStop(
            recording: recording,
            starting: starting,
            hasEngine: engine != nil,
            hasRecognitionTask: recognitionTask != nil,
            hasRequest: speechRequest != nil,
            ownsAudioSession: audioSessionActivated
        ) else { return }
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
        // The pending authorization continuation still owns the startup slot.
        // Only start()'s defer releases it; never allow overlapping prompts.
        let session = AVAudioSession.sharedInstance()
        if audioSessionActivated {
            audioSessionActivated = false
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
        }
        // AVAudioSession category is app-global and remains .record even
        // after deactivation. Restore the former configuration so the
        // adjacent native text-to-speech and other audio are not broken.
        // Do not overwrite configuration replaced by another component.
        if let previous = previousAudioConfiguration,
           session.category == .record, session.mode == .measurement {
            try? session.setCategory(
                previous.category, mode: previous.mode, options: previous.options
            )
        }
        previousAudioConfiguration = nil
        status = transcript.isEmpty ? "Aufnahme beendet – kein Text erkannt." : "Aufnahme beendet. Text kann kopiert werden."
    }

    func leaveView() {
        stop()
        transcript = ""
    }

    private enum OfflineDictationError: Error {
        case audioFormatUnavailable
    }
}

public struct OfflineDictationView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var dictation = OfflineDictationController()
    @State private var startupTask: Task<Void, Never>?
    public init() {}

    public var body: some View {
        Form {
            Section("Lokale Spracheingabe") {
                Text(dictation.status)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("igentic-dictation-status")

                HStack {
                    Button(dictation.starting ? "Wird gestartet …" : "Aufnahme starten") {
                        guard scenePhase == .active, startupTask == nil else { return }
                        startupTask = Task { @MainActor in
                            defer { startupTask = nil }
                            await dictation.start()
                        }
                    }
                    .disabled(startupTask != nil || dictation.starting || dictation.recording || scenePhase != .active)
                    .accessibilityIdentifier("igentic-dictation-start")

                    Button("Stoppen") { startupTask?.cancel(); dictation.stop() }
                        .disabled(startupTask == nil && !dictation.recording && !dictation.starting)
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
                    UIPasteboard.general.setItems([["public.utf8-plain-text": dictation.transcript]],
                                                      options: [.localOnly: true])
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
        .onDisappear { startupTask?.cancel(); dictation.leaveView() }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .receive(on: RunLoop.main)) { notice in
            if let raw = notice.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
               AVAudioSession.InterruptionType(rawValue: raw) == .began {
                startupTask?.cancel()
                dictation.stopOnBackground()
            }
        }
        .onChange(of: scenePhase) { _, next in
            // Permission alerts can temporarily set .inactive; don't abort
            // a pending consent flow. But a recording must stop immediately
            // on inactivity (lock/Control Center), before backgrounding.
            if next == .background || (next == .inactive && dictation.recording) {
                startupTask?.cancel()
                dictation.stopOnBackground()
            }
        }
    }
}
#endif
