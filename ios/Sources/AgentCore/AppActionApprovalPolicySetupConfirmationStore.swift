import Foundation

public struct AppActionApprovalPolicySetupConfirmationStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func defaultFileURL(fileManager: FileManager = .default) -> URL {
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return baseDirectory
            .appendingPathComponent("iGentic", isDirectory: true)
            .appendingPathComponent("AppActionApprovalPolicySetupConfirmed.v1")
    }

    public func isConfirmed() -> Bool {
        guard let data = try? Data(contentsOf: fileURL) else {
            return false
        }
        return data == Self.confirmationData
    }

    public func confirm(fileManager: FileManager = .default) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        if directoryURL.path != "/" && directoryURL.path != "." {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        try Self.confirmationData.write(to: fileURL, options: [.atomic])
    }

    private static let confirmationData = Data("confirmed-v1\n".utf8)
}
