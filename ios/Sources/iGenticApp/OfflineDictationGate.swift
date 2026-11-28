/// Deterministic, cross-platform admission policy for native microphone input.
/// Neither a model, a Shortcut nor an MCP caller can override this gate.
public enum OfflineDictationGateDecision: String, Equatable, Sendable {
    case admitted
    case alreadyBusy
    case offlineRecognizerUnavailable
    case speechPermissionDenied
    case microphonePermissionDenied
}

public enum OfflineDictationGate {
    /// Avoid mutating the shared AVAudioSession when this dictation view has
    /// never owned a microphone session. A pending permission request must
    /// still be cancellable without activating an unrelated audio session.
    public static func requiresStop(
        recording: Bool,
        starting: Bool,
        hasEngine: Bool,
        hasRecognitionTask: Bool,
        hasRequest: Bool,
        ownsAudioSession: Bool
    ) -> Bool {
        recording || starting || hasEngine || hasRecognitionTask || hasRequest || ownsAudioSession
    }

    /// Check again after async system consent; an obsolete permission result
    /// must not activate a microphone in an inactive application.
    public static func mayActivateCapture(
        isCurrentAttempt: Bool,
        cancelled: Bool,
        foregroundActive: Bool
    ) -> Bool {
        isCurrentAttempt && !cancelled && foregroundActive
    }

    public static func decide(
        supportsOnDevice: Bool,
        recognizerAvailable: Bool,
        speechAuthorized: Bool,
        microphoneAuthorized: Bool,
        busy: Bool
    ) -> OfflineDictationGateDecision {
        if busy { return .alreadyBusy }
        if !supportsOnDevice || !recognizerAvailable { return .offlineRecognizerUnavailable }
        if !speechAuthorized { return .speechPermissionDenied }
        if !microphoneAuthorized { return .microphonePermissionDenied }
        return .admitted
    }
}
