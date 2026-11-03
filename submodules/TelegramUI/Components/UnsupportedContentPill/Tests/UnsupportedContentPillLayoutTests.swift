import XCTest
import UIKit
@testable import UnsupportedContentPill

// The strings are built through the memberwise init on purpose. `PresentationStrings` can only be
// obtained from `defaultPresentationStrings`, which force-unwraps a `Localizable.strings` lookup in
// the APP bundle and is not safe to touch from a unit-test bundle — which is exactly why the
// component takes resolved strings rather than a `PresentationStrings`.
private let testStrings = UnsupportedContentPillStrings(
    title: "Unsupported message",
    text: "Please update Telegram to view this message.",
    action: "Update"
)

private let testColors = UnsupportedContentPillColors(
    fill: UIColor(white: 0.0, alpha: 0.1),
    primaryText: .white,
    isDark: true
)

final class UnsupportedContentPillLayoutTests: XCTestCase {
    /// The badge is 44pt and the content insets are 6/8, so a pill whose text and button both fit
    /// inside the badge's height is exactly 58pt tall. This pins the vertical rhythm the chat
    /// bubble has today — a change here is a visible change in every unsupported message.
    func testShortContentIsBadgeHeightPlusInsets() {
        let layout = UnsupportedContentPill.layout(strings: testStrings, colors: testColors, constrainedWidth: 600.0)
        XCTAssertEqual(layout.size.height, 58.0)
    }

    /// The intrinsic width is the badge + gaps + button + insets ("fixed width") plus the text
    /// column, so it must exceed the fixed part even with empty text.
    func testIntrinsicWidthExceedsTheFixedFurniture() {
        let empty = UnsupportedContentPillStrings(title: "", text: "", action: "Update")
        let layout = UnsupportedContentPill.layout(strings: empty, colors: testColors, constrainedWidth: 600.0)
        // 12 (left inset) + 44 (badge) + 12 (badge→text) + 12 (text→button) + 12 (right inset) = 92,
        // plus the measured "Update" button, which is non-empty.
        XCTAssertGreaterThan(layout.size.width, 92.0)
    }

    /// Longer text asks for more width, up to the constraint.
    func testLongerTitleAsksForMoreWidth() {
        let short = UnsupportedContentPill.layout(strings: testStrings, colors: testColors, constrainedWidth: 1000.0)
        let long = UnsupportedContentPill.layout(
            strings: UnsupportedContentPillStrings(title: String(repeating: "Unsupported ", count: 4), text: testStrings.text, action: testStrings.action),
            colors: testColors,
            constrainedWidth: 1000.0
        )
        XCTAssertGreaterThan(long.size.width, short.size.width)
    }

    /// Under a narrow constraint the subtitle wraps instead of overflowing: the pill grows taller
    /// than the badge and never wider than it was allowed.
    func testNarrowConstraintWrapsRatherThanOverflows() {
        let layout = UnsupportedContentPill.layout(strings: testStrings, colors: testColors, constrainedWidth: 220.0)
        XCTAssertLessThanOrEqual(layout.size.width, 220.0)
        XCTAssertGreaterThan(layout.size.height, 58.0)
    }

    /// The view re-derives its text through the same function, so the same inputs must produce the
    /// same numbers every time — otherwise a re-layout could disagree with the host's measure pass.
    func testLayoutIsDeterministic() {
        let a = UnsupportedContentPill.layout(strings: testStrings, colors: testColors, constrainedWidth: 320.0)
        let b = UnsupportedContentPill.layout(strings: testStrings, colors: testColors, constrainedWidth: 320.0)
        XCTAssertEqual(a, b)
    }
}
