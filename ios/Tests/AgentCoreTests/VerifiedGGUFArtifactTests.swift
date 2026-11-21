import Foundation
import XCTest
@testable import AgentCore
#if canImport(CryptoKit)
import CryptoKit
#endif

final class VerifiedGGUFArtifactTests: XCTestCase {
    private func makeManifest(modelID: String = "fixture/qwen-class", filename: String = "fixture.gguf", sha: String, size: Int, license: Bool = true, revision: String = String(repeating: "a", count: 40)) -> Data {
        let payload: [String: Any] = [
            "model_id": modelID,
            "filename": filename,
            "sha256": sha,
            "size_bytes": size,
            "source_revision": revision,
            "license_reviewed": license
        ]
        return try! JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    }

    func testRejectsNoncanonicalModelIdentity() {
        let sha = String(repeating: "0", count: 64)
        let invalidIDs = [
            "publisher/../private",
            "publisher//model",
            "publisher/model/extra",
            "publisher/.",
            "/model",
            "model-without-publisher"
        ]
        for modelID in invalidIDs {
            XCTAssertEqual(
                VerifiedGGUFArtifact.verify(
                    manifestData: makeManifest(modelID: modelID, sha: sha, size: 10),
                    directoryURL: FileManager.default.temporaryDirectory
                ),
                .failure(.invalidManifest),
                "Rejected model identity: \(modelID)"
            )
        }
    }

    func testRejectsUnpinnedRevisionAndLicense() throws {
        let directory = FileManager.default.temporaryDirectory
        let sha = String(repeating: "0", count: 64)
        XCTAssertEqual(VerifiedGGUFArtifact.verify(manifestData: makeManifest(sha: sha, size: 10, license: false), directoryURL: directory), .failure(.invalidManifest))
        XCTAssertEqual(VerifiedGGUFArtifact.verify(manifestData: makeManifest(sha: sha, size: 10, revision: "main"), directoryURL: directory), .failure(.invalidManifest))
    }

    func testRejectsTraversalAndUnexpectedFields() throws {
        let directory = FileManager.default.temporaryDirectory
        let sha = String(repeating: "0", count: 64)
        XCTAssertEqual(VerifiedGGUFArtifact.verify(manifestData: makeManifest(filename: "../escape.gguf", sha: sha, size: 10), directoryURL: directory), .failure(.invalidManifest))
        var raw = try XCTUnwrap(JSONSerialization.jsonObject(with: makeManifest(sha: sha, size: 10)) as? [String: Any])
        raw["untrusted_url"] = "https://example.invalid"
        let extra = try JSONSerialization.data(withJSONObject: raw)
        XCTAssertEqual(VerifiedGGUFArtifact.verify(manifestData: extra, directoryURL: directory), .failure(.invalidManifest))
    }

    #if canImport(CryptoKit)
    func testVerifiesFixtureAndRejectsTampering() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("fixture.gguf")
        let bytes = Data("synthetic model fixture".utf8)
        try bytes.write(to: file)
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        let manifest = makeManifest(sha: digest, size: bytes.count)
        XCTAssertEqual(VerifiedGGUFArtifact.verify(manifestData: manifest, directoryURL: root), .success(.init(modelID: "fixture/qwen-class", sizeBytes: Int64(bytes.count), sha256: digest)))
        try Data(repeating: 0, count: bytes.count).write(to: file)
        XCTAssertEqual(VerifiedGGUFArtifact.verify(manifestData: manifest, directoryURL: root), .failure(.digestMismatch))
    }

    func testRejectsSymbolicLink() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let external = root.appendingPathComponent("original.gguf")
        let link = root.appendingPathComponent("fixture.gguf")
        try Data("fixture".utf8).write(to: external)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: external)
        let sha = SHA256.hash(data: Data("fixture".utf8)).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(VerifiedGGUFArtifact.verify(manifestData: makeManifest(sha: sha, size: 7), directoryURL: root), .failure(.invalidFile))
    }
    #endif
}
