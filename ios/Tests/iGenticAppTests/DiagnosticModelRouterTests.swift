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
    func testCancelledAttemptNeverStartsAnyProvider() async {
        for selection in [DiagnosticModelRouter.Selection.apple, .qwen, .unavailable] {
            let task = Task { @MainActor in
                withUnsafeCurrentTask { $0?.cancel() }
                do {
                    let _: Int? = try await DiagnosticModelRouter.dispatch(selection, apple: {
                        XCTFail("Cancelled attempt started Apple"); return 1
                    }, qwen: {
                        XCTFail("Cancelled attempt started Qwen"); return 2
                    })
                    XCTFail("Cancellation must not be reported as a successful or unavailable route")
                } catch is CancellationError {
                    // Expected before either provider can run.
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
            }
            await task.value
        }
    }

    @MainActor
    func testQwenFailureNeverReplaysViaApple() async {
        enum Failure: Error { case expected }
        var qwenCalls = 0
        do {
            let _: Int? = try await DiagnosticModelRouter.dispatch(.qwen, apple: {
                XCTFail("Qwen failure replayed through Apple"); return 1
            }, qwen: {
                qwenCalls += 1
                throw Failure.expected
            })
            XCTFail("Expected failure")
        } catch Failure.expected {
            XCTAssertEqual(qwenCalls, 1)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    @MainActor
    func testNoProviderReplayAfterFailure() async throws {
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
        let result = try await DiagnosticModelRouter.dispatch(.qwen, apple: {
            apple += 1; return 1
        }, qwen: { qwen += 1; return 2 })
        XCTAssertEqual(result, 2)
        let unavailable = try await DiagnosticModelRouter.dispatch(.unavailable, apple: {
            apple += 1; return 1
        }, qwen: { qwen += 1; return 2 })
        XCTAssertNil(unavailable)
        XCTAssertEqual(apple, 1)
        XCTAssertEqual(qwen, 1)
    }
}
