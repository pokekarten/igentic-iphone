import Foundation

public enum AppActionApprovalPolicyBootstrapState: Equatable, Sendable {
    case loadedExisting(AppActionApprovalPolicy)
    case installedDefault(AppActionApprovalPolicy)
    case fellBackToDefault(AppActionApprovalPolicy)

    public var policy: AppActionApprovalPolicy {
        switch self {
        case .loadedExisting(let policy), .installedDefault(let policy), .fellBackToDefault(let policy):
            return policy
        }
    }
}

public struct AppActionApprovalPolicyBootstrap: Sendable {
    public let store: AppActionApprovalPolicyStore

    public init(store: AppActionApprovalPolicyStore = .init(fileURL: AppActionApprovalPolicyStore.defaultFileURL())) {
        self.store = store
    }

    public func prepare(fileManager: FileManager = .default) throws -> AppActionApprovalPolicyBootstrapState {
        if let policy = store.load() {
            return .loadedExisting(policy)
        }

        if fileManager.fileExists(atPath: store.fileURL.path) {
            return .fellBackToDefault(.default)
        }

        let policy = AppActionApprovalPolicy.default
        try store.save(policy, fileManager: fileManager)
        return .installedDefault(policy)
    }
}
