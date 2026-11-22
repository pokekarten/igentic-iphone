import AgentCore
import Foundation

/// Explicitly opt-in local-model acceptance probe. The only model input
/// is a committed synthetic demo phrase. The generated text is neither
/// logged nor returned; only the AgentCore gate's decision is printed.
@main
struct AppleOnDeviceProposalProbe {
    static func main() async {
        let environment = ProcessInfo.processInfo.environment
        let runReminderDraft = environment["IGENTIC_RUN_LOCAL_REMINDER_DRAFT_PROBE"] == "1"
        guard environment["IGENTIC_RUN_LOCAL_MODEL_PROBE"] == "1" || runReminderDraft else {
            print("LOCAL_MODEL_PROBE=skipped (explicit opt-in required)")
            return
        }

        if runReminderDraft {
            await runSyntheticReminderDraftProbe()
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

    private static func runSyntheticReminderDraftProbe() async {
        let probeCase = ProcessInfo.processInfo.environment["IGENTIC_LOCAL_REMINDER_PROBE_CASE"] ?? "supported"
        let instruction: String
        switch probeCase {
        case "supported":
            instruction = "Erinnere mich morgen um 18 Uhr daran, die Demo-Pflanze zu gießen."
        case "ambiguous":
            instruction = "Erinnere mich irgendwann an die Demo-Pflanze."
        case "unsupported":
            instruction = "Ändere mein Hintergrundbild auf blau."
        default:
            print("LOCAL_REMINDER_DRAFT_PROBE=invalidFixture")
            return
        }

        let result = await ReminderDraftProposalService().propose(
            instruction: instruction,
            trustedDataClassification: DataClassification(
                level: .contextualPrivateData,
                reason: "Fixed synthetic local-probe instruction."
            ),
            timeZoneIdentifier: "Europe/Berlin"
        )

        switch result {
        case .proposed(let proposal):
            guard probeCase == "supported" else {
                print("LOCAL_REMINDER_DRAFT_PROBE=unexpectedProposal")
                print("LOCAL_REMINDER_DRAFT_ABSTAINED=false")
                print("LOCAL_REMINDER_DRAFT_WRITE_ATTEMPTED=false")
                return
            }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .gmt
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            let parts = calendar.dateComponents([.year, .month, .day], from: tomorrow)
            let expectedDue = try? ReminderDueDate.resolve(
                year: parts.year ?? 0,
                month: parts.month ?? 0,
                day: parts.day ?? 0,
                hour: 18,
                minute: 0,
                timeZoneIdentifier: "Europe/Berlin"
            )
            let tokens = Set(proposal.title.value.lowercased().split { !$0.isLetter }.map(String.init))
            let hasDemoQualifier = tokens.contains("demo")
            let hasPlant = tokens.contains("pflanze")
            let hasWateringAction = tokens.contains("gießen") || tokens.contains("wässern")
            let titleMatch = hasDemoQualifier && hasPlant && hasWateringAction
            let dueMatch = expectedDue.map { proposal.due == $0 } ?? false
            print("LOCAL_REMINDER_DRAFT_PROBE=proposalCreated")
            print("LOCAL_REMINDER_DRAFT_TITLE_HAS_DEMO=\(hasDemoQualifier)")
            print("LOCAL_REMINDER_DRAFT_TITLE_HAS_PLANT=\(hasPlant)")
            print("LOCAL_REMINDER_DRAFT_TITLE_HAS_ACTION=\(hasWateringAction)")
            print("LOCAL_REMINDER_DRAFT_TITLE_MATCH=\(titleMatch)")
            print("LOCAL_REMINDER_DRAFT_DUE_MATCH=\(dueMatch)")
            print("LOCAL_REMINDER_DRAFT_SEMANTIC_MATCH=\(titleMatch && dueMatch)")
            print("LOCAL_REMINDER_DRAFT_WRITE_ATTEMPTED=false")
        case .inputRejected:
            print("LOCAL_REMINDER_DRAFT_PROBE=inputRejected")
        case .modelUnavailable:
            print("LOCAL_REMINDER_DRAFT_PROBE=modelUnavailable")
        case .generationFailed:
            print("LOCAL_REMINDER_DRAFT_PROBE=generationFailed")
        case .unsupportedAction:
            print("LOCAL_REMINDER_DRAFT_PROBE=unsupportedAction")
            print("LOCAL_REMINDER_DRAFT_ABSTAINED=\(probeCase != "supported")")
            print("LOCAL_REMINDER_DRAFT_WRITE_ATTEMPTED=false")
        case .invalidProposal:
            print("LOCAL_REMINDER_DRAFT_PROBE=invalidProposal")
            print("LOCAL_REMINDER_DRAFT_ABSTAINED=\(probeCase != "supported")")
            print("LOCAL_REMINDER_DRAFT_WRITE_ATTEMPTED=false")
        }
    }
}
