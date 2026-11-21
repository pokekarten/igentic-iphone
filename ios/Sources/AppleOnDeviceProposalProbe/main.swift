import AgentCore
import Foundation

/// Explicitly opt-in local-model acceptance probe. The only model input
/// is a committed synthetic demo phrase. The generated text is neither
/// logged nor returned; only the AgentCore gate's decision is printed.
@main
struct AppleOnDeviceProposalProbe {
    static func main() async {
        guard ProcessInfo.processInfo.environment["IGENTIC_RUN_LOCAL_MODEL_PROBE"] == "1" else {
            print("LOCAL_MODEL_PROBE=skipped (explicit opt-in required)")
            return
        }

        let result = await AppleOnDeviceProposalPreview().generateReview(
            for: "Make a synthetic reminder to water a demo plant.",
            trustedDataClassification: .publicDefault
        )

        switch result {
        case .reviewed(let review):
            // No action name, user data, generated model text or tool is printed.
            print("LOCAL_MODEL_PROBE=reviewed")
            print("LOCAL_MODEL_DISPOSITION=" + String(describing: review.disposition))
            print("LOCAL_MODEL_REASON=" + review.reason.rawValue)
        case .inputRejected:
            print("LOCAL_MODEL_PROBE=inputRejected")
        case .modelUnavailable:
            print("LOCAL_MODEL_PROBE=modelUnavailable")
        case .generationFailed:
            print("LOCAL_MODEL_PROBE=generationFailed")
        }
    }
}
