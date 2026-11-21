import AppIntentsTesting
import XCTest

/// Out-of-process system-level integration test, not an in-app direct call.
@available(iOS 27.0, *)
final class iGenticAppIntentsTests: XCTestCase {
    func testReadOnlyDiagnosticsIntentRunsThroughSystem() async throws {
        let definitions = IntentDefinitions(bundleIdentifier: "org.example.iGenticDiagnostics")
        let diagnostics = definitions.intents["iGenticReadOnlyDiagnosticsIntent"]
        // Repeated system dispatch must remain deterministic and read-only.
        // This exercise is intentionally limited to synthetic fixed output.
        for _ in 0..<3 {
            let result = try await diagnostics.makeIntent().run()
            let output = try result.value.as(String.self)
            XCTAssertEqual(
                output,
                "iGentic diagnostics shortcut is available. This is a fixed demo response, not a device health check. No personal data was accessed."
            )
        }
    }
}
