import AppIntentsTesting
import XCTest

/// Out-of-process system-level integration test, not an in-app direct call.
@available(iOS 27.0, *)
final class iGenticAppIntentsTests: XCTestCase {
    @MainActor
    func testReadOnlyDiagnosticsIntentRunsThroughSystem() async throws {
        // Apple's AppIntentsTesting setup requires the owning app to have
        // launched before asking the system for its registered definitions.
        // This only opens our fixed read-only diagnostics app in the simulator.
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
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

    @MainActor
    func testLocalModelReadinessIntentRunsWithoutMacOrGeneration() async throws {
        // The actual system App Intents path, not an in-process direct perform().
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        let codes: Set<String> = [
            "available", "notConfigured", "disabledByPolicy", "unsupportedPlatform",
            "deviceNotEligible", "appleIntelligenceNotEnabled", "modelNotReady",
            "unsupportedLocale", "unknownSystemCondition"
        ]
        let prefix = "iGentic local AI readiness: "
        let suffix = ". No prompt was processed or sent. This is not a device health check."
        for _ in 0..<2 {
            var returned: String?
            // Cold installs can register the owning app's metadata a little
            // after the first foreground launch. Retry only that precise
            // transient system registration code, never arbitrary failures.
            for attempt in 0..<6 {
                do {
                    let definitions = IntentDefinitions(bundleIdentifier: "org.example.iGenticDiagnostics")
                    let readiness = definitions.intents["iGenticLocalModelReadinessIntent"]
                    let result = try await readiness.makeIntent().run()
                    returned = try result.value.as(String.self)
                    break
                } catch {
                    let failure = error as NSError
                    guard failure.domain == "AppIntentsServicesMetadataErrorDomain",
                          failure.code == 400, attempt < 5 else { throw error }
                    try await Task.sleep(for: .seconds(2))
                }
            }
            let output = try XCTUnwrap(returned)
            XCTAssertTrue(output.hasPrefix(prefix), output)
            XCTAssertTrue(output.hasSuffix(suffix), output)
            let code = String(output.dropFirst(prefix.count).dropLast(suffix.count))
            XCTAssertTrue(codes.contains(code), "Unknown readiness code")
        }
    }
}
