import AppIntentsTesting
import XCTest

/// Out-of-process system-level integration test, not an in-app direct call.
@available(iOS 27.0, *)
final class iGenticAppIntentsTests: XCTestCase {
    @MainActor
    func testReadOnlyDeviceStatusIntentRunsThroughSystem() async throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        let definitions = IntentDefinitions(bundleIdentifier: "org.example.iGenticDiagnostics")
        let status = definitions.intents["iGenticDeviceStatusIntent"]
        let value = try await status.makeIntent().run().value.as(String.self)
        XCTAssertTrue(value.contains("iGentic iPhone: Akku"))
        XCTAssertTrue(value.contains("Stromsparmodus"))
        XCTAssertTrue(value.contains("ChatGPT-Verbindung nicht geprüft"))
        XCTAssertFalse(value.lowercased().contains("serial"))
    }

    @MainActor
    func testReadOnlyDiagnosticsIntentRunsThroughSystem() async throws {
        // Apple's AppIntentsTesting setup requires the owning app to have
        // launched before asking the system for its registered definitions.
        // This only opens our fixed read-only diagnostics app in the simulator.
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        // System metadata registration may lag the first foreground launch
        // on a cold simulator. Retry ONLY Apple's documented observed
        // registration-unavailable signal; never suppress unrelated failures.
        // All three actual dispatches must still complete and match exactly.
        for _ in 0..<3 {
            var output: String?
            for attempt in 0..<6 {
                do {
                    let definitions = IntentDefinitions(bundleIdentifier: "org.example.iGenticDiagnostics")
                    let diagnostics = definitions.intents["iGenticReadOnlyDiagnosticsIntent"]
                    let result = try await diagnostics.makeIntent().run()
                    output = try result.value.as(String.self)
                    break
                } catch {
                    let failure = error as NSError
                    guard failure.domain == "AppIntentsServicesMetadataErrorDomain",
                          failure.code == 400, attempt < 5 else { throw error }
                    try await Task.sleep(for: .seconds(2))
                }
            }
            XCTAssertEqual(
                try XCTUnwrap(output),
                "iGentic diagnostics shortcut is available. This is a fixed demo response, not a device health check. No personal data was accessed."
            )
        }
    }
}
