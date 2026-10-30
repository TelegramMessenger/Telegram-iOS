import XCTest
import UIKit
import Display
import StaticGlassBackground
@testable import UnsupportedContentPill

private let testStrings = UnsupportedContentPillStrings(
    title: "Unsupported message",
    text: "Please update Telegram to view this message.",
    action: "Update"
)

private let accent = UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0)
private let accentForeground = UIColor.white
private let secondaryText = UIColor(white: 0.5, alpha: 1.0)

private let plateColors = UnsupportedContentPillColors(
    fill: UIColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1.0),
    primaryText: .white,
    isDark: true
)

private let outlinedColors = UnsupportedContentPillColors(
    fill: .clear,
    primaryText: .black,
    isDark: false,
    style: .outlined(secondaryText: secondaryText, accent: accent, accentForeground: accentForeground)
)

private func update(_ view: UnsupportedContentPillView, colors: UnsupportedContentPillColors, width: CGFloat = 320.0) -> (UnsupportedContentPillLayout, CGSize) {
    let layout = UnsupportedContentPill.layout(strings: testStrings, colors: colors, constrainedWidth: width)
    let size = CGSize(width: width, height: layout.size.height)
    view.frame = CGRect(origin: CGPoint(), size: size)
    view.update(layout: layout, colors: colors, strings: testStrings, size: size, wallpaperBackgroundNode: nil, animation: .None)
    return (layout, size)
}

// A chat without bubbles stands the pill in a strip it frames itself: no plate, no room of the pill's own around its
// content, the badge in glass tinted with the accent and the button in light glass.
final class UnsupportedContentPillOutlinedTests: XCTestCase {
    func testOutlinedPillHasNoRoomAroundItsContent() {
        let layout = UnsupportedContentPill.layout(strings: testStrings, colors: outlinedColors, constrainedWidth: 600.0)
        XCTAssertEqual(layout.size.height, pillBadgeDiameter)
        XCTAssertEqual(layout.actionFrame(in: CGSize(width: 300.0, height: layout.size.height)).maxX, 300.0)
    }

    func testOutlinedPillStartsItsBadgeAtTheLeadingEdge() {
        let view = UnsupportedContentPillView()
        _ = update(view, colors: outlinedColors)
        let badge = view.subviews.compactMap({ $0 as? UIImageView }).first
        XCTAssertEqual(badge?.frame.minX, 0.0)
    }

    func testOutlinedPillPutsItsBadgeAndButtonOnGlass() {
        let view = UnsupportedContentPillView()
        _ = update(view, colors: outlinedColors)
        let imageViews = view.subviews.compactMap({ $0 as? UIImageView })
        // The badge's own fill gives way to glass at its frame; the glyph keeps the accent's foreground.
        XCTAssertEqual(imageViews.first?.isHidden, true)
        XCTAssertEqual(imageViews.last?.tintColor, accentForeground)
        let glassViews = view.subviews.compactMap({ $0 as? StaticGlassBackgroundView })
        XCTAssertEqual(glassViews.count, 2)
        XCTAssertEqual(glassViews.first?.frame, imageViews.first?.frame)
        let button = view.subviews.compactMap({ $0 as? HighlightTrackingButton }).first
        XCTAssertEqual(button?.backgroundColor, .clear)
        XCTAssertEqual(glassViews.last?.frame, button?.frame)
    }
    
    // Back to a plate, the glass goes.
    func testGlassGoesWithTheOutlinedStyle() {
        let view = UnsupportedContentPillView()
        _ = update(view, colors: outlinedColors)
        _ = update(view, colors: plateColors)
        XCTAssertTrue(view.subviews.compactMap({ $0 as? StaticGlassBackgroundView }).isEmpty)
        XCTAssertEqual(view.subviews.compactMap({ $0 as? UIImageView }).first?.isHidden, false)
    }

    func testOutlinedPillHasNoPlate() {
        let view = UnsupportedContentPillView()
        _ = update(view, colors: outlinedColors)
        XCTAssertEqual(view.subviews.first?.isHidden, true)
    }

    func testPlateReturnsAfterTheOutlinedStyle() {
        let view = UnsupportedContentPillView()
        _ = update(view, colors: outlinedColors)
        _ = update(view, colors: plateColors)
        let plate = view.subviews.first
        XCTAssertEqual(plate?.isHidden, false)
        XCTAssertEqual(plate?.backgroundColor, plateColors.fill)
        let badge = view.subviews.compactMap({ $0 as? UIImageView }).first
        XCTAssertEqual(badge?.frame.minX, pillContentInsets.left)
    }
}
