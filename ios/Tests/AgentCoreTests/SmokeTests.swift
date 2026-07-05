@@
         let results = ScenarioRunner().runAll()
 
         XCTAssertEqual(
             results.map(\..scenarioID),
-            ["local-only-summary", "critical-reminder", "external-provider-check", "safe-metadata-local"]
+            ["local-only-summary", "critical-reminder", "external-provider-check", "trusted-device-metadata"]
         )
     }
 }
