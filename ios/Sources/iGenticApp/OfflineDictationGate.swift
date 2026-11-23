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
