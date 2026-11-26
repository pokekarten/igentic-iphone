import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Byte admission for one reviewed, immutable MLX snapshot. No downloads,
/// inference, model-generated manifests, or tool execution are performed.
public enum PinnedMLXSnapshot {
    public static let modelID = "mlx-community/Qwen3-0.6B-4bit"
    public static let revision = "73e3e38d981303bc594367cd910ea6eb48349da8"
    public static let license = "Apache-2.0"

    public enum Rejection: Error, Equatable, Sendable {
        case invalidDirectory, unexpectedFiles, invalidFile, sizeMismatch, digestMismatch, digestUnavailable
    }
    public struct Receipt: Equatable, Sendable {
        public let modelID: String
        public let revision: String
        public let fileCount: Int
        public let totalBytes: Int64
    }
    struct Entry: Sendable {
        let name: String
        let bytes: Int64
        let digest: String
    }
    static let qwenFiles: [Entry] = [
        .init(name: "added_tokens.json", bytes: 707, digest: "c0284b582e14987fbd3d5a2cb2bd139084371ed9acbae488829a1c900833c680"),
        .init(name: "config.json", bytes: 937, digest: "15d3ac26c043ae477273ed5802ee0f0b33bb14f18c9d3dd70910c02d906e3f1f"),
        .init(name: "merges.txt", bytes: 1671853, digest: "8831e4f1a044471340f7c0a83d7bd71306a5b867e95fd870f74d0c5308a904d5"),
        .init(name: "model.safetensors", bytes: 335450584, digest: "392e8d466d56100ada00eb82031fb854297fc9e389b7d303eba3af114e87bce2"),
        .init(name: "model.safetensors.index.json", bytes: 49731, digest: "7b294141456f6904936db03c00bca50fb5f6198f652fe8483f9cd2a1018accfb"),
        .init(name: "special_tokens_map.json", bytes: 613, digest: "76862e765266b85aa9459767e33cbaf13970f327a0e88d1c65846c2ddd3a1ecd"),
        .init(name: "tokenizer.json", bytes: 11422654, digest: "aeb13307a71acd8fe81861d94ad54ab689df773318809eed3cbe794b4492dae4"),
        .init(name: "tokenizer_config.json", bytes: 9706, digest: "253153d0738ceb4c668d2eff957714dd2bea0b56de772a9fdccd96cbf517e6a0"),
        .init(name: "vocab.json", bytes: 2776833, digest: "ca10d7e9fb3ed18575dd1e277a2579c16d108e32f27439684afa0e10b1440910"),
    ]

    public static let lfmResearchModelID = "LiquidAI/LFM2.5-350M-MLX-4bit"
    public static let lfmResearchRevision = "f6cb4e006bb7a2d8a6afa14ec0a53e0586f65a5b"
    // The pinned original model supplies the license text missing in this export.
    public static let lfmResearchLicenseRevision = "9921cd4d82c0e3986887aa4b376f9446729ef8a3"
    public static let lfmResearchLicense = "LFM Open License v1.0"
    static let lfmResearchFiles: [Entry] = [
        .init(name: "LICENSE", bytes: 10574, digest: "4d28ca14dedc0b3d0fcc2b3339f0e79931faa33874f3d24f522183a8fc70068c"),
        .init(name: "README.md", bytes: 2329, digest: "90060ba684dfe9716d391782396bf2084a3941b5bcdb31f1ef6d1b5a5934814e"),
        .init(name: "chat_template.jinja", bytes: 2607, digest: "1a2d8281b5477abb5bb1cebd69d7d1ee389e074656ca5f5e0ef6ae56d6ae65c1"),
        .init(name: "config.json", bytes: 1714, digest: "9a8d76fffac255e7aeba7f154fd493e5b42c55b8bf150cc3478484adec6a98ed"),
        .init(name: "generation_config.json", bytes: 132, digest: "1c72d35bb46c5102537eb114fea9a5c10ef928cc813401c3c12aef399c1f8e5d"),
        .init(name: "model.safetensors", bytes: 221809325, digest: "f17b51362f7aa11a8dffafa6f44c625d5d695b2f76122eed11525104810ae809"),
        .init(name: "model.safetensors.index.json", bytes: 23413, digest: "be372bf2e03a849a8f01821a2e35ffc44840a86d3132ad7e8f2cef5ea655b50f"),
        .init(name: "tokenizer.json", bytes: 4733389, digest: "df1d8d5ec5d091b460562ffd545e4a5e91d17d4a0db7ebe733be34ed374377bd"),
        .init(name: "tokenizer_config.json", bytes: 489, digest: "75c287923e252b08b0a0f1c367bbe557ab23a681d0b71c5a34e0932ddbe2f5ee"),
    ]

    /// Research-only byte verification. A valid snapshot is not authorization
    /// for commercial use, production routing or any tool execution.
    public static func verifyLFM25Research(directory: URL) -> Result<Receipt, Rejection> {
        verify(directory: directory, entries: lfmResearchFiles).map {
            Receipt(modelID: lfmResearchModelID, revision: lfmResearchRevision,
                    fileCount: lfmResearchFiles.count, totalBytes: $0)
        }
    }

    /// The caller must retain exclusive control of this private model directory
    /// until loading finishes. This is a byte check, not a runtime attestation.
    public static func verifyQwen3(directory: URL) -> Result<Receipt, Rejection> {
        verify(directory: directory, entries: qwenFiles).map {
            Receipt(modelID: modelID, revision: revision, fileCount: qwenFiles.count, totalBytes: $0)
        }
    }

    static func verify(directory: URL, entries: [Entry]) -> Result<Int64, Rejection> {
        #if canImport(CryptoKit) && (canImport(Darwin) || canImport(Glibc))
        guard directory.isFileURL else { return .failure(.invalidDirectory) }
        let dir = open(directory.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard dir >= 0 else { return .failure(.invalidDirectory) }
        defer { _ = close(dir) }
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path),
              Set(names) == Set(entries.map(\.name)), names.count == entries.count else {
            return .failure(.unexpectedFiles)
        }
        var total: Int64 = 0
        for entry in entries {
            let fd = openat(dir, entry.name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
            guard fd >= 0 else { return .failure(.invalidFile) }
            defer { _ = close(fd) }
            var info = stat()
            guard fstat(fd, &info) == 0, (info.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG), info.st_nlink == 1 else {
                return .failure(.invalidFile)
            }
            guard info.st_size == entry.bytes else { return .failure(.sizeMismatch) }
            var hash = SHA256()
            var buffer = [UInt8](repeating: 0, count: 1_048_576)
            var count: Int64 = 0
            while true {
                let n = read(fd, &buffer, buffer.count)
                guard n >= 0 else { return .failure(.invalidFile) }
                if n == 0 { break }
                count += Int64(n)
                guard count <= entry.bytes else { return .failure(.sizeMismatch) }
                hash.update(data: Data(buffer.prefix(n)))
            }
            guard count == entry.bytes, fstat(fd, &info) == 0, info.st_size == entry.bytes else {
                return .failure(.sizeMismatch)
            }
            let digest = hash.finalize().map { String(format: "%02x", $0) }.joined()
            guard digest == entry.digest else { return .failure(.digestMismatch) }
            total += count
        }
        return .success(total)
        #else
        return .failure(.digestUnavailable)
        #endif
    }
}
