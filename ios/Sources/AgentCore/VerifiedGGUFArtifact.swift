import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Read-only, local GGUF byte integrity gate. Never loads or executes a model.
/// The expected hash and license review must come from a trusted caller, not
/// from model-generated output or an unverified model download.
public enum VerifiedGGUFArtifact {
    public enum Rejection: String, Error, Equatable, Sendable {
        case invalidManifest
        case invalidDirectory
        case invalidFile
        case sizeMismatch
        case digestMismatch
        case digestUnavailable
    }

    public struct Receipt: Equatable, Sendable {
        public let modelID: String
        public let sizeBytes: Int64
        public let sha256: String
    }

    private struct Manifest: Decodable {
        let modelID: String
        let filename: String
        let sha256: String
        let sizeBytes: Int64
        let sourceRevision: String
        let licenseReviewed: Bool

        enum CodingKeys: String, CodingKey {
            case modelID = "model_id"
            case filename
            case sha256
            case sizeBytes = "size_bytes"
            case sourceRevision = "source_revision"
            case licenseReviewed = "license_reviewed"
        }
    }

    private static func matches(_ input: String, _ expression: String) -> Bool {
        input.range(of: expression, options: .regularExpression) != nil
    }

    /// Reject ambiguous JSON *before* Foundation decoders discard duplicate
    /// object members. The manifest is deliberately a flat, six-scalar object.
    /// Keys are decoded as JSON strings so escaped aliases also collide.
    private static func hasUniqueManifestKeys(_ data: Data) -> Bool {
        // Reject oversized input before allocating a separate byte array.
        guard !data.isEmpty, data.count <= 16_384 else { return false }
        let bytes = Array(data)
        var offset = 0

        func skipWhitespace() {
            while offset < bytes.count && [9, 10, 13, 32].contains(bytes[offset]) {
                offset += 1
            }
        }

        func take(_ byte: UInt8) -> Bool {
            skipWhitespace()
            guard offset < bytes.count, bytes[offset] == byte else { return false }
            offset += 1
            return true
        }

        func readString() -> String? {
            guard offset < bytes.count, bytes[offset] == 34 else { return nil }
            let start = offset
            offset += 1
            while offset < bytes.count {
                let value = bytes[offset]
                offset += 1
                if value == 34 {
                    return try? JSONDecoder().decode(String.self, from: Data(bytes[start..<offset]))
                }
                if value == 92 {
                    // Leave escaped quotes/backslashes/uXXXX decoding to JSONDecoder.
                    guard offset < bytes.count else { return nil }
                    offset += 1
                }
            }
            return nil
        }

        func readScalar() -> Bool {
            skipWhitespace()
            guard offset < bytes.count else { return false }
            if bytes[offset] == 34 { return readString() != nil }
            // Nested objects/arrays cannot occur in this six-scalar schema.
            guard bytes[offset] != 123, bytes[offset] != 91 else { return false }
            let start = offset
            while offset < bytes.count,
                  ![UInt8(9), 10, 13, 32, 44, 125].contains(bytes[offset]) {
                offset += 1
            }
            return offset > start
        }

        guard take(123) else { return false } // {
        var keys = Set<String>()
        let required: Set<String> = [
            "model_id", "filename", "sha256", "size_bytes",
            "source_revision", "license_reviewed"
        ]
        for position in 0..<required.count {
            skipWhitespace()
            guard let key = readString(), required.contains(key),
                  keys.insert(key).inserted, take(58), readScalar()
            else { return false }
            skipWhitespace()
            if position < required.count - 1 {
                guard take(44) else { return false } // ,
            }
        }
        guard take(125) else { return false } // }
        skipWhitespace()
        return offset == bytes.count && keys == required
    }

    public static func verify(manifestData: Data, directoryURL: URL) -> Result<Receipt, Rejection> {
        guard
            hasUniqueManifestKeys(manifestData),
            let manifest = try? JSONDecoder().decode(Manifest.self, from: manifestData),
            matches(manifest.modelID, "\\A[A-Za-z0-9][A-Za-z0-9._-]{0,63}/[A-Za-z0-9][A-Za-z0-9._-]{0,63}\\z"),
            matches(manifest.filename, "\\A[A-Za-z0-9][A-Za-z0-9._-]{0,255}\\z"),
            manifest.filename.hasSuffix(".gguf"),
            ![".", ".."].contains(manifest.filename),
            matches(manifest.sha256, "\\A[0-9a-f]{64}\\z"),
            matches(manifest.sourceRevision, "\\A[0-9a-f]{40}\\z"),
            manifest.sizeBytes > 0, manifest.sizeBytes <= 20_000_000_000,
            manifest.licenseReviewed
        else { return .failure(.invalidManifest) }

        #if canImport(CryptoKit) && (canImport(Darwin) || canImport(Glibc))
        guard directoryURL.isFileURL else { return .failure(.invalidDirectory) }
        let directoryPath = directoryURL.path
        var dirStat = stat()
        guard lstat(directoryPath, &dirStat) == 0,
              (dirStat.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR)
        else { return .failure(.invalidDirectory) }

        let filePath = directoryURL.appendingPathComponent(manifest.filename, isDirectory: false).path
        var fileStat = stat()
        guard lstat(filePath, &fileStat) == 0,
              (fileStat.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG)
        else { return .failure(.invalidFile) }
        guard fileStat.st_size == manifest.sizeBytes else { return .failure(.sizeMismatch) }

        let fd = open(filePath, O_RDONLY | O_NOFOLLOW)
        guard fd >= 0 else { return .failure(.invalidFile) }
        defer { _ = close(fd) }
        var opened = stat()
        guard fstat(fd, &opened) == 0,
              opened.st_dev == fileStat.st_dev,
              opened.st_ino == fileStat.st_ino,
              (opened.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG)
        else { return .failure(.invalidFile) }
        guard opened.st_size == manifest.sizeBytes else { return .failure(.sizeMismatch) }

        var hasher = SHA256()
        var buffer = [UInt8](repeating: 0, count: 1024 * 1024)
        var total: Int64 = 0
        while true {
            let count = read(fd, &buffer, buffer.count)
            if count < 0 { return .failure(.invalidFile) }
            if count == 0 { break }
            total += Int64(count)
            if total > manifest.sizeBytes { return .failure(.sizeMismatch) }
            hasher.update(data: Data(buffer.prefix(count)))
        }
        guard total == manifest.sizeBytes,
              fstat(fd, &opened) == 0, opened.st_size == manifest.sizeBytes
        else { return .failure(.sizeMismatch) }
        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        guard digest == manifest.sha256 else { return .failure(.digestMismatch) }
        return .success(Receipt(modelID: manifest.modelID, sizeBytes: total, sha256: digest))
        #else
        return .failure(.digestUnavailable)
        #endif
    }
}
