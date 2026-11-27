import Foundation
import CryptoKit
import Darwin

/// Explicit one-chunk foreground research step. The pinned chunk manifest is
/// derived from the upstream-verified full file. No runtime admission or
/// automatic network fallback; independent full-file/manifest checks remain
/// mandatory. Private lab storage only, no user payload or credentials.
@MainActor
public enum NativeModelChunkStore {
    private struct Chunk: Sendable {
        let offset: Int64
        let count: Int
        let sha256: String
    }
    private static let total: Int64 = 1722271785
    private static let source = URL(string: "https://huggingface.co/mlx-community/Qwen3.5-2B-4bit/resolve/674aaa7240b91e8012fcad5d791b7dfe5ba90207/model.safetensors")!
    private static let chunks: [Chunk] = [
        .init(offset: 0, count: 1048576, sha256: "705691b421bd6370463372d1255f625dc87f839b2423c7067d85b707516cfaa5"),
        .init(offset: 1048576, count: 1048576, sha256: "66364401f5c8fcc43ba3f5171be4d0a012ac96454bb3ef3294116a331383b78d"),
        .init(offset: 2097152, count: 16777216, sha256: "d717b7c4b2525c847a2a08a05dd17254a65d186e053e84739c9ddb16a00d437a"),
        .init(offset: 18874368, count: 16777216, sha256: "4c96d4327bf2f8dd4ac14cd8ca549c7ed03fdd955ecd737ec9b85a761161431a"),
        .init(offset: 35651584, count: 16777216, sha256: "5b6a2b8aaa515c4e402f60d42341c23e15810f41db2b934cb26fb342d68fb79a"),
        .init(offset: 52428800, count: 16777216, sha256: "e897dbcb25b3e7119ade6c354549977d06774570c0629b63d7dcdc5058c8d151"),
        .init(offset: 69206016, count: 16777216, sha256: "0012afe66dda290e24edb88dfb68200f7c3047f7fb98f3cff25fe29adb32b597"),
        .init(offset: 85983232, count: 16777216, sha256: "4cc256caa50121ef3b6a099da3e8c8c055bf9baf6c7e66b639a025f721f9bec4"),
        .init(offset: 102760448, count: 16777216, sha256: "3d69b46193c9b2715ad2198df87cd7eb845b82cf2bd86bbc7e23b5ff959b7a4f"),
        .init(offset: 119537664, count: 16777216, sha256: "987195ec661f6f3402b2f33dca01010a83feeb33a491014568a9c206a77a1e4e"),
        .init(offset: 136314880, count: 16777216, sha256: "6126a68c46171d303a6f5c9f29d028c432adc51668e8c306d365a24bb0fa505f"),
        .init(offset: 153092096, count: 16777216, sha256: "48825a024a01457a698bca0e8d99182d8720893ac0e465061bfb0450bdbadaa5"),
        .init(offset: 169869312, count: 16777216, sha256: "96c73c50bfba7bee4a630c6bb10cad06d7521c3f2106c8dc9a4d7f2dddcb8478"),
        .init(offset: 186646528, count: 16777216, sha256: "1b1e921e2926b14856e74ebba49e0835bc530b30b5a08db4f245afd847868cce"),
        .init(offset: 203423744, count: 16777216, sha256: "a3fe9ae81f7fcb7ffeefccf77a650f813cbd6ccd59179cc04713435f9c5eeb0f"),
        .init(offset: 220200960, count: 16777216, sha256: "8d7662850b9516e30ca40335e7b13162889e49cf3027b71295c391cef90465ba"),
        .init(offset: 236978176, count: 16777216, sha256: "99723558271b49a61b2e8d82d8df937141422103e8648098626200d768f28456"),
        .init(offset: 253755392, count: 16777216, sha256: "30edb19bddd1cf99d872cc2e4b97195e5bf4720146672f1f8340304d2f39a1da"),
        .init(offset: 270532608, count: 16777216, sha256: "ac97a24e51e9871a8af80ec76818dfe720e8362420560a1726102eb63c703c0b"),
        .init(offset: 287309824, count: 16777216, sha256: "72f5d44daeae3acd86c7e9ef19a1c8aadee5a7f0be880848c2a077eec855a020"),
        .init(offset: 304087040, count: 16777216, sha256: "c21fe8aa6a06c25c4a51deece6722a87664124daac63fe155ea340532e7c5174"),
        .init(offset: 320864256, count: 16777216, sha256: "828f763a57fdcf6daf9a722ec2d7b5b70ce2a9c562b2611883b8e6795d247cde"),
        .init(offset: 337641472, count: 16777216, sha256: "368870520c31b9b22fd20b3c5d3e72408de7d13058a7fa415fd8cf372b659e66"),
        .init(offset: 354418688, count: 16777216, sha256: "05f5430fa2fe19acd34bb1ef2026760d93ad79075a3f331ba823509a8bdde6b7"),
        .init(offset: 371195904, count: 16777216, sha256: "b9cef016a82cc3c63428f5ff2746e4f6aff536ed5561932e9e4e9c2f3b674a44"),
        .init(offset: 387973120, count: 16777216, sha256: "f2ceefe2d5ad97698c1d9313581e9326fa9d9b4e48d65d804b68288b9d2eb6e1"),
        .init(offset: 404750336, count: 16777216, sha256: "f27ae83a29f03a7de61983e1b303dc85f544779662e31221a405794de0e908fb"),
        .init(offset: 421527552, count: 16777216, sha256: "92524f39afb1790aa5e4a1b6c93a3f4688c9a06ab950faab1c86ce659fabc4c9"),
        .init(offset: 438304768, count: 16777216, sha256: "c7fed70f364d851ae354e75f3451d7f839b79487ad4f5bdb8cb9b83653e6dc6f"),
        .init(offset: 455081984, count: 16777216, sha256: "9572f3dcd01477a551d8eba3ad5b7891789fedfa2bcece463e104067d3886451"),
        .init(offset: 471859200, count: 16777216, sha256: "8f39ea46718c168d520c61a7d4ab91b3386c1b159ef01abfae5a4057d833e437"),
        .init(offset: 488636416, count: 16777216, sha256: "a4c6cf28600a9b6d44fcddc795a7d4a829cf115e355a85a20829e3f9efcca3de"),
        .init(offset: 505413632, count: 16777216, sha256: "501498d71777aa0694d5574d15a8c83c3e613fd0e8b44e9fce468d8fc12125e2"),
        .init(offset: 522190848, count: 16777216, sha256: "351c3fcb46148cb54406ae2340ceb5fa02c888c3dfa442aa46f39b41d194eb41"),
        .init(offset: 538968064, count: 16777216, sha256: "6a68d2f0a62cc8005faaa3c08b88796f53f06ef6b7e99f85cad1ff4ff4affa13"),
        .init(offset: 555745280, count: 16777216, sha256: "71068303aada38f81330f8a3be6d526829f0e213aa654e279438cbd3e1a3cf59"),
        .init(offset: 572522496, count: 16777216, sha256: "04ad6d4a317a8dc7545cfe3e5464ecf092d6c3a091b17621a5f57d73704467a3"),
        .init(offset: 589299712, count: 16777216, sha256: "544fb24b5baa152bd897ab200360a827529eb6ce24ea07d9779e2ef07b2c4b5f"),
        .init(offset: 606076928, count: 16777216, sha256: "9256610697a59531d01ea7ed88dd789d1c292e64ef37a9fa2469540b66d09e82"),
        .init(offset: 622854144, count: 16777216, sha256: "ff63587d4f358dff7119e447e83c602518a364016b9035f2333c62977f8e80e5"),
        .init(offset: 639631360, count: 16777216, sha256: "900692553ef8f7cee6a0baa0aac8049e5d9d377707939b4de653a0550d591097"),
        .init(offset: 656408576, count: 16777216, sha256: "76b0192c12aac3630aa3768e5b8707b81da8f5030915ee9a791534adeab0cee7"),
        .init(offset: 673185792, count: 16777216, sha256: "e2d97f70a0495151eae2394aca15248deeaf6759b6fbe542028fde4f735f37a1"),
        .init(offset: 689963008, count: 16777216, sha256: "6a23e0917922fe5e2e08eac9c98eef39a71d2c2b037682a42e17c80faf69fd92"),
        .init(offset: 706740224, count: 16777216, sha256: "2e199a9c24de5b9f160565ec3fc73453332df134c649f47e830199656be3dd9c"),
        .init(offset: 723517440, count: 16777216, sha256: "96406c58cd88c52ac5b6aee07a00d0acc1a40f89980de74e963b047e6ae54b56"),
        .init(offset: 740294656, count: 16777216, sha256: "6e439c9464ae223f4298888342090da2860f5864f84a45728310730cd26ed165"),
        .init(offset: 757071872, count: 16777216, sha256: "c5b831a5c9f7f1c8835e1f5b10e836f15149f65c9b12095366d91ab6ad24d308"),
        .init(offset: 773849088, count: 16777216, sha256: "cfcd7505222182a2247e6546b6aab197bb87253b3472f09673d4938f1735f742"),
        .init(offset: 790626304, count: 16777216, sha256: "d5211b120b7278a2dcbdad5a9dbeae14996389ecd09d1f1a90d05fad4c531aa4"),
        .init(offset: 807403520, count: 16777216, sha256: "aefdc00dfbcb681c8255935a775230a007a92a90c3e81fe1d2837b9347555d00"),
        .init(offset: 824180736, count: 16777216, sha256: "835b54f6b7ad572ad0f7dd6f1d24251cfe29fa744f66a562b0a61b0bdfca072f"),
        .init(offset: 840957952, count: 16777216, sha256: "e26f4207cf53433a26b40a2046a7f6327fe02ca924740b4a3d99b238e2a99b99"),
        .init(offset: 857735168, count: 16777216, sha256: "4c0ca096747706544fc7c0e729660915794aec1c385d66643b02f817549c1be1"),
        .init(offset: 874512384, count: 16777216, sha256: "6614d9b50ed3a7136e3997163a2a9a41b511d2546e350f88039e3ef1b54b2a67"),
        .init(offset: 891289600, count: 16777216, sha256: "2f7b57826310bc70d752f61c541c668ec8707f1f7e8dde4f8190b81577b2a432"),
        .init(offset: 908066816, count: 16777216, sha256: "30ebc56a051d57f90a4ba5d6a1fe54c8b361b8f208753aa6ef7265bfc8ea376c"),
        .init(offset: 924844032, count: 16777216, sha256: "6cbc0799af776306a1adecfe8895083158cda697e64fc342ef47396d6f3df1aa"),
        .init(offset: 941621248, count: 16777216, sha256: "e410742d0c9a53c643083c91846d04a99f89ac15401895d4ae1f36e8e12dcf94"),
        .init(offset: 958398464, count: 16777216, sha256: "8b94d694305e01b54c70008a479f8153a3926ee75ceb7c6d56a37947e1bee2fd"),
        .init(offset: 975175680, count: 16777216, sha256: "5b38394c759ba2cfbfa2c35d96eaa75abaa763f87784ff794d7b917c70bff33a"),
        .init(offset: 991952896, count: 16777216, sha256: "81ee3348da044f85192c23f6571bb445f2c936da21e5ccba2499bde88c230350"),
        .init(offset: 1008730112, count: 16777216, sha256: "7d14f2bcfcf51a00751ea8a43482ba43caaec0dc29304967488b6dc1c03da2cf"),
        .init(offset: 1025507328, count: 16777216, sha256: "41620742d6565cbbd5d91ed588977c3046670ad013ddac528e09cd407ccabca9"),
        .init(offset: 1042284544, count: 16777216, sha256: "a5f6bc87a5925e6d7ed9c086237cd1c96250f23d997d7d5e9775662f14c33c8b"),
        .init(offset: 1059061760, count: 16777216, sha256: "2c20519b6923748fae7982f7397ca60d6db4fe892e9fa0e9186aae791fc1001d"),
        .init(offset: 1075838976, count: 16777216, sha256: "6c1e6edb8d9d19206a492b7240e7d784eb180951e591245706ebd7aeba80531a"),
        .init(offset: 1092616192, count: 16777216, sha256: "4214956ed74483e695321bdfb13e690c85e4c11ef965577efae17e23d5e8b9a9"),
        .init(offset: 1109393408, count: 16777216, sha256: "8bb88a6f3f01404c19b4f27e03ca4fda9b0113ba3d371b3becd1c2b65cbd8212"),
        .init(offset: 1126170624, count: 16777216, sha256: "4d6af205dd18646a4df1253e827d55379076a3f84460287562508ec64cca6601"),
        .init(offset: 1142947840, count: 16777216, sha256: "6966b560691c2269c2f47bbfa8c36d27f825b5e1e9c3130413ac942d75224c45"),
        .init(offset: 1159725056, count: 16777216, sha256: "8a9022e5013c2a1c87daa5acef04ace35e57db9a3a473f7084073dd1dccf1b9e"),
        .init(offset: 1176502272, count: 16777216, sha256: "c394e44cd7116594febd92b40ee412865a01990805bf61385e1dd5347326a203"),
        .init(offset: 1193279488, count: 16777216, sha256: "730cd8528f4078a2d307726ff7aa08ef0bc985c9feb5cd149b0bc2fefac18577"),
        .init(offset: 1210056704, count: 16777216, sha256: "8d7feefc459215cb52ae8832337f6400f87c4a49b53d39620caea87c7c6f054a"),
        .init(offset: 1226833920, count: 16777216, sha256: "af024a843532f9d6b576632e7b2f5656aaad4de4b4c48a1c5c64a17488d3823a"),
        .init(offset: 1243611136, count: 16777216, sha256: "c5cfcbae84d9eae5f31d17d634304f1a11484409cb440f10296880735146fbf2"),
        .init(offset: 1260388352, count: 16777216, sha256: "fc099297f2dade8b53e01c53728ccc0c7bf82eaa3545b4974245945fd92bb6e9"),
        .init(offset: 1277165568, count: 16777216, sha256: "8a78cd8beb087b8be65362163ae03673c7add65bec0eab56fd8cdb36933e3652"),
        .init(offset: 1293942784, count: 16777216, sha256: "d121aeb8f3eebe14d531788af3552627245843250693a5c2ebd01985074f9f5f"),
        .init(offset: 1310720000, count: 16777216, sha256: "3f3110a44d3db9a0c20ea93cd138a8423bc71c7f7cc777d6947904f93eda8cb6"),
        .init(offset: 1327497216, count: 16777216, sha256: "7cfb08321bd6d8a5efb6dd1d32cf7c4151b2f5916dc4a1811f0ea5f4435701db"),
        .init(offset: 1344274432, count: 16777216, sha256: "51cec6d1f156dc14318fe74058ea522a97f8f601b2d94e71f7d66cd2c38a3888"),
        .init(offset: 1361051648, count: 16777216, sha256: "bad55f69918717343f3935449e62df189baeee73c43bffe95a543e502dd4123d"),
        .init(offset: 1377828864, count: 16777216, sha256: "f1870b124cb1aa7d12b11e48dd4df651b6b82a4941021902d0fd5ff07ccec24c"),
        .init(offset: 1394606080, count: 16777216, sha256: "e71d507e3885fc6bebf34eadf2d7349a52c7db1ab930d811fb190727105bdee1"),
        .init(offset: 1411383296, count: 16777216, sha256: "7cc2de402a81f6b5ecdcc07b1be8ec12dad205a9bbcaa504794fe257a0950943"),
        .init(offset: 1428160512, count: 16777216, sha256: "2c5db7c51abd4876519dbd27a93f0dec9ab678348ed62426df76cbf2a8cf9766"),
        .init(offset: 1444937728, count: 16777216, sha256: "de580b7d07f5aa0ff77cd212ce4cb65cc393695173c5088ea3bc00bafe491a88"),
        .init(offset: 1461714944, count: 16777216, sha256: "0987c73ea7c5852eb336808ac085d55b3e878c58b82c30a01d79acc8a435b4c2"),
        .init(offset: 1478492160, count: 16777216, sha256: "4b9607690133862af983cd933a5bea854d6ce86c0221ef4be8311167663c2d4c"),
        .init(offset: 1495269376, count: 16777216, sha256: "13913fa7c07007866984fc9cbc2582d821eb9ea272ae4e24dfc2860c99591f10"),
        .init(offset: 1512046592, count: 16777216, sha256: "5ca78a553b60785ddd266545b075da108ba154047a35892778d8e206b9c8875d"),
        .init(offset: 1528823808, count: 16777216, sha256: "511995a6b5908dc92fe9994465e954a3ce24d6bb66884e432c39bf7bf8b4a819"),
        .init(offset: 1545601024, count: 16777216, sha256: "3665dc9065cfcaee33639a62373720544d7b152b9f8b55e80b730438186be061"),
        .init(offset: 1562378240, count: 16777216, sha256: "0f2d0b7b701c73dad4162d41257b93687d62ff44ac01bb862f4cc171b219f7c9"),
        .init(offset: 1579155456, count: 16777216, sha256: "8f4ea77cdc62e71f1eb8a1a551efd18e4718661cb335f1414fadd2328b30f262"),
        .init(offset: 1595932672, count: 16777216, sha256: "3d9af841269a3c1383284af4697bc8f9d4880db46610f984a68dbd2b9759b95f"),
        .init(offset: 1612709888, count: 16777216, sha256: "ef7b7a8496099857f3a0a3cb46c936b9911616f2e526a44e6e579ec95f6fe006"),
        .init(offset: 1629487104, count: 16777216, sha256: "56ad73aa851b5df23e2a18560beb5ef8dda4f40dd215dbdda7caff837ba44396"),
        .init(offset: 1646264320, count: 16777216, sha256: "ef635f563bc1ee077c5d5439618dc548650a194e784577bb26406efa274110f7"),
        .init(offset: 1663041536, count: 16777216, sha256: "7118c013ad0e25360bad9dc7c37dece732d0e0345dae6992c4e6df7bf5a74ec8"),
        .init(offset: 1679818752, count: 16777216, sha256: "5817536e383dec735b003e6d6cf8e8eb09bf1e95b0cc64e254f0dbcaaea60978"),
        .init(offset: 1696595968, count: 16777216, sha256: "f4ff1909fff072ec4fd5c9228b85cfd0168a2abe28c870c4815ded0fc888384c"),
        .init(offset: 1713373184, count: 8898601, sha256: "cd39c3924ef6ac4d5077dd4c060824034792684092a1edd53d3af5c94e2ed1f5"),
    ]

    private static func digest(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
    private nonisolated static func allowed(_ url: URL?) -> Bool {
        guard let url, url.scheme == "https", url.user == nil, url.password == nil, let host = url.host?.lowercased() else { return false }
        return host == "huggingface.co" || host.hasSuffix(".huggingface.co") || host.hasSuffix(".hf.co")
    }
    private final class RedirectGate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
        let range: String
        init(range: String) { self.range = range }
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest) async -> URLRequest? {
            guard NativeModelChunkStore.allowed(request.url) else { return nil }
            var clean = request
            clean.setValue(nil, forHTTPHeaderField: "Authorization")
            clean.setValue(nil, forHTTPHeaderField: "Cookie")
            clean.setValue(range, forHTTPHeaderField: "Range")
            clean.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
            return clean
        }
    }
    private static var running = false
    private static func file(_ root: URL, _ index: Int) -> URL {
        root.appendingPathComponent(String(format: "chunk-%04d.bin", index))
    }
    private static func check(_ url: URL, _ chunk: Chunk) -> Bool {
        var st = stat()
        guard lstat(url.path, &st) == 0, (st.st_mode & S_IFMT) == S_IFREG,
              st.st_nlink == 1, st.st_size == chunk.count,
              let data = try? Data(contentsOf: url), data.count == chunk.count else { return false }
        return digest(data) == chunk.sha256
    }

    /// One verified chunk per explicit invocation. A later process can resume
    /// from the contiguous independently checked files; partial downloads never
    /// become checkpoints. Caller retains exclusive control of this lab folder.
    public static func step() async -> String {
        guard !running else { return "MODEL_CHUNK=busy; installed=false" }
        running = true; defer { running = false }
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("qwen2b-native-chunks-v1", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        } catch {
            // Existing directory is acceptable, but not a symbolic link.
        }
        var st = stat()
        guard lstat(root.path, &st) == 0, (st.st_mode & S_IFMT) == S_IFDIR else {
            return "MODEL_CHUNK=storageRejected; installed=false"
        }
        do {
            let names = Set(try FileManager.default.contentsOfDirectory(atPath: root.path))
            let count = names.count
            guard count <= chunks.count,
                  names == Set((0..<count).map { file(root, $0).lastPathComponent }) else {
                return "MODEL_CHUNK=checkpointRejected; installed=false"
            }
            for i in 0..<count {
                try Task.checkCancellation()
                guard check(file(root, i), chunks[i]) else { return "MODEL_CHUNK=checkpointRejected; installed=false" }
            }
            if count == chunks.count { return "MODEL_CHUNK=allChunksVerified; installed=false" }
            let chunk = chunks[count]
            guard let capacity = try? root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage,
                  capacity >= Int64(chunk.count) + 2_147_483_648 else { return "MODEL_CHUNK=storageRejected; installed=false" }
            let range = "bytes=\(chunk.offset)-\(chunk.offset+Int64(chunk.count)-1)"
            var request = URLRequest(url: source)
            request.setValue(range, forHTTPHeaderField: "Range")
            request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
            let config = URLSessionConfiguration.ephemeral
            config.httpCookieStorage = nil; config.urlCredentialStorage = nil; config.urlCache = nil
            config.httpShouldSetCookies = false
            config.timeoutIntervalForRequest = 25; config.timeoutIntervalForResource = 90
            let session = URLSession(configuration: config, delegate: RedirectGate(range: range), delegateQueue: nil)
            defer { session.invalidateAndCancel() }
            let start = ProcessInfo.processInfo.systemUptime
            let (stream, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse, allowed(http.url), http.statusCode == 206,
                  http.value(forHTTPHeaderField: "Content-Range") == "bytes \(chunk.offset)-\(chunk.offset+Int64(chunk.count)-1)/\(total)",
                  http.expectedContentLength == -1 || http.expectedContentLength == Int64(chunk.count) else {
                return "MODEL_CHUNK=responseRejected; installed=false"
            }
            var data = Data(); data.reserveCapacity(chunk.count)
            for try await byte in stream {
                guard data.count < chunk.count, !Task.isCancelled else { return "MODEL_CHUNK=bodyRejected; installed=false" }
                data.append(byte)
            }
            guard data.count == chunk.count, digest(data) == chunk.sha256 else { return "MODEL_CHUNK=bodyRejected; installed=false" }
            try Task.checkCancellation()
            try data.write(to: file(root, count), options: [.atomic])
            guard check(file(root, count), chunk) else { return "MODEL_CHUNK=checkpointRejected; installed=false" }
            return "MODEL_CHUNK=verified; previous=\(count); next=\(count+1); chunks=\(chunks.count); bytes=\(chunk.count); offset=\(chunk.offset); milliseconds=\(Int((ProcessInfo.processInfo.systemUptime-start)*1000)); installed=false"
        } catch { return "MODEL_CHUNK=failed; installed=false" }
    }
}
