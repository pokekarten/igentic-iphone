import Foundation
import CryptoKit
import Darwin
import AgentCore

/// Fixed research recovery of a previously interrupted CoreDevice transfer.
/// No network, arbitrary path, model inference, or primary-app access.
/// A verified new file is assembled before atomically replacing the partial.
public enum RecoverPinnedQwen2B {
    private static let offset: Int64 = 1292921912
    private static let total: Int64 = 1722271785
    private static let prefixDigest = "86cf447ff91b4a180a69ee8366412729e602a8d0585a324f7f78b9d1cd6a2353"
    private static let tailDigest = "0df157539cf7b5456f1c49d1b75bb4ff6d5252398c30ba3d2dd265066d6ce47b"
    private static let fullDigest = "713fe7e5d3c3965f7106b0d0ee17615f7869c23c8d327996df8c1196fbcf07d5"

    private enum Failure: Error { case invalidInput, io, digest }
    private static func regular(_ url: URL, bytes: Int64) -> Bool {
        var info = stat()
        guard lstat(url.path, &info) == 0 else { return false }
        return (info.st_mode & S_IFMT) == S_IFREG && info.st_nlink == 1 && info.st_size == bytes
    }
    private static func hex(_ digest: SHA256.Digest) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }
    private static func copy(_ source: URL, bytes: Int64, output: FileHandle,
                             whole: inout SHA256) throws -> String {
        guard regular(source, bytes: bytes) else { throw Failure.invalidInput }
        let fd = open(source.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
        guard fd >= 0 else { throw Failure.io }
        let reader = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? reader.close() }
        var info = stat()
        guard fstat(fd, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG,
              info.st_nlink == 1, info.st_size == bytes else { throw Failure.invalidInput }
        var local = SHA256(), remaining = bytes
        while remaining > 0 {
            try Task.checkCancellation()
            guard let data = try reader.read(upToCount: Int(min(remaining, 1_048_576))),
                  !data.isEmpty else { throw Failure.io }
            local.update(data: data); whole.update(data: data)
            try output.write(contentsOf: data); remaining -= Int64(data.count)
        }
        guard try reader.read(upToCount: 1)?.isEmpty ?? true else { throw Failure.invalidInput }
        return hex(local.finalize())
    }

    /// The lab caller must retain exclusive control of its private model
    /// directory throughout recovery. No concurrent downloader or loader.
    public static func run() -> String {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = root.appendingPathComponent("qwen2b", isDirectory: true)
        let prefix = folder.appendingPathComponent("model.safetensors")
        let tail = root.appendingPathComponent("qwen2b-tail-recovery.bin")
        let temporary = root.appendingPathComponent("qwen2b-assembled-" + UUID().uuidString)
        let start = ProcessInfo.processInfo.systemUptime
        var info = stat()
        guard lstat(folder.path, &info) == 0, (info.st_mode & S_IFMT) == S_IFDIR,
              regular(prefix, bytes: offset), regular(tail, bytes: total-offset) else {
            return "QWEN2B_RECOVERY=inputRejected; inference=false"
        }
        guard let available = try? root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage,
              available >= total + 2_147_483_648 else {
            return "QWEN2B_RECOVERY=storageBlocked; inference=false"
        }
        let fd = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { return "QWEN2B_RECOVERY=ioFailed; inference=false" }
        let output = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? output.close(); try? FileManager.default.removeItem(at: temporary) }
        do {
            var hash = SHA256()
            guard try copy(prefix, bytes: offset, output: output, whole: &hash) == prefixDigest,
                  try copy(tail, bytes: total-offset, output: output, whole: &hash) == tailDigest,
                  hex(hash.finalize()) == fullDigest else { throw Failure.digest }
            try output.synchronize()
            try output.close()
            try Task.checkCancellation()
            guard regular(temporary, bytes: total), regular(prefix, bytes: offset),
                  rename(temporary.path, prefix.path) == 0 else { throw Failure.io }
            guard case .success(let r) = PinnedMLXSnapshot.verifyQwen2BResearch(directory: folder) else {
                return "QWEN2B_RECOVERY=manifestRejected; inference=false"
            }
            return "QWEN2B_RECOVERY=verified; files=\(r.fileCount); bytes=\(r.totalBytes); milliseconds=\(Int((ProcessInfo.processInfo.systemUptime-start)*1000)); inference=false"
        } catch { return "QWEN2B_RECOVERY=failed; inference=false" }
    }
}
