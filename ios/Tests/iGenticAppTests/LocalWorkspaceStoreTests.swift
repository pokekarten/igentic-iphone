import Foundation
import XCTest
@testable import iGenticApp

final class LocalWorkspaceStoreTests: XCTestCase {
    private func withStore(_ body: (LocalWorkspaceStore, URL) throws -> Void) throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("igentic-workspace-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        try body(LocalWorkspaceStore(directory: dir), dir)
    }

    func testPreviewDoesNotWriteAndConfirmedSaveIsReadable() throws {
        try withStore { store, dir in
            let preview = try store.preview(name: "notiz_01", text: "Privater Entwurf")
            XCTAssertNil(preview.previous)
            XCTAssertNil(try store.read(name: "notiz_01"))
            XCTAssertThrowsError(try store.apply(preview, confirmedByOwner: false)) {
                XCTAssertEqual($0 as? LocalWorkspaceError, .confirmationRequired)
            }
            try store.apply(preview, confirmedByOwner: true)
            XCTAssertEqual(try store.read(name: "notiz_01"), "Privater Entwurf")
            XCTAssertEqual(try store.listNames(), ["notiz_01"])
            let attributes = try FileManager.default.attributesOfItem(
                atPath: dir.appendingPathComponent("notiz_01.txt").path
            )
            XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        }
    }

    func testStalePreviewNeverOverwritesChangedNote() throws {
        try withStore { store, _ in
            try store.apply(try store.preview(name: "a", text: "first"), confirmedByOwner: true)
            let stale = try store.preview(name: "a", text: "second")
            try store.apply(try store.preview(name: "a", text: "third"), confirmedByOwner: true)
            XCTAssertThrowsError(try store.apply(stale, confirmedByOwner: true)) {
                XCTAssertEqual($0 as? LocalWorkspaceError, .stalePreview)
            }
            XCTAssertEqual(try store.read(name: "a"), "third")
        }
    }

    func testCanonicallyEquivalentByteChangeInvalidatesPreview() throws {
        try withStore { store, dir in
            let composed = "caf\u{00E9}"
            let decomposed = "cafe\u{0301}"
            XCTAssertEqual(composed, decomposed)
            XCTAssertNotEqual(Data(composed.utf8), Data(decomposed.utf8))
            try store.apply(try store.preview(name: "note", text: composed), confirmedByOwner: true)
            let stale = try store.preview(name: "note", text: "replacement")
            let url = dir.appendingPathComponent("note.txt")
            try Data(decomposed.utf8).write(to: url)
            XCTAssertThrowsError(try store.apply(stale, confirmedByOwner: true)) {
                XCTAssertEqual($0 as? LocalWorkspaceError, .stalePreview)
            }
            XCTAssertEqual(try Data(contentsOf: url), Data(decomposed.utf8))
        }
    }

    func testMissingNotePreviewDoesNotOverwriteNewEmptyNote() throws {
        try withStore { store, _ in
            let stale = try store.preview(name: "note", text: "replacement")
            try store.apply(try store.preview(name: "note", text: ""), confirmedByOwner: true)
            XCTAssertThrowsError(try store.apply(stale, confirmedByOwner: true)) {
                XCTAssertEqual($0 as? LocalWorkspaceError, .stalePreview)
            }
            XCTAssertEqual(try store.read(name: "note"), "")
        }
    }

    func testRejectsTraversalControlCharactersAndLargeFiles() throws {
        try withStore { store, _ in
            for name in ["../private", "a/b", ".hidden", "älter", "", String(repeating: "a", count: 33)] {
                XCTAssertThrowsError(try store.preview(name: name, text: "ok"))
            }
            XCTAssertThrowsError(try store.preview(name: "valid", text: "a\u{0}b"))
            XCTAssertThrowsError(try store.preview(name: "valid", text: String(repeating: "ä", count: 5000)))
            XCTAssertNil(try store.read(name: "valid"))
        }
    }

    func testHardlinkToExternalFileIsNotAWorkspaceNote() throws {
        try withStore { store, dir in
            _ = try store.listNames()
            let outside = FileManager.default.temporaryDirectory
                .appendingPathComponent("igentic-hardlink-fixture-\(UUID().uuidString)")
            try Data("synthetic external content".utf8).write(to: outside)
            defer { try? FileManager.default.removeItem(at: outside) }
            try FileManager.default.linkItem(
                at: outside, to: dir.appendingPathComponent("alias.txt")
            )
            XCTAssertThrowsError(try store.read(name: "alias")) {
                XCTAssertEqual($0 as? LocalWorkspaceError, .unsafeEntry)
            }
            XCTAssertThrowsError(try store.listNames()) {
                XCTAssertEqual($0 as? LocalWorkspaceError, .unsafeEntry)
            }
            XCTAssertEqual(
                try String(contentsOf: outside, encoding: .utf8),
                "synthetic external content"
            )
        }
    }

    func testRejectsSymlinkAndInvalidUTF8WithoutReadingContent() throws {
        try withStore { store, dir in
            _ = try store.listNames()
            let outside = FileManager.default.temporaryDirectory
                .appendingPathComponent("igentic-outside-\(UUID().uuidString)")
            try Data("outside".utf8).write(to: outside)
            defer { try? FileManager.default.removeItem(at: outside) }
            try FileManager.default.createSymbolicLink(
                at: dir.appendingPathComponent("linked.txt"), withDestinationURL: outside
            )
            XCTAssertThrowsError(try store.read(name: "linked"))
            XCTAssertThrowsError(try store.listNames())
            let invalid = dir.appendingPathComponent("invalid.txt")
            try Data([0xFF, 0xFE]).write(to: invalid)
            XCTAssertThrowsError(try store.read(name: "invalid"))
            XCTAssertEqual(try String(contentsOf: outside, encoding: .utf8), "outside")
        }
    }
}
