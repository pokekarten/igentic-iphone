#if os(iOS) && canImport(SwiftUI) && canImport(CryptoKit) && canImport(Security)
import Foundation
import SwiftUI
import Security
import CryptoKit

// The user enables this per-device; no background task, device access, arbitrary
// remote commands, persistent connection or external mobile automation runtime.
private struct CellularCredentials: Codable {
    let endpoint: String
    let secret: String
}

private enum CellularKeychain {
    static let service = "de.bos.igentic.cellular-readiness-v1"
    static let account = "opt-in-connection"

    private static var lookup: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
    static func save(endpoint: String, secret: String) -> Bool {
        guard CellularHeartbeatProtocol.validEndpoint(endpoint) != nil,
              CellularHeartbeatProtocol.decodedSecret(secret) != nil,
              let data = try? JSONEncoder().encode(CellularCredentials(
                endpoint: endpoint, secret: secret.trimmingCharacters(in: .whitespacesAndNewlines)
              )) else { return false }
        var item = lookup
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        // Never delete valid stored credentials before a replacement succeeds.
        // SecItemUpdate is atomic; on unexpected errors retain the old item.
        let replacement: [String: Any] = [kSecValueData as String: data]
        let update = SecItemUpdate(
            lookup as CFDictionary, replacement as CFDictionary
        )
        if update == errSecSuccess { return true }
        guard update == errSecItemNotFound else { return false }
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }
    static func load() -> CellularCredentials? {
        var query = lookup
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let credentials = try? JSONDecoder().decode(CellularCredentials.self, from: data),
              CellularHeartbeatProtocol.validEndpoint(credentials.endpoint) != nil,
              CellularHeartbeatProtocol.decodedSecret(credentials.secret) != nil
        else { return nil }
        return credentials
    }
    static func clear() {
        _ = SecItemDelete(lookup as CFDictionary)
    }
}

private final class NoCellularRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

private enum CellularReadinessClient {
    static func send() async -> String {
        guard let saved = CellularKeychain.load(),
              let url = CellularHeartbeatProtocol.validEndpoint(saved.endpoint),
              let secret = CellularHeartbeatProtocol.decodedSecret(saved.secret)
        else { return "Nicht eingerichtet" }

        let timestamp = Int(Date().timeIntervalSince1970)
        let nonce = UUID().uuidString.lowercased()
        guard let signature = CellularHeartbeatProtocol.signature(
            secret: secret, timestamp: timestamp, nonce: nonce
        ) else { return "Signaturfehler" }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = CellularHeartbeatProtocol.body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(String(timestamp), forHTTPHeaderField: "x-igentic-timestamp")
        request.setValue(nonce, forHTTPHeaderField: "x-igentic-nonce")
        request.setValue(signature, forHTTPHeaderField: "x-igentic-signature")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 12

        let config = URLSessionConfiguration.ephemeral
        config.allowsCellularAccess = true
        config.waitsForConnectivity = false
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 15
        config.requestCachePolicy = .reloadIgnoringLocalCacheData

        let session = URLSession(
            configuration: config, delegate: NoCellularRedirect(), delegateQueue: nil
        )
        defer { session.invalidateAndCancel() }
        do {
            // Only system-trusted HTTPS; NEVER bypass trust or allow redirects.
            let (data, response) = try await session.data(for: request)
            guard let reply = response as? HTTPURLResponse,
                  reply.statusCode == 200,
                  data.count <= 512,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json.count == 5, json["schema"] as? Int == 1,
                  json["status"] as? String == "accepted",
                  json["capability"] as? String == "readiness-only",
                  json["deviceControl"] as? String == "not-enabled",
                  json["backgroundExecution"] as? String == "not-guaranteed"
            else { return "Serverbestätigung nicht gültig" }
            return "Bestätigt: sicherer Bereitschaftscheck. Netzwerkroute nicht verifiziert."
        } catch {
            // Deliberately never display URLs, network diagnostics or tokens.
            return "Verbindung oder TLS nicht bestätigt"
        }
    }
}

public struct CellularCompanionView: View {
    @State private var endpoint = ""
    @State private var secret = ""
    @State private var status = "Deaktiviert bis zur manuellen Einrichtung"
    @State private var isSending = false

    public init() {}

    public var body: some View {
        Form {
            Section("Optionaler Mobilfunk-Begleiter") {
                Text("Funktioniert über mobile Daten, wenn eine eigene erreichbare HTTPS-Adresse konfiguriert ist. Kein Mac, USB-C oder ChatGPT ist für den iPhone-Client nötig.")
                Text("Nur nach Antippen. Kein Hintergrunddienst und keine Fernsteuerung anderer Apps. Für einen echten 4G/5G-Nachweis WLAN ausschalten.")
            }
            Section("Eigener iGentic-HTTPS-Server") {
                TextField("https://example.com/v1/companion/readiness", text: $endpoint)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                SecureField("32-Byte-Schlüssel (Base64)", text: $secret)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Verbindung sicher speichern") {
                    let saved = CellularKeychain.save(endpoint: endpoint, secret: secret)
                    secret = ""
                    status = saved ? "Lokal im Schlüsselbund gespeichert" :
                        "Ungültige HTTPS-Adresse oder Schlüssel"
                }
                Button("Verbindung deaktivieren und löschen", role: .destructive) {
                    CellularKeychain.clear()
                    endpoint = ""
                    secret = ""
                    status = "Deaktiviert"
                }
            }
            Section("Manueller Bereitschaftscheck") {
                Button("Signierten Check senden") {
                    guard !isSending else { return }
                    isSending = true
                    Task {
                        let outcome = await CellularReadinessClient.send()
                        status = outcome
                        isSending = false
                    }
                }
                .disabled(isSending)
                Text(status)
                    .accessibilityIdentifier("igentic-cellular-readiness-result")
            }
        }
        .navigationTitle("Mobilfunk")
        .onAppear {
            endpoint = CellularKeychain.load()?.endpoint ?? ""
        }
    }
}
#endif
