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

    public static let qwen35ResearchModelID = "mlx-community/Qwen3.5-0.8B-4bit"
    public static let qwen35ResearchRevision = "da28692b5f139cb0ec58a356b437486b7dac7462"
    public static let qwen35ResearchLicenseRevision = "2fc06364715b967f1860aea9cf38778875588b17"
    static let qwen35ResearchFiles: [Entry] = [
        .init(name: "LICENSE", bytes: 11544, digest: "bbedc3fda3305820b977265f01b8619d87570a6739de3a5582c3464840f1e57a"),
        .init(name: "README.md", bytes: 678, digest: "5614ff1cdf39fd970ade36d9499d99024c089e7add90931e018b8cd8de6dd265"),
        .init(name: "chat_template.jinja", bytes: 7755, digest: "273d8e0e683b885071fb17e08d71e5f2a5ddfb5309756181681de4f5a1822d80"),
        .init(name: "config.json", bytes: 3112, digest: "ba7770da23eae5ebd6827571f086e331956b33f4442a9e876fb4aa10969a6772"),
        .init(name: "model.safetensors", bytes: 625229487, digest: "f5a0d9dd3efa73510542a8023d610ff26be2b4b020d181cfc4bedaa1fcc5dd9e"),
        .init(name: "model.safetensors.index.json", bytes: 71473, digest: "6e48f2fa5d6f033a6d77bf833abfa9698ca24d1715ecea4c67447bcfaee44650"),
        .init(name: "preprocessor_config.json", bytes: 390, digest: "27225450ac9c6529872ee1924fcb0962ff5634834f817040f444118116f4e516"),
        .init(name: "processor_config.json", bytes: 1300, digest: "14932921ca485d458a04dafd8069fbb0a4505622a48208d19ed247115801385b"),
        .init(name: "tokenizer.json", bytes: 19989343, digest: "87a7830d63fcf43bf241c3c5242e96e62dd3fdc29224ca26fed8ea333db72de4"),
        .init(name: "tokenizer_config.json", bytes: 1139, digest: "e98f1901ac6f0adff67b1d540bfa0c36ac1a0cf59eb72ed78146ef89aafa1182"),
        .init(name: "video_preprocessor_config.json", bytes: 385, digest: "7768af27c1fafa9cc9011c1dc20067e03f8915e03b63504550e11d5066986d13"),
        .init(name: "vocab.json", bytes: 6722759, digest: "ce99b4cb2983d118806ce0a8b777a35b093e2000a503ebde25853284c9dfa003"),
    ]

    /// Research-only pin. Weights must pass byte verification before loading.
    /// This does not establish text or multimodal runtime compatibility.
    public static func verifyQwen35Research(directory: URL) -> Result<Receipt, Rejection> {
        verify(directory: directory, entries: qwen35ResearchFiles).map {
            Receipt(modelID: qwen35ResearchModelID, revision: qwen35ResearchRevision,
                    fileCount: qwen35ResearchFiles.count, totalBytes: $0)
        }
    }

    public static let granite350ResearchModelID = "mlx-community/granite-4.0-h-350m-4bit"
    public static let granite350ResearchRevision = "2b96c1f68e5349bcaec2a498a68cc177537e46d1"
    public static let granite350UpstreamRevision = "3b17b717b8f2f5d305b0a92c1491e239aeda19c8"
    static let granite350ResearchFiles: [Entry] = [
        .init(name: "README.md", bytes: 904, digest: "7a03391eb3f4df30673b008f24d40951319d1b80e17e6dcec07fe001833cb326"),
        .init(name: "UPSTREAM_MODEL_CARD.md", bytes: 33196, digest: "df1afd6b94ea2cb8e9948c5c78646500499516186f73eb5217add80305011b5f"),
        .init(name: "chat_template.jinja", bytes: 6418, digest: "9524df67b77a7b25a2dfee898f75b316a157eb9d855b51e32aeac79d7c8a83ce"),
        .init(name: "config.json", bytes: 2145, digest: "4e24aa441f7afe9050da9cfff33db40d496e7bc4e60b74851990b52f215020ae"),
        .init(name: "generation_config.json", bytes: 147, digest: "7c04cb9d2ba771f7528fba5a7104999cdaf7566d02b5fbd58472829f62716177"),
        .init(name: "merges.txt", bytes: 916646, digest: "b6fe424e334903f7fb84d3a106d9730455f4744b9fe3c21ee136d97a00e72502"),
        .init(name: "model.safetensors", bytes: 192015950, digest: "808cf0214a3d615539667f73fb315ae37c2218e69e8e7316f8d3b22e053988ed"),
        .init(name: "model.safetensors.index.json", bytes: 50346, digest: "ff1f5f88a93dd86bfa9f316f0e89e934f7eab1064ca023ed048a894a7204a2ea"),
        .init(name: "special_tokens_map.json", bytes: 579, digest: "c08676c49fd7969a3130f72be6d4bf34da66aa484a6e21dffe359893a1bd5f2e"),
        .init(name: "tokenizer.json", bytes: 7153421, digest: "e2bad66439538cb4d5a7580680932432ed9ece9d3b8577e675512bdf11599253"),
        .init(name: "tokenizer_config.json", bytes: 17659, digest: "a5ec5daab12ba090a90f3dd169c8f9c275557013a87b9c1258dc7cb497a35c86"),
        .init(name: "vocab.json", bytes: 1612704, digest: "8af71076de8b0b626eed0f4c984faf0a7c062479164b2a31308a948524d4f69c"),
    ]

    /// Private research candidate. Upstream model card states Apache-2.0;
    /// standalone upstream license file is absent. No production admission.
    public static func verifyGranite350Research(directory: URL) -> Result<Receipt, Rejection> {
        verify(directory: directory, entries: granite350ResearchFiles).map {
            Receipt(modelID: granite350ResearchModelID, revision: granite350ResearchRevision,
                    fileCount: granite350ResearchFiles.count, totalBytes: $0)
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
