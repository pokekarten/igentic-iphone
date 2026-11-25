import Foundation
import AgentCore
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Fixed owner-selected goal, model-directed sequence, deterministic execution.
/// No provider, external tool, persistence, arbitrary command or write authority.
public enum AgentLoopDiagnosticStep: String, Sendable, Equatable {
    case readStatus = "status.read"
    case checkModel = "model.readiness"
    case finish
}

public struct AgentLoopDiagnosticProgress: Sendable, Equatable {
    public let completed: [AgentLoopDiagnosticStep]
    public let statusAvailable: Bool
    public let localModelAvailable: Bool?
}

public struct AgentLoopDiagnosticReport: Sendable, Equatable {
    public enum Outcome: String, Sendable {
        case completed, modelUnavailable, rejectedProposal, failed, cancelled, expired
    }
    public let outcome: Outcome
    public let steps: [AgentLoopDiagnosticStep]
    public let modelTurns: Int
    /// Local UI only. Never send this report to a provider or console.
    public let localReport: String?
}

@MainActor
public enum AgentLoopLocalDiagnosticWorkflow {
    /// A task-scoped model adapter can propose only a string; native code
    /// independently enforces the goal, sequence, budget and policy.
    static func run(
        propose: @MainActor (AgentLoopDiagnosticProgress) async throws -> String,
        readStatus: @MainActor () -> AgentLoopLocalStatus,
        checkModel: @MainActor () -> Bool,
        elapsed: @MainActor () -> TimeInterval
    ) async -> AgentLoopDiagnosticReport {
        var steps: [AgentLoopDiagnosticStep] = []
        var turns = 0
        var status: AgentLoopLocalStatus?
        var readiness: Bool?
        func receipt(_ outcome: AgentLoopDiagnosticReport.Outcome, _ report: String? = nil) -> AgentLoopDiagnosticReport {
            .init(outcome: outcome, steps: steps, modelTurns: turns, localReport: report)
        }
        func currentFailure() -> AgentLoopDiagnosticReport.Outcome? {
            if Task.isCancelled { return .cancelled }
            let age = elapsed()
            return age.isFinite && age >= 0 && age < 60 ? nil : .expired
        }
        for _ in 0..<3 {
            if let failure = currentFailure() { return receipt(failure) }
            let policy = PolicyEngine().decide(PolicyRequest(
                privacyMode: .localOnly,
                dataClassification: .init(level: .contextualPrivateData, reason: "Owner-selected local diagnostic workflow."),
                actionRisk: .read, requestedDelegationTarget: .localDevice))
            guard policy.isAllowed && !policy.requiresApproval else { return receipt(.failed) }
            turns += 1
            let raw: String
            do {
                raw = try await propose(.init(completed: steps, statusAvailable: status != nil,
                                              localModelAvailable: readiness))
            } catch {
                return receipt(Task.isCancelled ? .cancelled : .failed)
            }
            if let failure = currentFailure() { return receipt(failure) }
            guard let step = AgentLoopDiagnosticStep(rawValue: raw), !steps.contains(step) else {
                return receipt(.rejectedProposal)
            }
            switch step {
            case .readStatus:
                status = readStatus()
            case .checkModel:
                readiness = checkModel()
            case .finish:
                guard let status, let readiness else { return receipt(.rejectedProposal) }
                if let failure = currentFailure() { return receipt(failure) }
                steps.append(step)
                let text = status.shortcutSummary + "\nLokale KI: " +
                    (readiness ? "bereit" : "nicht bereit") +
                    ". Bericht aus zwei lokal geprüften Werkzeugergebnissen."
                return receipt(.completed,text)
            }
            if let failure = currentFailure() { return receipt(failure) }
            steps.append(step)
        }
        return receipt(.rejectedProposal)
    }

    #if os(iOS) && canImport(UIKit)
    /// Native UI/explicit debug test entry, with the actual Apple system model.
    /// No fallback to a hosted provider and no model-controlled tool callbacks.
    public static func runOnDevice() async -> AgentLoopDiagnosticReport {
        let runtime = AppleFoundationModelsRuntime()
        guard runtime.assess(.init(capability: .structuredProposal, dataSensitivity: .publicData,
                                  allowedExecutionKinds: [.system])).isAccepted else {
            return .init(outcome: .modelUnavailable, steps: [], modelTurns: 0, localReport: nil)
        }
        let start = ContinuousClock.now
        return await run(propose: { progress in
            #if canImport(FoundationModels)
            let session = LanguageModelSession(model: SystemLanguageModel.default, tools: [],
                instructions: """
                You are the planner for one fixed local diagnostic report. Select one next action.
                Read device status and check local AI readiness, in either order, exactly once each.
                After both observations have been obtained, select finish. Never repeat an action.
                The native app independently validates and executes the allowed local reads.
                """)
            let completed = progress.completed.map(\.rawValue).joined(separator: ", ")
            let response = try await session.respond(
                to: "Completed: \(completed.isEmpty ? "none" : completed). Status obtained: \(progress.statusAvailable). Local AI readiness: \(progress.localModelAvailable.map(String.init) ?? "not yet checked"). Select the next action.",
                generating: iGenticDiagnosticStepCandidate.self)
            return response.content.action
            #else
            throw CancellationError()
            #endif
        }, readStatus: { AgentLoopDeviceStatusReader.read() },
        checkModel: { runtime.availability == .available },
        elapsed: {
            let d = start.duration(to: .now).components
            return Double(d.seconds) + Double(d.attoseconds) / 1e18
        })
    }
    #endif
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct iGenticDiagnosticStepCandidate {
    @Guide(description: "Next action, not an execution result.", .anyOf(["status.read","model.readiness","finish"]))
    var action: String
}
#endif
