import AppIntentsTesting
import Foundation
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

    @MainActor
    func testDeterministicLocalStatusLoopRunsThroughSystem() async throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        // Exercise the real registered intent, not the Swift store directly.
        // No model API, network delegate, Mac worker or write action is needed.
        // Two completed tasks must have different correlation IDs.
        var previousTaskID: String?
        for _ in 0..<2 {
            let definitions = IntentDefinitions(bundleIdentifier: "org.example.iGenticDiagnostics")
            let intent = definitions.intents["iGenticRunLocalStatusLoopIntent"]
            let output = try await intent.makeIntent().run().value.as(String.self)
            let payload = try XCTUnwrap(
                JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any]
            )
            XCTAssertEqual(payload["schema"] as? Int, 1)
            XCTAssertEqual(payload["stage"] as? String, "finished")
            XCTAssertEqual(payload["localStatusRead"] as? Bool, true)
            XCTAssertEqual(payload["remoteActionExecuted"] as? Bool, false)
            XCTAssertEqual(payload["ownerApproved"] as? Bool, false)
            XCTAssertNil(payload["nextPrompt"])
            let taskID = try XCTUnwrap(payload["taskId"] as? String)
            XCTAssertEqual(UUID(uuidString: taskID)?.uuidString.lowercased(), taskID)
            XCTAssertNotEqual(previousTaskID, taskID)
            previousTaskID = taskID
            let observation = try XCTUnwrap(payload["observation"] as? String)
            XCTAssertTrue(observation.contains("iGentic iPhone: Akku"))
            XCTAssertTrue(observation.contains("ChatGPT-Verbindung nicht geprüft"))
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
