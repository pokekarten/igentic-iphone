--- a/ios/Tests/AgentCoreTests/SmokeTests.swift
+++ b/ios/Tests/AgentCoreTests/SmokeTests.swift
@@
-        XCTAssertEqual(
-            results.map(\.scenarioID),
-            ["local-only-summary", "critical-reminder", "external-provider-check", "safe-metadata-local"]
-        )
+        XCTAssertEqual(
+            results.map(\.scenarioID),
+            ["local-only-summary", "critical-reminder", "external-provider-check", "trusted-device-metadata"]
+        )
