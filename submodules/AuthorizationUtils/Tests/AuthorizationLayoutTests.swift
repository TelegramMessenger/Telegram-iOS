import XCTest
import UIKit
import Display
import AuthorizationUtils

// The login password screen's column (AuthorizationSequencePasswordEntryControllerNode) laid out above the keyboard,
// with the sizes measured on the simulators (issue #50). Above a short screen's keyboard the monkey animation does not
// fit: kept above the issue's 275pt keyboard, it left "Forgot password?" 1pt below the field's line. The screen drops
// the animation when `authorizationLayoutItemsFit` says the column does not fit, and the spacers then get their share.
final class AuthorizationLayoutTests: XCTestCase {
    private final class Column {
        let animation = UIView()
        let separator = UIView()
        let forgot = UIView()
        let reset = UIView()
        let items: [AuthorizationLayoutItem]

        // The item specs mirror the password entry screen's `containerLayoutUpdated` (title, notice, field, its line,
        // Forgot password, Reset Account, which it shows with `suggestReset` as in the issue, and the animation first
        // when it is shown).
        init(noticeHeight: CGFloat, withAnimation: Bool) {
            let none = AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)
            var items: [AuthorizationLayoutItem] = [
                AuthorizationLayoutItem(view: UIView(), size: CGSize(width: 188.0, height: 33.0), spacingBefore: AuthorizationLayoutItemSpacing(weight: 18.0, maxValue: 18.0), spacingAfter: none),
                AuthorizationLayoutItem(view: UIView(), size: CGSize(width: 300.0, height: noticeHeight), spacingBefore: AuthorizationLayoutItemSpacing(weight: 18.0, maxValue: 18.0), spacingAfter: none),
                AuthorizationLayoutItem(view: UIView(), size: CGSize(width: 300.0, height: 44.0), spacingBefore: AuthorizationLayoutItemSpacing(weight: 32.0, maxValue: 60.0), spacingAfter: none),
                AuthorizationLayoutItem(view: self.separator, size: CGSize(width: 334.0, height: 1.0 / 3.0), spacingBefore: none, spacingAfter: none),
                AuthorizationLayoutItem(view: self.forgot, size: CGSize(width: 130.0, height: 19.0), spacingBefore: AuthorizationLayoutItemSpacing(weight: 48.0, maxValue: 100.0), spacingAfter: none),
                AuthorizationLayoutItem(view: self.reset, size: CGSize(width: 106.0, height: 19.0), spacingBefore: AuthorizationLayoutItemSpacing(weight: 10.0, maxValue: 10.0), spacingAfter: none)
            ]
            if withAnimation {
                items.insert(AuthorizationLayoutItem(view: self.animation, size: CGSize(width: 100.0, height: 100.0), spacingBefore: AuthorizationLayoutItemSpacing(weight: 10.0, maxValue: 10.0), spacingAfter: none), at: 0)
            }
            self.items = items
        }

        func layout(bounds: CGRect) {
            let _ = layoutAuthorizationItems(bounds: bounds, items: self.items, transition: .immediate, failIfDoesNotFit: false)
        }

        var forgotGap: CGFloat {
            return self.forgot.frame.minY - self.separator.frame.maxY
        }
    }

    // The column's bounds as the screen computes them: from the status bar (with the animation) or the navigation bar
    // (without it) down to the keyboard, less the 110pt kept for the Continue button.
    private func bounds(width: CGFloat, height: CGFloat, top: CGFloat, keyboardHeight: CGFloat) -> CGRect {
        return CGRect(x: 0.0, y: top, width: width, height: height - top - keyboardHeight - 110.0)
    }

    private func assertSpacedColumn(width: CGFloat, height: CGFloat, statusBarHeight: CGFloat, navigationBarHeight: CGFloat, keyboardHeight: CGFloat, noticeHeight: CGFloat, animationFits: Bool, file: StaticString = #filePath, line: UInt = #line) {
        let withAnimation = Column(noticeHeight: noticeHeight, withAnimation: true)
        let animationBounds = self.bounds(width: width, height: height, top: statusBarHeight, keyboardHeight: keyboardHeight)
        let fits = authorizationLayoutItemsFit(height: animationBounds.height, items: withAnimation.items)
        XCTAssertEqual(fits, animationFits, "animation fits", file: file, line: line)

        // As the screen does: the animation stays when the fit check says so.
        let column = fits ? withAnimation : Column(noticeHeight: noticeHeight, withAnimation: false)
        let bounds = fits ? animationBounds : self.bounds(width: width, height: height, top: navigationBarHeight, keyboardHeight: keyboardHeight)
        column.layout(bounds: bounds)

        XCTAssertGreaterThanOrEqual(column.forgotGap, 20.0, "Forgot password's gap below the field", file: file, line: line)
        XCTAssertLessThanOrEqual(column.reset.frame.maxY, bounds.maxY, "the column ends above the Continue button", file: file, line: line)
    }

    // iPhone Duo unfolded, landscape (951x669), keyboard 220pt (the simulator's): the animation is dropped.
    func test_duoUnfoldedLandscape_dropsTheAnimation_spacesTheButtons() {
        self.assertSpacedColumn(width: 951.0, height: 669.0, statusBarHeight: 20.0, navigationBarHeight: 60.0, keyboardHeight: 220.0, noticeHeight: 45.0, animationFits: false)
    }

    // The same with the issue's 275pt keyboard (its Continue button's position), where a kept animation leaves Forgot
    // password 1pt.
    func test_duoUnfoldedLandscapeTallKeyboard_dropsTheAnimation_spacesTheButtons() {
        self.assertSpacedColumn(width: 951.0, height: 669.0, statusBarHeight: 20.0, navigationBarHeight: 60.0, keyboardHeight: 275.0, noticeHeight: 45.0, animationFits: false)
    }

    // iPhone Duo folded, portrait (466x678), keyboard 265pt: the animation is dropped.
    func test_duoFoldedPortrait_dropsTheAnimation_spacesTheButtons() {
        self.assertSpacedColumn(width: 466.0, height: 678.0, statusBarHeight: 2.0, navigationBarHeight: 62.0, keyboardHeight: 265.0, noticeHeight: 67.0, animationFits: false)
    }

    // iPhone 18 Pro (402x874), keyboard 328pt: the animation fits and stays.
    func test_iPhone18Pro_keepsTheAnimation_spacesTheButtons() {
        self.assertSpacedColumn(width: 402.0, height: 874.0, statusBarHeight: 54.0, navigationBarHeight: 114.0, keyboardHeight: 328.0, noticeHeight: 67.0, animationFits: true)
    }

    // The issue's screenshot: kept above the unfolded screen's 275pt keyboard, the animation leaves Forgot password no
    // gap.
    func test_duoUnfoldedLandscape_keptAnimation_squeezesTheButtons() {
        let column = Column(noticeHeight: 45.0, withAnimation: true)
        column.layout(bounds: self.bounds(width: 951.0, height: 669.0, top: 20.0, keyboardHeight: 275.0))
        XCTAssertLessThan(column.forgotGap, 5.0)
    }
}
