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

    func testGranite350ResearchManifest() {
        XCTAssertEqual(PinnedMLXSnapshot.granite350ResearchFiles.count, 12)
        XCTAssertEqual(Set(PinnedMLXSnapshot.granite350ResearchFiles.map(\.name)).count, 12)
        XCTAssertTrue(PinnedMLXSnapshot.granite350ResearchFiles.contains { $0.name == "UPSTREAM_MODEL_CARD.md" })
        XCTAssertEqual(PinnedMLXSnapshot.granite350ResearchFiles.reduce(Int64(0)) { $0 + $1.bytes }, 201_810_115)
        XCTAssertEqual(PinnedMLXSnapshot.granite350ResearchRevision.count, 40)
    }

    func testMiniCPM5ResearchManifest() {
        XCTAssertEqual(PinnedMLXSnapshot.miniCPM5ResearchFiles.count, 10)
        XCTAssertEqual(Set(PinnedMLXSnapshot.miniCPM5ResearchFiles.map(\.name)).count, 10)
        XCTAssertTrue(PinnedMLXSnapshot.miniCPM5ResearchFiles.contains { $0.name == "UPSTREAM_MODEL_CARD.md" })
        XCTAssertEqual(PinnedMLXSnapshot.miniCPM5ResearchFiles.reduce(Int64(0)) { $0 + $1.bytes }, 618_039_803)
        XCTAssertEqual(PinnedMLXSnapshot.miniCPM5ResearchRevision.count, 40)
    }

    func testFalcon90ResearchManifest() {
        XCTAssertEqual(PinnedMLXSnapshot.falcon90ResearchFiles.count, 9)
        XCTAssertEqual(Set(PinnedMLXSnapshot.falcon90ResearchFiles.map(\.name)).count, 9)
        XCTAssertEqual(PinnedMLXSnapshot.falcon90ResearchFiles.reduce(Int64(0)) { $0 + $1.bytes }, 53968563)
        XCTAssertTrue(PinnedMLXSnapshot.falcon90ResearchFiles.contains { $0.name == "UPSTREAM_MODEL_CARD.md" })
    }

    func testSmol135ResearchManifest() {
        XCTAssertEqual(PinnedMLXSnapshot.smol135ResearchFiles.count, 10)
        XCTAssertEqual(Set(PinnedMLXSnapshot.smol135ResearchFiles.map(\.name)).count, 10)
        XCTAssertEqual(PinnedMLXSnapshot.smol135ResearchFiles.reduce(Int64(0)) { $0 + $1.bytes }, 79221815)
        XCTAssertTrue(PinnedMLXSnapshot.smol135ResearchFiles.contains { $0.name == "UPSTREAM_MODEL_CARD.md" })
    }

    func testLFM12ResearchManifest() {
        XCTAssertEqual(PinnedMLXSnapshot.lfm12ResearchFiles.count, 11)
        XCTAssertEqual(Set(PinnedMLXSnapshot.lfm12ResearchFiles.map(\.name)).count, 11)
        XCTAssertEqual(PinnedMLXSnapshot.lfm12ResearchFiles.reduce(Int64(0)) { $0 + $1.bytes }, 663422439)
        XCTAssertTrue(PinnedMLXSnapshot.lfm12ResearchFiles.contains { $0.name == "UPSTREAM_MODEL_CARD.md" })
    }

    func testQwen2BResearchManifest() {
        XCTAssertEqual(PinnedMLXSnapshot.qwen2bResearchFiles.count, 13)
        XCTAssertEqual(Set(PinnedMLXSnapshot.qwen2bResearchFiles.map(\.name)).count, 13)
        XCTAssertEqual(PinnedMLXSnapshot.qwen2bResearchFiles.reduce(Int64(0)) { $0 + $1.bytes }, 1749154715)
        XCTAssertTrue(PinnedMLXSnapshot.qwen2bResearchFiles.contains { $0.name == "UPSTREAM_MODEL_CARD.md" })
    }

    func testQwen4BResearchManifest() {
        XCTAssertEqual(PinnedMLXSnapshot.qwen4bResearchFiles.count, 13)
        XCTAssertEqual(Set(PinnedMLXSnapshot.qwen4bResearchFiles.map(\.name)).count, 13)
        XCTAssertEqual(PinnedMLXSnapshot.qwen4bResearchFiles.reduce(Int64(0)) { $0 + $1.bytes }, 3061220555)
        XCTAssertTrue(PinnedMLXSnapshot.qwen4bResearchFiles.contains { $0.name == "LICENSE" })
    }

    func testQwen3Text4BResearchManifest() {
        XCTAssertEqual(PinnedMLXSnapshot.qwen3text4bResearchFiles.count, 14)
        XCTAssertEqual(Set(PinnedMLXSnapshot.qwen3text4bResearchFiles.map(\.name)).count, 14)
        XCTAssertEqual(PinnedMLXSnapshot.qwen3text4bResearchFiles.reduce(Int64(0)) { $0 + $1.bytes }, 2278990177)
        XCTAssertTrue(PinnedMLXSnapshot.qwen3text4bResearchFiles.contains { $0.name == "LICENSE" })
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
