import XCTest
@testable import iGenticApp

final class OfflineDictationGateTests: XCTestCase {
    func testOnlyLocalAvailableAuthorizedIdleRecognitionIsAdmitted() {
        let result = OfflineDictationGate.decide(
            supportsOnDevice: true,
            recognizerAvailable: true,
            speechAuthorized: true,
            microphoneAuthorized: true,
            busy: false
        )
        XCTAssertEqual(result, .admitted)
    }

    func testAnyMissingPrerequisiteFailsClosed() {
        let cases: [(Bool, Bool, Bool, Bool, Bool, OfflineDictationGateDecision)] = [
            (false, true, true, true, false, .offlineRecognizerUnavailable),
            (true, false, true, true, false, .offlineRecognizerUnavailable),
            (true, true, false, true, false, .speechPermissionDenied),
            (true, true, true, false, false, .microphonePermissionDenied),
            (true, true, true, true, true, .alreadyBusy),
            (false, false, false, false, true, .alreadyBusy)
        ]
        for (offline, available, speech, microphone, busy, expected) in cases {
            XCTAssertEqual(
                OfflineDictationGate.decide(
                    supportsOnDevice: offline,
                    recognizerAvailable: available,
                    speechAuthorized: speech,
                    microphoneAuthorized: microphone,
                    busy: busy
                ),
                expected
            )
        }
    }

    func testNoNetworkOrModelOverrideExistsInGate() {
        let disabled = OfflineDictationGate.decide(
            supportsOnDevice: false, recognizerAvailable: true,
            speechAuthorized: true, microphoneAuthorized: true, busy: false
        )
        XCTAssertNotEqual(disabled, .admitted)
    }
}
