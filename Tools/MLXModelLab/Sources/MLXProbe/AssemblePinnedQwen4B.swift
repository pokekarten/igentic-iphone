import Foundation
import CryptoKit
import Darwin
import AgentCore

/// Fixed offline lab import. Caller must retain exclusive access to both private
/// directories. No download, model execution, arbitrary paths or primary app.
public enum AssemblePinnedQwen4B {
    private struct Part: Sendable { let bytes: Int64; let sha256: String }
    private static let total: Int64 = 2263022417
    private static let digest = "2a73c6c248601ab904e035548abd8e6abb65ea27dcb5f342fb0a8910eb44173f"
    private static let parts: [Part] = [
        .init(bytes: 67108864, sha256: "2890f9471a9443b95c9b5d1e23476ee3a86b0f02b1920648b5af8f8fbd498aa6"),
        .init(bytes: 67108864, sha256: "1eb6001135c527f5bf5ba1a87362c2b180c5ef3543988649228c093d492af465"),
        .init(bytes: 67108864, sha256: "45f4ab0433a727dce11c24e3dad068687409f2b704479d689a3efcd477eeee6a"),
        .init(bytes: 67108864, sha256: "105236a278ba6bb02cb2f2b8f71e0b87960d2a1f68f059986c6f79d465f2d86f"),
        .init(bytes: 67108864, sha256: "29f56a4be9a370cd98475d4ed8605168b0898d1f0c9dc2949c08c9499ca6cb14"),
        .init(bytes: 67108864, sha256: "611f8482e7fb05570f5df7565d36bb94c3ee76af6d1993c7b552cd4d38346743"),
        .init(bytes: 67108864, sha256: "708534d6d40d06027204b87b0e91862783968cd98473631462a06da46e699ca8"),
        .init(bytes: 67108864, sha256: "7b6f67d610fef78f582e9fc29da04432b4c3f326afca5d00d5b824875ce2a9c6"),
        .init(bytes: 67108864, sha256: "f50531e19fcd2786cf4bdc47e7ef8b59a07f47419f5f97d412bd38093f7511fe"),
        .init(bytes: 67108864, sha256: "f7d3c5bb0562e66a67fa27f2efdb3a05fecf69027b408dec8a0acf618903143d"),
        .init(bytes: 67108864, sha256: "57963bb6575a7f3bf9e31dbf6e1c04df8240acfee0b505737a960d6befc80ddd"),
        .init(bytes: 67108864, sha256: "fa6ddb7fc63585ee11728b2551b16ecc003d0939aa1f9b5dba3c352de660a5ef"),
        .init(bytes: 67108864, sha256: "d219e15000bfce9a49ea7a17a71233c698c31289a32a3248ba5dc525f65e46b1"),
        .init(bytes: 67108864, sha256: "f8b210fc8e779ae98dbe3818ca3671e1fcbda2484741976ebefa637435f30f84"),
        .init(bytes: 67108864, sha256: "f2797e459217aef868e4215107dd96c21594832181aa0ce7f4388dc0aa401c59"),
        .init(bytes: 67108864, sha256: "fe37faaab185bbe8ee91b2d7b5d448f8fe6e259fc7f0d204c05e4a00c28aa59e"),
        .init(bytes: 67108864, sha256: "6a2508791deee454696e551aa1328ffa3736932b6480c85a5f1bcb061231fdbc"),
        .init(bytes: 67108864, sha256: "8a0f8b55cda45f23417574e800fab4724324f6381552f17274847ebf15b2131f"),
        .init(bytes: 67108864, sha256: "0f956dcb2d37a62ea942748a233b022577364f2cc0bd5fb313eef61e3ab56d34"),
        .init(bytes: 67108864, sha256: "e5f9167fe6e0f57f5a7c5b6cc76628ddd9291c394456d01af8fb83fd3d634377"),
        .init(bytes: 67108864, sha256: "757fa42dd02d50ad67ce6f899fdeec07a6c71ef9fce2f69e51712e33892ff779"),
        .init(bytes: 67108864, sha256: "0385e26d8c5993be0efaa92d7ad62722250c7352e63ff0b70cfe7cf7c0373cda"),
        .init(bytes: 67108864, sha256: "f81ae4acdd1994f5e4f2999edebb1c93b9ef6e947d430b543602187f0d390147"),
        .init(bytes: 67108864, sha256: "03997fc0a61b5c4f2ab0d754c32f70e7091927a7038f76006234ac0f5e632424"),
        .init(bytes: 67108864, sha256: "d59cd8e69e4e7d6c02be84568b0a20feda7001d84239f12f822a775089a95a1d"),
        .init(bytes: 67108864, sha256: "e63fc4860a911634eb3ab34ef353d8b2773b4938d6e17239270fb1c9fb85d860"),
        .init(bytes: 67108864, sha256: "5b6e1fc98b5477ef4788a3b0c308edf190b4098a8815a5ec674b245f05c41e9a"),
        .init(bytes: 67108864, sha256: "e93850129171688a7b68cc3c010056502d2c339aed9c27a9c4744f44f20aff5c"),
        .init(bytes: 67108864, sha256: "aa31270e37f6739325260e1d11c65bb74cf3a521d50018e533001f798fff36b8"),
        .init(bytes: 67108864, sha256: "37b82313dc32e85d8f608dd61df3d2e884087df2e3f852628aabb4d0b022367c"),
        .init(bytes: 67108864, sha256: "833e91a34e35d42db2e633e632010bc44a0bed7cd440b886ef53fc0fef1c682b"),
        .init(bytes: 67108864, sha256: "0fd3e459c8e673be33f65c425404a50e4461932b9d4508bd682e2471d8dfded0"),
        .init(bytes: 67108864, sha256: "06aa504f066a6399fec58a03aec717329d11b4274f7742161094972e09578972"),
        .init(bytes: 48429905, sha256: "c07391f97a0e3eed5eab4684a5caaf463e6b3479b2750feafba1673928a300f2"),
    ]
    private enum Failure: Error { case input, io, digest }
    private static func hex(_ d: SHA256.Digest) -> String {
        d.map { String(format: "%02x", $0) }.joined()
    }
    private static func isDirectory(_ url: URL) -> Bool {
        var st = stat()
        return lstat(url.path, &st) == 0 && (st.st_mode & S_IFMT) == S_IFDIR
    }
    private static func copy(_ url: URL, part: Part, output: FileHandle, full: inout SHA256) throws {
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
        guard fd >= 0 else { throw Failure.io }
        let reader = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? reader.close() }
        var st = stat()
        guard fstat(fd, &st) == 0, (st.st_mode & S_IFMT) == S_IFREG,
              st.st_nlink == 1, st.st_size == part.bytes else { throw Failure.input }
        var hash = SHA256(), remaining = part.bytes
        while remaining > 0 {
            try Task.checkCancellation()
            guard let data = try reader.read(upToCount: Int(min(remaining, 1_048_576))),
                  !data.isEmpty else { throw Failure.io }
            hash.update(data: data); full.update(data: data)
            try output.write(contentsOf: data); remaining -= Int64(data.count)
        }
        guard try reader.read(upToCount: 1)?.isEmpty ?? true,
              hex(hash.finalize()) == part.sha256 else { throw Failure.digest }
    }
    public static func run() -> String {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = root.appendingPathComponent("qwen3text4b", isDirectory: true)
        let staging = root.appendingPathComponent("qwen3text4b-parts", isDirectory: true)
        let destination = folder.appendingPathComponent("model.safetensors")
        let temporary = root.appendingPathComponent("qwen4b-assembled-" + UUID().uuidString)
        let names = parts.indices.map { String(format: "part-%04d.bin", $0) }
        let start = ProcessInfo.processInfo.systemUptime
        var st = stat()
        guard isDirectory(folder), isDirectory(staging),
              lstat(destination.path, &st) != 0, errno == ENOENT,
              let actual = try? FileManager.default.contentsOfDirectory(atPath: staging.path),
              Set(actual) == Set(names), parts.reduce(Int64(0), { $0 + $1.bytes }) == total else {
            return "QWEN4B_ASSEMBLY=inputRejected; inference=false"
        }
        guard let capacity = try? root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage,
              capacity >= total + 2_147_483_648 else {
            return "QWEN4B_ASSEMBLY=storageBlocked; inference=false"
        }
        let fd = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { return "QWEN4B_ASSEMBLY=ioFailed; inference=false" }
        let output = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? output.close(); try? FileManager.default.removeItem(at: temporary) }
        do {
            var full = SHA256()
            for (index, part) in parts.enumerated() {
                try copy(staging.appendingPathComponent(names[index]), part: part, output: output, full: &full)
            }
            guard hex(full.finalize()) == digest else { throw Failure.digest }
            try output.synchronize(); try output.close(); try Task.checkCancellation()
            guard lstat(temporary.path, &st) == 0, (st.st_mode & S_IFMT) == S_IFREG,
                  st.st_size == total, st.st_nlink == 1,
                  renamex_np(temporary.path, destination.path, UInt32(RENAME_EXCL)) == 0 else { throw Failure.io }
            guard case .success(let r) = PinnedMLXSnapshot.verifyQwen3Text4BResearch(directory: folder) else {
                return "QWEN4B_ASSEMBLY=manifestRejected; inference=false"
            }
            return "QWEN4B_ASSEMBLY=verified; parts=\(parts.count); files=\(r.fileCount); bytes=\(r.totalBytes); milliseconds=\(Int((ProcessInfo.processInfo.systemUptime-start)*1000)); inference=false"
        } catch { return "QWEN4B_ASSEMBLY=failed; inference=false" }
    }
}
