import Foundation

enum ReminderAttempt {
    /// Reserve before EventKit writes. Keep the reservation across process death.
    static func reserve(_ id: UUID, in directory: URL) throws -> Bool {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            try Data().write(to: directory.appendingPathComponent(id.uuidString), options: .withoutOverwriting)
            return true
        } catch let error as CocoaError where error.code == .fileWriteFileExists {
            return false
        }
    }
}
