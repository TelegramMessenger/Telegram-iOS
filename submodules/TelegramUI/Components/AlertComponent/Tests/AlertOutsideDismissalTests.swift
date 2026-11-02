import XCTest
@testable import AlertComponent

/// Dismissing an alert without an action (outside tap, Escape key, VoiceOver escape) follows `dismissOnOutsideTap` and is
/// reported as an outside tap, so hosts that finish a request only then (web alert/confirm panels) are not left hanging.
final class AlertOutsideDismissalTests: XCTestCase {
    func testAllowedDismissalMarksOutsideTapBeforeDismissing() {
        var events: [String] = []
        let result = AlertOutsideDismissal.perform(configuration: AlertScreen.Configuration(dismissOnOutsideTap: true), markDismissedByOutsideTap: {
            events.append("mark")
        }, dismiss: {
            events.append("dismiss")
        })
        XCTAssertTrue(result)
        XCTAssertEqual(events, ["mark", "dismiss"])
    }

    func testDisallowedDismissalDoesNothing() {
        var events: [String] = []
        let result = AlertOutsideDismissal.perform(configuration: AlertScreen.Configuration(dismissOnOutsideTap: false), markDismissedByOutsideTap: {
            events.append("mark")
        }, dismiss: {
            events.append("dismiss")
        })
        XCTAssertFalse(result)
        XCTAssertTrue(events.isEmpty)
    }
}
