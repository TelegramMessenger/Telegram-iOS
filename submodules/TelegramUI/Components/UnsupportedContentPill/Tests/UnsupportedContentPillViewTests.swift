import XCTest
import UIKit
import Display
@testable import UnsupportedContentPill

private let testStrings = UnsupportedContentPillStrings(
    title: "Unsupported message",
    text: "Please update Telegram to view this message.",
    action: "Update"
)

private let testColors = UnsupportedContentPillColors(
    fill: UIColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1.0),
    primaryText: .white,
    isDark: true
)

private func makeUpdatedPill(width: CGFloat = 320.0) -> (UnsupportedContentPillView, UnsupportedContentPillLayout, CGSize) {
    let layout = UnsupportedContentPill.layout(strings: testStrings, colors: testColors, constrainedWidth: width)
    let size = CGSize(width: width, height: layout.size.height)
    let view = UnsupportedContentPillView()
    view.frame = CGRect(origin: CGPoint(), size: size)
    view.update(layout: layout, colors: testColors, strings: testStrings, size: size, wallpaperBackgroundNode: nil, animation: .None)
    return (view, layout, size)
}

final class UnsupportedContentPillViewTests: XCTestCase {
    /// The host arbitrates taps by asking the pill where its button is (the chat bubble's
    /// `tapActionAtPoint`), so the reported region must match where the button was actually placed:
    /// pinned to the trailing inset, vertically centred.
    func testActionRegionCoversTheButtonAndNothingElse() {
        let (view, layout, size) = makeUpdatedPill()

        let buttonCentre = CGPoint(x: size.width - pillContentInsets.right - layout.buttonSize.width / 2.0, y: size.height / 2.0)
        XCTAssertTrue(view.actionContains(buttonCentre))

        // The badge, at the leading inset, is not part of the action region.
        XCTAssertFalse(view.actionContains(CGPoint(x: pillContentInsets.left + pillBadgeDiameter / 2.0, y: size.height / 2.0)))
    }

    /// Tapping the button runs the host's action.
    func testButtonTapInvokesTheAction() {
        let (view, _, _) = makeUpdatedPill()
        var fired = 0
        view.action = { fired += 1 }

        guard let control = view.subviews.compactMap({ $0 as? UIControl }).first else {
            return XCTFail("the pill has no UIControl to tap")
        }
        XCTAssertTrue(control is HighlightTrackingButton)

        // `sendActions(for:)` dispatches through `UIApplication`, which this test runner does not
        // pump, so invoke the registered target/action pairs directly — that registration IS the
        // wiring a real touch would use.
        var invoked = 0
        for target in control.allTargets {
            for actionName in control.actions(forTarget: target, forControlEvent: .touchUpInside) ?? [] {
                _ = (target as AnyObject).perform(Selector(actionName))
                invoked += 1
            }
        }
        XCTAssertEqual(invoked, 1, "expected exactly one touchUpInside action on the pill's button")
        XCTAssertEqual(fired, 1)
    }

    /// The button's label must be sized and centred inside it. A `TextNode` returned by `apply()`
    /// has ZERO bounds until its frame is assigned, so positioning the label from `bounds.size`
    /// rather than from the measured layout collapses it to nothing: the pill renders, the button
    /// renders at the right size and still taps, and the word "Update" is simply invisible.
    func testButtonLabelIsSizedAndCentredInsideTheButton() {
        let (view, layout, _) = makeUpdatedPill()

        guard let control = view.subviews.compactMap({ $0 as? UIControl }).first else {
            return XCTFail("the pill has no UIControl")
        }
        guard let label = control.subviews.first else {
            return XCTFail("the button has no label view")
        }
        XCTAssertGreaterThan(label.frame.width, 0.0)
        XCTAssertGreaterThan(label.frame.height, 0.0)
        XCTAssertEqual(label.frame.midX, layout.buttonSize.width / 2.0, accuracy: 1.0)
        XCTAssertEqual(label.frame.midY, layout.buttonSize.height / 2.0, accuracy: 1.0)
        // The label is the reason the button has the width it does: button = label + 11pt padding.
        XCTAssertEqual(label.frame.width, layout.buttonSize.width - pillButtonHorizontalPadding * 2.0, accuracy: 0.5)
    }

    /// With no wallpaper node the pill paints the static fill itself; without this the pill is
    /// invisible in the send preview and the text-processing screen.
    func testFallbackFillIsPaintedWithoutAWallpaperNode() {
        let (view, _, size) = makeUpdatedPill()
        let filled = view.subviews.first(where: { $0.backgroundColor == testColors.fill })
        XCTAssertNotNil(filled, "expected a background view filled with colors.fill")
        XCTAssertEqual(filled?.frame, CGRect(origin: CGPoint(), size: size))
        // Rounded to a stadium, capped at 22pt — at 320pt wide the subtitle wraps and the pill is
        // taller than 44pt, so this is the capped branch.
        XCTAssertEqual(filled?.layer.cornerRadius, min(size.height / 2.0, pillMaximumCornerRadius))
        XCTAssertEqual(filled?.layer.cornerRadius, pillMaximumCornerRadius)
    }

    /// A second update with the same inputs must not accumulate subviews — the chat bubble calls
    /// `update` on every list apply.
    func testRepeatedUpdatesDoNotAccumulateSubviews() {
        let (view, layout, size) = makeUpdatedPill()
        let countAfterFirst = view.subviews.count
        view.update(layout: layout, colors: testColors, strings: testStrings, size: size, wallpaperBackgroundNode: nil, animation: .None)
        XCTAssertEqual(view.subviews.count, countAfterFirst)
    }

    /// A touch inside the button must hit-test to the BUTTON, not to the label sitting on top of
    /// it. Telegram's bubble-wide tap recognizer bails out of arbitration only when the hit-test
    /// result *is* a `UIButton` (`TapLongTapOrDoubleTapGestureRecognizer.touchesBegan`); with an
    /// interactive label on top the recognizer instead claims the touch and cancels the button's
    /// tracking, so `touchUpInside` never fires and the pill reads as dead.
    func testHitTestInsideTheButtonResolvesToTheButton() {
        let (view, layout, size) = makeUpdatedPill()

        let buttonCentre = CGPoint(x: size.width - pillContentInsets.right - layout.buttonSize.width / 2.0, y: size.height / 2.0)
        let hit = view.hitTest(buttonCentre, with: nil)
        XCTAssertTrue(hit is UIButton, "expected the button, got \(String(describing: hit.map { type(of: $0) }))")
    }

    /// `actionFrame(in:)` is what a host that arbitrates taps from the LAYOUT alone (no view) tests
    /// against, so it must be the same rect the view positions its button at.
    func testActionFrameFromTheLayoutMatchesWhereTheViewPutsTheButton() {
        let (view, layout, size) = makeUpdatedPill()

        guard let control = view.subviews.compactMap({ $0 as? UIControl }).first else {
            return XCTFail("the pill has no UIControl")
        }
        XCTAssertEqual(control.frame, layout.actionFrame(in: size))
        // And the two tap-arbitration entry points agree with each other.
        let frame = layout.actionFrame(in: size)
        XCTAssertTrue(view.actionContains(CGPoint(x: frame.midX, y: frame.midY)))
    }
}
