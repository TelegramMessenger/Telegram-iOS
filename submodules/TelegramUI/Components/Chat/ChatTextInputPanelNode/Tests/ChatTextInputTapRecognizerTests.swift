import XCTest
@testable import ChatTextInputPanelNode

/// The panel's own recognizer takes a tap on the input field while the input node is not loaded yet, and whenever
/// sending text is restricted: the input node is disabled then, and that tap opens the "Boost group to send messages"
/// sheet or the restriction tooltip. The chat loads the input node as it appears, so a recognizer given up once the
/// node was loaded left the restricted field ("Text not allowed") doing nothing (#90).
final class ChatTextInputTapRecognizerTests: XCTestCase {
    func testBeforeTheInputNodeLoadsTheRecognizerTakesTheTap() {
        XCTAssertTrue(textInputTapRecognizerIsEnabled(isInputNodeLoaded: false, sendingTextDisabled: false))
        XCTAssertTrue(textInputTapRecognizerIsEnabled(isInputNodeLoaded: false, sendingTextDisabled: true))
    }

    func testRestrictedTextKeepsTheTapOnceTheInputNodeIsLoaded() {
        XCTAssertTrue(textInputTapRecognizerIsEnabled(isInputNodeLoaded: true, sendingTextDisabled: true))
    }

    func testAnEnabledInputNodeTakesItsOwnTaps() {
        XCTAssertFalse(textInputTapRecognizerIsEnabled(isInputNodeLoaded: true, sendingTextDisabled: false))
    }
}
