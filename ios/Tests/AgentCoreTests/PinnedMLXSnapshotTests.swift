import Foundation
import XCTest
@testable import AgentCore

final class PinnedMLXSnapshotTests: XCTestCase {
    func testPinnedManifest() {
        XCTAssertEqual(PinnedMLXSnapshot.qwenFiles.count, 9)
        XCTAssertEqual(Set(PinnedMLXSnapshot.qwenFiles.map(\.name)).count, 9)
        XCTAssertEqual(PinnedMLXSnapshot.qwenFiles.reduce(Int64(0)) { $0 + $1.bytes }, 351_383_618)
        XCTAssertEqual(PinnedMLXSnapshot.revision.count, 40)
        XCTAssertEqual(PinnedMLXSnapshot.license, "Apache-2.0")
    }

    func testLFMResearchManifest() {
        XCTAssertEqual(PinnedMLXSnapshot.lfmResearchFiles.count, 9)
        XCTAssertEqual(Set(PinnedMLXSnapshot.lfmResearchFiles.map(\.name)).count, 9)
        XCTAssertTrue(PinnedMLXSnapshot.lfmResearchFiles.contains { $0.name == "LICENSE" })
        XCTAssertEqual(PinnedMLXSnapshot.lfmResearchFiles.reduce(Int64(0)) { $0 + $1.bytes }, 226583972)
        XCTAssertEqual(PinnedMLXSnapshot.lfmResearchRevision.count, 40)
        XCTAssertEqual(PinnedMLXSnapshot.lfmResearchLicenseRevision.count, 40)
    }

    func testQwen35ResearchManifest() {
        XCTAssertEqual(PinnedMLXSnapshot.qwen35ResearchFiles.count, 12)
        XCTAssertEqual(Set(PinnedMLXSnapshot.qwen35ResearchFiles.map(\.name)).count, 12)
        XCTAssertTrue(PinnedMLXSnapshot.qwen35ResearchFiles.contains { $0.name == "LICENSE" })
        XCTAssertEqual(PinnedMLXSnapshot.qwen35ResearchFiles.reduce(Int64(0)) { $0 + $1.bytes }, 652039365)
        XCTAssertEqual(PinnedMLXSnapshot.qwen35ResearchRevision.count, 40)
    }

    func testFixtureAndRejections() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? fm.removeItem(at: root) }
        let folder = root.appendingPathComponent("snapshot")
        try fm.createDirectory(at: folder, withIntermediateDirectories: false)
        let file = folder.appendingPathComponent("fixture.json")
        let data = Data("abc".utf8)
        let entries: [PinnedMLXSnapshot.Entry] = [.init(name: "fixture.json", bytes: 3, digest: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")]
        try data.write(to: file)
        #if canImport(CryptoKit)
        XCTAssertEqual(PinnedMLXSnapshot.verify(directory: folder, entries: entries), .success(3))
        try Data("abd".utf8).write(to: file)
        XCTAssertEqual(PinnedMLXSnapshot.verify(directory: folder, entries: entries), .failure(.digestMismatch))
        try Data("abcd".utf8).write(to: file)
        XCTAssertEqual(PinnedMLXSnapshot.verify(directory: folder, entries: entries), .failure(.sizeMismatch))
        try fm.removeItem(at: file)
        XCTAssertEqual(PinnedMLXSnapshot.verify(directory: folder, entries: entries), .failure(.unexpectedFiles))
        try data.write(to: file)
        let extra = folder.appendingPathComponent("extra")
        try Data().write(to: extra)
        XCTAssertEqual(PinnedMLXSnapshot.verify(directory: folder, entries: entries), .failure(.unexpectedFiles))
        try fm.removeItem(at: extra)
        try fm.removeItem(at: file)
        let other = root.appendingPathComponent("other")
        try data.write(to: other)
        try fm.createSymbolicLink(at: file, withDestinationURL: other)
        XCTAssertEqual(PinnedMLXSnapshot.verify(directory: folder, entries: entries), .failure(.invalidFile))
        let alias = root.appendingPathComponent("alias")
        try fm.createSymbolicLink(at: alias, withDestinationURL: folder)
        XCTAssertEqual(PinnedMLXSnapshot.verify(directory: alias, entries: entries), .failure(.invalidDirectory))
        #else
        XCTAssertEqual(PinnedMLXSnapshot.verify(directory: folder, entries: entries), .failure(.digestUnavailable))
        #endif
    }
}
