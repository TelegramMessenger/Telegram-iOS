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

    // MARK: sheetBandPlacement

    func test_band_unfoldedLandscape_sheetKeepsClearOfTheRightStrip() {
        // The status corner (84x120) is at the top of the right strip: the whole sheet, not only its content,
        // stays left of it, so the content is centred on the sheet and nothing of the sheet runs under the block.
        let p = sheetBandPlacement(containerSize: CGSize(width: 951.0, height: 669.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 21.0, right: 84.0))
        XCTAssertEqual(p?.minX, 0.0)
        XCTAssertEqual(p?.width, 867.0)
        XCTAssertEqual(p?.contentSideInsets, UIEdgeInsets())
    }

    func test_band_coverLandscape_sheetKeepsToTheBand() {
        let left = sheetBandPlacement(containerSize: self.coverLandscape, safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 21.0, right: 84.0))
        XCTAssertEqual(left?.minX, 0.0)
        XCTAssertEqual(left?.width, 594.0)
        XCTAssertEqual(left?.contentSideInsets, UIEdgeInsets())
        let right = sheetBandPlacement(containerSize: self.coverLandscape, safeInsets: UIEdgeInsets(top: 0.0, left: 84.0, bottom: 21.0, right: 0.0))
        XCTAssertEqual(right?.minX, 84.0)
        XCTAssertEqual(right?.width, 594.0)
        XCTAssertEqual(right?.contentSideInsets, UIEdgeInsets())
    }

    func test_band_portraitAndEqualInsets_spanTheContainerAsBefore() {
        // Folded portrait: a bottom panel across the strip, as before.
        XCTAssertNil(sheetBandPlacement(containerSize: self.coverPortrait, safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0)))
        // Unfolded portrait: no side insets.
        XCTAssertNil(sheetBandPlacement(containerSize: CGSize(width: 669.0, height: 951.0), safeInsets: UIEdgeInsets(top: 82.0, left: 0.0, bottom: 20.0, right: 0.0)))
        // A notched phone in landscape (equal insets): unchanged.
        XCTAssertNil(sheetBandPlacement(containerSize: CGSize(width: 932.0, height: 430.0), safeInsets: UIEdgeInsets(top: 0.0, left: 59.0, bottom: 21.0, right: 59.0)))
    }

    // MARK: sheetRestingScrollOffset

    func test_resting_sheetThatFits_bottomAtTheContainersBottomAsBefore() {
        // The scroll offset that puts the sheet's bottom at the container's bottom: -(container - content).
        XCTAssertEqual(sheetRestingScrollOffset(contentHeight: 500.0, containerHeight: 874.0, keepsBottomVisible: false), -374.0)
        XCTAssertEqual(sheetRestingScrollOffset(contentHeight: 669.0, containerHeight: 669.0, keepsBottomVisible: false), 0.0)
    }

    func test_resting_sheetTallerThanTheContainer_topAtTheContainersTop() {
        // Unfolded landscape, the report reasons (#79): resting on its bottom, it opened with its header 46pt above
        // the screen.
        XCTAssertEqual(sheetRestingScrollOffset(contentHeight: 715.0, containerHeight: 669.0, keepsBottomVisible: false), 0.0)
    }

    func test_resting_withTheKeyboard_keepsTheBottomInView() {
        // A sheet that grew by the keyboard's height keeps what is above the keyboard (the text field) in view; one
        // that cannot scroll keeps its bottom (its action) in view.
        XCTAssertEqual(sheetRestingScrollOffset(contentHeight: 900.0, containerHeight: 669.0, keepsBottomVisible: true), 231.0)
        XCTAssertEqual(sheetRestingScrollOffset(contentHeight: 500.0, containerHeight: 669.0, keepsBottomVisible: true), -169.0)
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

    // MARK: centeredSheetFrame

    func test_centered_iPadLandscape_halfTheLongerSideAcross_centered() {
        let f = centeredSheetFrame(containerSize: CGSize(width: 1180.0, height: 820.0), contentHeight: 400.0)
        XCTAssertEqual(f, CGRect(x: 295.0, y: 210.0, width: 590.0, height: 400.0))
    }

    func test_centered_iPadPortrait_sameWidthAsInLandscape() {
        let f = centeredSheetFrame(containerSize: CGSize(width: 820.0, height: 1180.0), contentHeight: 400.0)
        XCTAssertEqual(f, CGRect(x: 115.0, y: 390.0, width: 590.0, height: 400.0))
    }

    func test_centered_tallContent_keeps44ptAboveAndBelow() {
        let f = centeredSheetFrame(containerSize: CGSize(width: 1180.0, height: 820.0), contentHeight: 2000.0)
        XCTAssertEqual(f, CGRect(x: 295.0, y: 44.0, width: 590.0, height: 732.0))
    }

    func test_centered_narrowContainer_keeps10ptOnEachSide() {
        // A tall, narrow regular container: narrower than half its longer side allows.
        let f = centeredSheetFrame(containerSize: CGSize(width: 700.0, height: 1500.0), contentHeight: 300.0)
        XCTAssertEqual(f.width, 680.0)
        XCTAssertEqual(f.minX, 10.0)
        XCTAssertEqual(f.minY, 600.0)
    }

    func test_centeredAnchored_atRest_isTheCenteredFrame() {
        let container = CGSize(width: 1180.0, height: 820.0)
        let rest = centeredSheetFrame(containerSize: container, contentHeight: 400.0)
        XCTAssertEqual(centeredSheetFrame(containerSize: container, contentHeight: 400.0, maxY: rest.maxY), rest)
    }

    func test_centeredAnchored_stretchedContent_growsUpwardOnly() {
        // The list rubber-bands 50pt: the card's bottom stays where it rests, its top follows the content.
        let f = centeredSheetFrame(containerSize: CGSize(width: 1180.0, height: 820.0), contentHeight: 450.0, maxY: 610.0)
        XCTAssertEqual(f, CGRect(x: 295.0, y: 160.0, width: 590.0, height: 450.0))
    }

    func test_centeredAnchored_neverRisesAboveTheTallestCard() {
        // Stretched to the tallest card's height from a bottom resting at 681: the top stops at the 44pt margin
        // and the card grows downward instead of running off the screen.
        let f = centeredSheetFrame(containerSize: CGSize(width: 1180.0, height: 820.0), contentHeight: 732.0, maxY: 681.0)
        XCTAssertEqual(f, CGRect(x: 295.0, y: 44.0, width: 590.0, height: 732.0))
    }
}
