import XCTest
import UIKit
@testable import Display

/// Where bottom sheets sit beside iPhone Duo's side strip, and that every other device keeps the placement
/// sheets always had.
final class SheetPlacementTests: XCTestCase {
    private let coverPortrait = CGSize(width: 466.0, height: 678.0)
    private let coverLandscape = CGSize(width: 678.0, height: 466.0)

    // MARK: resizableSheetHorizontalPlacement

    func test_resizable_coverPortrait_spansTheScreenAsBefore() {
        let p = resizableSheetHorizontalPlacement(containerSize: self.coverPortrait, safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), maxWidth: nil)
        XCTAssertEqual(p.minX, 0.0)
        XCTAssertEqual(p.width, 466.0)
        // The content sees the insets it always saw.
        XCTAssertEqual(p.contentSideInsets, UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0))
    }

    func test_resizable_coverLandscapeRight_centersInTheBandClearOfTheLeftStrip() {
        let p = resizableSheetHorizontalPlacement(containerSize: self.coverLandscape, safeInsets: UIEdgeInsets(top: 0.0, left: 84.0, bottom: 21.0, right: 0.0), maxWidth: nil)
        XCTAssertEqual(p.width, 382.0)
        XCTAssertEqual(p.minX, 190.0)
        XCTAssertEqual(p.minX + p.width * 0.5, 84.0 + (678.0 - 84.0) * 0.5)
        XCTAssertEqual(p.contentSideInsets, UIEdgeInsets())
    }

    func test_resizable_coverLandscapeLeft_centersInTheBandClearOfTheRightStrip() {
        let p = resizableSheetHorizontalPlacement(containerSize: self.coverLandscape, safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 21.0, right: 84.0), maxWidth: nil)
        XCTAssertEqual(p.width, 382.0)
        XCTAssertEqual(p.minX, 106.0)
        XCTAssertLessThanOrEqual(p.minX + p.width, 678.0 - 84.0)
        XCTAssertEqual(p.contentSideInsets, UIEdgeInsets())
    }

    func test_resizable_unfoldedLandscape_regular_centersInTheBand() {
        let p = resizableSheetHorizontalPlacement(containerSize: CGSize(width: 951.0, height: 669.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 21.0, right: 84.0), maxWidth: 414.0)
        XCTAssertEqual(p.width, 414.0)
        XCTAssertEqual(p.minX, 226.0)
        XCTAssertEqual(p.contentSideInsets, UIEdgeInsets())
    }

    func test_resizable_equalInsets_unchanged() {
        // A notched phone in landscape: narrowed by both insets, centered on the screen, content insets as given.
        let compact = resizableSheetHorizontalPlacement(containerSize: CGSize(width: 932.0, height: 430.0), safeInsets: UIEdgeInsets(top: 0.0, left: 59.0, bottom: 21.0, right: 59.0), maxWidth: nil)
        XCTAssertEqual(compact.width, 430.0 - 118.0)
        XCTAssertEqual(compact.minX, floor((932.0 - 312.0) * 0.5))
        XCTAssertEqual(compact.contentSideInsets, UIEdgeInsets(top: 0.0, left: 59.0, bottom: 0.0, right: 59.0))

        let regular = resizableSheetHorizontalPlacement(containerSize: CGSize(width: 932.0, height: 430.0), safeInsets: UIEdgeInsets(top: 0.0, left: 59.0, bottom: 21.0, right: 59.0), maxWidth: 414.0)
        XCTAssertEqual(regular.width, 414.0 - 118.0)
        XCTAssertEqual(regular.minX, floor((932.0 - 296.0) * 0.5))

        let portrait = resizableSheetHorizontalPlacement(containerSize: CGSize(width: 402.0, height: 874.0), safeInsets: UIEdgeInsets(top: 62.0, left: 0.0, bottom: 34.0, right: 0.0), maxWidth: nil)
        XCTAssertEqual(portrait.width, 402.0)
        XCTAssertEqual(portrait.minX, 0.0)
        XCTAssertEqual(portrait.contentSideInsets, UIEdgeInsets())
    }

    // MARK: sheetContentBandInsets

    func test_contentBand_onlyInLandscapeBesideAStrip() {
        XCTAssertEqual(sheetContentBandInsets(containerSize: self.coverLandscape, safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 21.0, right: 84.0)), UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0))
        XCTAssertEqual(sheetContentBandInsets(containerSize: self.coverLandscape, safeInsets: UIEdgeInsets(top: 0.0, left: 84.0, bottom: 21.0, right: 0.0)), UIEdgeInsets(top: 0.0, left: 84.0, bottom: 0.0, right: 0.0))
        // Folded portrait: a bottom panel across the strip, as before.
        XCTAssertNil(sheetContentBandInsets(containerSize: self.coverPortrait, safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0)))
        // Equal insets: unchanged.
        XCTAssertNil(sheetContentBandInsets(containerSize: CGSize(width: 932.0, height: 430.0), safeInsets: UIEdgeInsets(top: 0.0, left: 59.0, bottom: 21.0, right: 59.0)))
    }

    // MARK: sheetHeaderCornerInsets

    private let portraitCorners = ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 84.0, height: 170.0), bottomLeft: nil, bottomRight: nil)

    func test_header_tallSheetInPortrait_clearsTheStatusCorner() {
        let insets = sheetHeaderCornerInsets(containerWidth: 466.0, sheetMinX: 0.0, sheetWidth: 466.0, sheetMinY: 58.0, reservedCorners: self.portraitCorners)
        XCTAssertEqual(insets, UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0))
    }

    func test_header_shortSheetInPortrait_keepsItsLayout() {
        let insets = sheetHeaderCornerInsets(containerWidth: 466.0, sheetMinX: 0.0, sheetWidth: 466.0, sheetMinY: 400.0, reservedCorners: self.portraitCorners)
        XCTAssertEqual(insets, UIEdgeInsets())
    }

    func test_header_sheetInTheBand_clearOfTheBlock() {
        let corners = ContainerViewLayoutCorners(topLeft: CGSize(width: 84.0, height: 84.0), topRight: nil, bottomLeft: nil, bottomRight: nil)
        let insets = sheetHeaderCornerInsets(containerWidth: 678.0, sheetMinX: 190.0, sheetWidth: 382.0, sheetMinY: 10.0, reservedCorners: corners)
        XCTAssertEqual(insets, UIEdgeInsets())
    }

    func test_header_noCorners_unchanged() {
        XCTAssertEqual(sheetHeaderCornerInsets(containerWidth: 402.0, sheetMinX: 0.0, sheetWidth: 402.0, sheetMinY: 72.0, reservedCorners: .none), UIEdgeInsets())
    }
}
