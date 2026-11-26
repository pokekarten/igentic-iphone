import XCTest
@testable import iGenticApp

final class DiagnosticModelRouterTests: XCTestCase {
    func testAllSelectionCombinations() {
        for apple in [false, true] {
            for consent in [false, true] {
                for admitted in [false, true] {
                    let eligible = consent && admitted
                    XCTAssertEqual(DiagnosticModelRouter.select(preference: .automatic, appleReady: apple, qwenOptIn: consent, qwenArtifactAdmitted: admitted), apple ? .apple : (eligible ? .qwen : .unavailable))
                    XCTAssertEqual(DiagnosticModelRouter.select(preference: .apple, appleReady: apple, qwenOptIn: consent, qwenArtifactAdmitted: admitted), apple ? .apple : .unavailable)
                    XCTAssertEqual(DiagnosticModelRouter.select(preference: .qwen, appleReady: apple, qwenOptIn: consent, qwenArtifactAdmitted: admitted), eligible ? .qwen : .unavailable)
                }
            }
        }
    }

    @MainActor
    func testNoProviderReplayAfterFailure() async {
        enum Failure: Error { case expected }
        var apple = 0, qwen = 0
        do {
            let _: Int? = try await DiagnosticModelRouter.dispatch(.apple, apple: {
                apple += 1
                throw Failure.expected
            }, qwen: { qwen += 1; return 2 })
            XCTFail("Expected failure")
        } catch { }
        XCTAssertEqual(apple, 1)
        XCTAssertEqual(qwen, 0)
        let result = await DiagnosticModelRouter.dispatch(.qwen, apple: {
            apple += 1; return 1
        }, qwen: { qwen += 1; return 2 })
        XCTAssertEqual(result, 2)
        let unavailable = await DiagnosticModelRouter.dispatch(.unavailable, apple: {
            apple += 1; return 1
        }, qwen: { qwen += 1; return 2 })
        XCTAssertNil(unavailable)
        XCTAssertEqual(apple, 1)
        XCTAssertEqual(qwen, 1)
    }
}
