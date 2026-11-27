import Foundation
import AgentCore
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Fixed owner-selected goal, model-directed sequence, deterministic execution.
/// No external provider, arbitrary command or system write authority.
public enum AgentLoopDiagnosticStep: String, Codable, Sendable, Equatable {
    case readStatus = "status.read"
    case checkModel = "model.readiness"
    case inspectCapabilities = "capabilities.read"
    case finish
}

/// Goal is selected by the local owner, not inferred from model output.
public enum AgentLoopDiagnosticGoal: String, Codable, Sendable, Equatable {
    case basic, extended
    var requiredReads: [AgentLoopDiagnosticStep] {
        self == .basic ? [.readStatus, .checkModel] : [.readStatus, .checkModel, .inspectCapabilities]
    }
}

/// Reuse AgentCore registry metadata; navigation capabilities are not
/// executable tools. Only these three native readers may be dispatched.
enum AgentLoopDiagnosticCatalog {
    private static let registry = ToolRegistry(tools: [
        .init(name: "status.read", requiredDataLevel: .contextualPrivateData,
              actionRisk: .read, description: "Read own-device coarse status locally."),
        .init(name: "model.readiness", requiredDataLevel: .publicData,
              actionRisk: .read, description: "Check availability of the system language model."),
        .init(name: "capabilities.read", requiredDataLevel: .publicData,
              actionRisk: .read, description: "Inspect bundled own-app navigation capability metadata.")
    ])
    static func definition(_ step: AgentLoopDiagnosticStep) -> ToolDefinition? {
        registry.tool(named: step.rawValue)
    }
}

public struct AgentLoopDiagnosticProgress: Sendable, Equatable {
    public let completed: [AgentLoopDiagnosticStep]
    public let statusAvailable: Bool
    public let localModelAvailable: Bool?
    public let capabilityCount: Int?
    public let remainingReads: [AgentLoopDiagnosticStep]
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

    /// A Shortcuts caller may forward its output elsewhere. Return only
    /// bounded execution metadata, never the local observation or model text.
    public var shortcutReceipt: String {
        "outcome=\(outcome.rawValue); modelTurns=\(modelTurns); steps=\(steps.map(\.rawValue).joined(separator: ",")); reportPrepared=\(localReport != nil)"
    }
}

@MainActor
public enum AgentLoopLocalDiagnosticWorkflow {
    /// A task-scoped model adapter can propose only a string; native code
    /// independently enforces the goal, sequence, budget and policy.
    static func run(
        goal: AgentLoopDiagnosticGoal = .basic,
        usesModel: Bool = true,
        propose: @MainActor (AgentLoopDiagnosticProgress) async throws -> String,
        readStatus: @MainActor () -> AgentLoopLocalStatus,
        checkModel: @MainActor () -> Bool,
        inspectCapabilities: @MainActor () -> Int = { AgentHomeCapabilityCatalog.navigationTools().count },
        elapsed: @MainActor () -> TimeInterval,
        checkpoint: @MainActor ([AgentLoopDiagnosticStep]) throws -> Void = { _ in }
    ) async -> AgentLoopDiagnosticReport {
        var steps: [AgentLoopDiagnosticStep] = []
        var turns = 0
        var status: AgentLoopLocalStatus?
        var readiness: Bool?
        var capabilityCount: Int?
        func receipt(_ outcome: AgentLoopDiagnosticReport.Outcome, _ report: String? = nil) -> AgentLoopDiagnosticReport {
            .init(outcome: outcome, steps: steps, modelTurns: turns, localReport: report)
        }
        // Admission deadline: a suspended model call can return after the budget.
        func currentFailure() -> AgentLoopDiagnosticReport.Outcome? {
            if Task.isCancelled { return .cancelled }
            let age = elapsed()
            return age.isFinite && age >= 0 && age < 60 ? nil : .expired
        }
        for _ in 0..<(goal.requiredReads.count + 1) {
            if let failure = currentFailure() { return receipt(failure) }
            let remaining = goal.requiredReads.filter { !steps.contains($0) }
            if usesModel { turns += 1 }
            let raw: String
            do {
                raw = try await propose(.init(completed: steps, statusAvailable: status != nil,
                                              localModelAvailable: readiness, capabilityCount: capabilityCount, remainingReads: remaining))
            } catch {
                return receipt(currentFailure() ?? .failed)
            }
            if let failure = currentFailure() { return receipt(failure) }
            guard let step = AgentLoopDiagnosticStep(rawValue: raw), !steps.contains(step) else {
                return receipt(.rejectedProposal)
            }
            if step != .finish {
                guard remaining.contains(step), let tool = AgentLoopDiagnosticCatalog.definition(step),
                      tool.actionRisk == .read else { return receipt(.rejectedProposal) }
                let policy = PolicyEngine().decide(PolicyRequest(
                    privacyMode: .localOnly,
                    dataClassification: .init(level: tool.requiredDataLevel, reason: "Owner-selected local diagnostic reader."),
                    actionRisk: tool.actionRisk, requestedDelegationTarget: .localDevice))
                guard policy.isAllowed && !policy.requiresApproval else { return receipt(.failed) }
            }
            switch step {
            case .readStatus:
                status = readStatus()
            case .checkModel:
                readiness = checkModel()
            case .inspectCapabilities:
                let count = inspectCapabilities()
                guard (0...128).contains(count) else { return receipt(.failed) }
                capabilityCount = count
            case .finish:
                guard remaining.isEmpty, let status, let readiness else { return receipt(.rejectedProposal) }
                if let failure = currentFailure() { return receipt(failure) }
                do { try checkpoint(steps + [step]) } catch { return receipt(.failed) }
                steps.append(step)
                var text = status.shortcutSummary + "\nLokale KI: " +
                    (readiness ? "bereit" : "nicht bereit") +
                    ". Bericht aus lokal geprüften Werkzeugergebnissen."
                if let capabilityCount { text += "\nEigene Navigationsmöglichkeiten: \(capabilityCount). Keine davon wurde geöffnet oder ausgeführt." }
                return receipt(.completed,text)
            }
            if let failure = currentFailure() { return receipt(failure) }
            do { try checkpoint(steps + [step]) } catch { return receipt(.failed) }
            steps.append(step)
        }
        return receipt(.rejectedProposal)
    }

    /// Local model adapter sees only the remaining action names, not device values,
    /// prompts from the owner, or the local report. No external provider is supplied.
    public struct LocalDecisionRequest: Sendable, Equatable {
        public let allowedActions: [String]
        public let completedActions: [String]
    }

    static func decisionRequest(_ progress: AgentLoopDiagnosticProgress) -> LocalDecisionRequest {
        .init(allowedActions: progress.remainingReads.isEmpty ? ["finish"] : progress.remainingReads.map(\.rawValue),
              completedActions: progress.completed.map(\.rawValue))
    }

    /// Explicit deterministic planner for the same bounded local report.
    /// No model call or implicit fallback after a failed model attempt.
    static func runDeterministic(
        goal: AgentLoopDiagnosticGoal,
        readStatus: @MainActor () -> AgentLoopLocalStatus,
        checkModel: @MainActor () -> Bool,
        inspectCapabilities: @MainActor () -> Int = { AgentHomeCapabilityCatalog.navigationTools().count },
        elapsed: @MainActor () -> TimeInterval,
        checkpoint: @MainActor ([AgentLoopDiagnosticStep]) throws -> Void = { _ in }
    ) async -> AgentLoopDiagnosticReport {
        await run(goal: goal, usesModel: false, propose: { progress in
            (progress.remainingReads.first ?? .finish).rawValue
        }, readStatus: readStatus, checkModel: checkModel,
        inspectCapabilities: inspectCapabilities, elapsed: elapsed, checkpoint: checkpoint)
    }

    /// Portable execution boundary for an explicitly selected in-process adapter.
    /// Only action names cross the planner boundary; the native workflow owns
    /// all observations, tool admission, deadlines, and checkpointing.
    static func runLocalAdapter(
        goal: AgentLoopDiagnosticGoal,
        propose: @MainActor (LocalDecisionRequest) async throws -> String,
        readStatus: @MainActor () -> AgentLoopLocalStatus,
        checkModel: @MainActor () -> Bool,
        inspectCapabilities: @MainActor () -> Int = { AgentHomeCapabilityCatalog.navigationTools().count },
        elapsed: @MainActor () -> TimeInterval,
        checkpoint: @MainActor ([AgentLoopDiagnosticStep]) throws -> Void = { _ in }
    ) async -> AgentLoopDiagnosticReport {
        await run(goal: goal, propose: { progress in
            try await propose(decisionRequest(progress))
        }, readStatus: readStatus, checkModel: checkModel,
        inspectCapabilities: inspectCapabilities, elapsed: elapsed, checkpoint: checkpoint)
    }

    #if os(iOS) && canImport(UIKit)
    /// Explicit local-only adapter entry. The app supplies trusted, in-process
    /// inference code. Model strings never grant tool authority or bypass the journal.
    public static func runJournaledLocalAdapter(
        goal: AgentLoopDiagnosticGoal = .extended,
        propose: @MainActor (LocalDecisionRequest) async throws -> String
    ) async throws -> AgentLoopDiagnosticReport {
        let runtime = AppleFoundationModelsRuntime()
        let start = ContinuousClock.now
        return try await AgentLoopDiagnosticJournal().run(goal: goal) { checkpoint in
            await runLocalAdapter(goal: goal, propose: propose,
                readStatus: { AgentLoopDeviceStatusReader.read() },
            checkModel: { runtime.availability == .available },
            elapsed: {
                let d = start.duration(to: .now).components
                return Double(d.seconds) + Double(d.attoseconds) / 1e18
            }, checkpoint: checkpoint)
        }
    }

    /// Local owner chooses this path before execution. Readiness is an
    /// observation only, never a prerequisite for native tools.
    public static func runDeterministicOnDevice(
        goal: AgentLoopDiagnosticGoal = .extended,
        checkpoint: @MainActor ([AgentLoopDiagnosticStep]) throws -> Void = { _ in }
    ) async -> AgentLoopDiagnosticReport {
        let start = ContinuousClock.now
        return await runDeterministic(goal: goal,
            readStatus: { AgentLoopDeviceStatusReader.read() },
            checkModel: { AppleFoundationModelsRuntime().availability == .available },
            elapsed: {
                let d = start.duration(to: .now).components
                return Double(d.seconds) + Double(d.attoseconds) / 1e18
            }, checkpoint: checkpoint)
    }

    /// Native Shortcut entry uses the same durable exclusion and recovery
    /// contract as the UI. Never consume queued tasks or restart interrupted runs.
    public static func runJournaledOnDevice(goal: AgentLoopDiagnosticGoal = .extended) async throws -> AgentLoopDiagnosticReport {
        try await AgentLoopDiagnosticJournal().run(goal: goal) { checkpoint in
            await runOnDevice(goal: goal, checkpoint: checkpoint)
        }
    }

    /// Native UI/explicit debug test entry, with the actual Apple system model.
    /// No fallback to a hosted provider and no model-controlled tool callbacks.
    public static func runOnDevice(goal: AgentLoopDiagnosticGoal = .basic,
                                   checkpoint: @MainActor ([AgentLoopDiagnosticStep]) throws -> Void = { _ in }) async -> AgentLoopDiagnosticReport {
        let runtime = AppleFoundationModelsRuntime()
        guard runtime.assess(.init(capability: .structuredProposal, dataSensitivity: .publicData,
                                  allowedExecutionKinds: [.system])).isAccepted else {
            return .init(outcome: .modelUnavailable, steps: [], modelTurns: 0, localReport: nil)
        }
        let start = ContinuousClock.now
        return await run(goal: goal, propose: { progress in
            #if canImport(FoundationModels)
            let session = LanguageModelSession(model: SystemLanguageModel.default, tools: [],
                instructions: """
                You are the planner for one fixed local diagnostic report. Select one next action.
                Read each remaining tool exactly once. Select finish only when no reads remain.
                Never repeat an action. The app independently validates and executes local reads.
                """)
            let remaining = progress.remainingReads
            let evidence = "Completed: \(progress.completed.map(\.rawValue).joined(separator: ",")); AI available: \(progress.localModelAvailable.map(String.init) ?? "unknown"); navigation capability count: \(progress.capabilityCount.map(String.init) ?? "unknown"). "
            // The actual schema changes with the remaining native menu.
            switch remaining {
            case [.readStatus, .checkModel, .inspectCapabilities]:
                return try await session.respond(to: evidence + "Choose first remaining tool.", generating: iGenticDiagnosticAllCandidate.self).content.action
            case [.readStatus, .checkModel]:
                return try await session.respond(to: evidence + "Choose a remaining read.", generating: iGenticDiagnosticStepCandidate.self).content.action
            case [.readStatus, .inspectCapabilities]:
                return try await session.respond(to: evidence + "Choose a remaining read.", generating: iGenticDiagnosticStatusCapabilitiesCandidate.self).content.action
            case [.checkModel, .inspectCapabilities]:
                return try await session.respond(to: evidence + "Choose a remaining read.", generating: iGenticDiagnosticReadinessCapabilitiesCandidate.self).content.action
            case [.readStatus]:
                return try await session.respond(to: evidence + "Read remaining device status.", generating: iGenticDiagnosticStatusCandidate.self).content.action
            case [.checkModel]:
                return try await session.respond(to: evidence + "Read remaining AI readiness.", generating: iGenticDiagnosticReadinessCandidate.self).content.action
            case [.inspectCapabilities]:
                return try await session.respond(to: evidence + "Read remaining bundled capability inventory.", generating: iGenticDiagnosticCapabilitiesCandidate.self).content.action
            case []:
                return try await session.respond(to: evidence + "All required reads complete. Select finish or abort.", generating: iGenticDiagnosticFinishCandidate.self).content.action
            default: return "abort"
            }
            #else
            throw CancellationError()
            #endif
        }, readStatus: { AgentLoopDeviceStatusReader.read() },
        checkModel: { runtime.availability == .available },
        elapsed: {
            let d = start.duration(to: .now).components
            return Double(d.seconds) + Double(d.attoseconds) / 1e18
        }, checkpoint: checkpoint)
    }
    #endif
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct iGenticDiagnosticStepCandidate {
    @Guide(description: "Next action, not an execution result.", .anyOf(["status.read","model.readiness","abort"]))
    var action: String
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct iGenticDiagnosticStatusCandidate {
    @Guide(.anyOf(["status.read","abort"])) var action: String
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct iGenticDiagnosticReadinessCandidate {
    @Guide(.anyOf(["model.readiness","abort"])) var action: String
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct iGenticDiagnosticFinishCandidate {
    @Guide(.anyOf(["finish","abort"])) var action: String
}
@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct iGenticDiagnosticAllCandidate {
    @Guide(.anyOf(["status.read","model.readiness","capabilities.read","abort"])) var action: String
}
@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct iGenticDiagnosticStatusCapabilitiesCandidate {
    @Guide(.anyOf(["status.read","capabilities.read","abort"])) var action: String
}
@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct iGenticDiagnosticReadinessCapabilitiesCandidate {
    @Guide(.anyOf(["model.readiness","capabilities.read","abort"])) var action: String
}
@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct iGenticDiagnosticCapabilitiesCandidate {
    @Guide(.anyOf(["capabilities.read","abort"])) var action: String
}
#endif
