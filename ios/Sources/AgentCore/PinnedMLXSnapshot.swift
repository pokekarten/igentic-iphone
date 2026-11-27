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
