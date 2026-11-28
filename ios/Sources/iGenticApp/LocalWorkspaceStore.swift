import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// A first-party text-only workspace inside the app sandbox.
/// Models, MCP clients and remote transports are deliberately not given this store.
public struct LocalWorkspacePreview: Equatable, Sendable {
    public let name: String
    public let previous: String?
    public let proposed: String

    public var willReplaceExistingNote: Bool { previous != nil }
}

public enum LocalWorkspaceError: Error, Equatable {
    case invalidName
    case invalidText
    case unsafeEntry
    case stalePreview
    case confirmationRequired
}

extension LocalWorkspaceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidName: "Nur 1–32 Buchstaben, Ziffern, _ oder - als Notizname."
        case .invalidText: "Maximal 8192 UTF-8-Bytes ohne Steuerzeichen."
        case .unsafeEntry: "Unsicherer oder nicht lesbarer Eintrag. Keine Änderung."
        case .stalePreview: "Notiz wurde seit der Vorschau verändert. Bitte erneut prüfen."
        case .confirmationRequired: "Zum Speichern ist eine ausdrückliche Bestätigung nötig."
        }
    }
}

public struct LocalWorkspaceStore {
    public static let maximumTextBytes = 8192
    private let directory: URL
    private let fileManager = FileManager.default

    public init(directory: URL = LocalWorkspaceStore.defaultDirectory()) {
        self.directory = directory
    }

    public static func defaultDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iGentic/LocalWorkspace", isDirectory: true)
    }

    public func listNames() throws -> [String] {
        try ensureDirectory()
        let entries = try fileManager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey]
        )
        return try entries.compactMap { url in
            guard url.pathExtension == "txt" else { return nil }
            let name = url.deletingPathExtension().lastPathComponent
            try validateName(name)
            try requireRegularFile(url)
            return name
        }.sorted()
    }

    public func read(name: String) throws -> String? {
        try validateName(name)
        try ensureDirectory()
        let url = fileURL(name)
        guard fileManager.fileExists(atPath: url.path) else {
            // A dangling symbolic link must not be treated as a new writable file.
            if (try? fileManager.destinationOfSymbolicLink(atPath: url.path)) != nil {
                throw LocalWorkspaceError.unsafeEntry
            }
            return nil
        }
        try requireRegularFile(url)
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber,
              size.intValue <= Self.maximumTextBytes
        else { throw LocalWorkspaceError.unsafeEntry }
        let bytes = try Data(contentsOf: url)
        guard bytes.count <= Self.maximumTextBytes,
              let content = String(data: bytes, encoding: .utf8),
              isAllowedText(content)
        else { throw LocalWorkspaceError.unsafeEntry }
        return content
    }

    /// No mutation: UI must show both versions to the owner.
    public func preview(name: String, text: String) throws -> LocalWorkspacePreview {
        try validateName(name)
        guard isAllowedText(text),
              text.utf8.count <= Self.maximumTextBytes
        else { throw LocalWorkspaceError.invalidText }
        return LocalWorkspacePreview(name: name, previous: try read(name: name), proposed: text)
    }

    /// Only a separately confirmed, unchanged preview can be written.
    /// This never creates an arbitrary path, runs code, or exports a file.
    public func apply(_ preview: LocalWorkspacePreview, confirmedByOwner: Bool) throws {
        guard confirmedByOwner else { throw LocalWorkspaceError.confirmationRequired }
        try validateName(preview.name)
        guard isAllowedText(preview.proposed),
              preview.proposed.utf8.count <= Self.maximumTextBytes
        else { throw LocalWorkspaceError.invalidText }
        // Swift String equality is Unicode-canonical, not byte-exact. A file
        // changed to a different UTF-8 representation must invalidate the preview.
        let current = try read(name: preview.name)
        guard current.map({ Data($0.utf8) }) == preview.previous.map({ Data($0.utf8) }) else {
            throw LocalWorkspaceError.stalePreview
        }
        // Stage in a private directory on the same filesystem. Set protection
        // before publication, so failure cannot replace the previous note.
        // This is still a single-owner UI safeguard, not a multiprocess CAS.
        let staging = directory.appendingPathComponent(".stage-" + UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: false,
                                        attributes: [.posixPermissions: 0o700])
        defer { try? fileManager.removeItem(at: staging) }
        let candidate = staging.appendingPathComponent("note")
        #if os(iOS)
        try Data(preview.proposed.utf8).write(to: candidate, options: [.withoutOverwriting, .completeFileProtection])
        #else
        try Data(preview.proposed.utf8).write(to: candidate, options: .withoutOverwriting)
        #endif
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: candidate.path)
        // Same-volume rename is atomic. No throwing operation follows a
        // successful publication, so the caller cannot report a false failure.
        let destination = fileURL(preview.name)
        guard rename(candidate.path, destination.path) == 0 else {
            throw LocalWorkspaceError.unsafeEntry
        }
    }

    private func fileURL(_ name: String) -> URL {
        directory.appendingPathComponent(name + ".txt", isDirectory: false)
    }

    private func ensureDirectory() throws {
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(
                at: directory, withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        }
        let properties = try directory.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        guard properties.isDirectory == true, properties.isSymbolicLink != true else {
            throw LocalWorkspaceError.unsafeEntry
        }
    }

    private func requireRegularFile(_ url: URL) throws {
        let properties = try url.resourceValues(
            forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
        )
        guard properties.isRegularFile == true, properties.isSymbolicLink != true else {
            throw LocalWorkspaceError.unsafeEntry
        }
        // A hardlink is a regular file and bypasses the symlink guard.
        // Never allow a workspace entry to alias another file, even within
        // the app's sandbox. Missing link-count evidence also fails closed.
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard let links = attributes[.referenceCount] as? NSNumber,
              links.intValue == 1 else {
            throw LocalWorkspaceError.unsafeEntry
        }
    }

    private func validateName(_ name: String) throws {
        guard (1...32).contains(name.utf8.count),
              name.utf8.allSatisfy({ byte in
                  (65...90).contains(byte) || (97...122).contains(byte)
                    || (48...57).contains(byte) || byte == 95 || byte == 45
              })
        else { throw LocalWorkspaceError.invalidName }
    }

    private func isAllowedText(_ text: String) -> Bool {
        text.unicodeScalars.allSatisfy {
            $0.value >= 32 || $0.value == 9 || $0.value == 10 || $0.value == 13
        } && !text.unicodeScalars.contains { $0.value == 127 }
    }
}
