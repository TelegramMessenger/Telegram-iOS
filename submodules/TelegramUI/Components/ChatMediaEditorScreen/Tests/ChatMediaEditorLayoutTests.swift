import XCTest
import UIKit
import ChatMediaEditorScreen

final class ChatMediaEditorLayoutTests: XCTestCase {
    let size = CGSize(width: 393.0, height: 852.0)
    let insets = UIEdgeInsets(top: 59.0, left: 0.0, bottom: 34.0, right: 0.0)

    func testGalleryPhotoIsCenteredOnTheScreenLikeLegacy() {
        let layout = chatMediaEditorLayout(size: size, safeInsets: insets, mediaSize: CGSize(width: 4032.0, height: 3024.0), toolbarHeight: 48.0, captionPanelHeight: 52.0, keyboardHeight: 0.0)
        XCTAssertEqual(layout.toolbarFrame.maxY, 852.0 - 34.0)
        XCTAssertEqual(layout.captionPanelFrame.maxY, layout.toolbarFrame.minY)
        XCTAssertEqual(layout.previewFrame.width, 393.0)
        XCTAssertEqual(layout.previewFrame.height / layout.previewFrame.width, 0.75, accuracy: 0.01)
        XCTAssertEqual(layout.previewFrame.midY, 852.0 / 2.0, accuracy: 0.5)
    }

    func testMeasuredLegacyGalleryPhotoFrame() {
        let layout = chatMediaEditorLayout(size: CGSize(width: 402.0, height: 874.0), safeInsets: UIEdgeInsets(top: 62.0, left: 0.0, bottom: 20.0, right: 0.0), mediaSize: CGSize(width: 3024.0, height: 4032.0), toolbarHeight: 49.0, captionPanelHeight: 62.0, keyboardHeight: 0.0)
        XCTAssertEqual(layout.previewFrame.midY, (167.7 + 705.3) / 2.0, accuracy: 0.6)
        XCTAssertEqual(layout.previewFrame.width, 402.0)
    }

    func testTallVideoFitsTheScreen() {
        let layout = chatMediaEditorLayout(size: size, safeInsets: insets, mediaSize: CGSize(width: 1080.0, height: 2400.0), toolbarHeight: 48.0, captionPanelHeight: 52.0, keyboardHeight: 0.0)
        XCTAssertEqual(layout.previewFrame.minY, 0.0, accuracy: 0.5)
        XCTAssertEqual(layout.previewFrame.maxY, 852.0, accuracy: 0.5)
        XCTAssertEqual(layout.previewFrame.midX, 393.0 / 2.0, accuracy: 0.5)
    }

    func testKeyboardMovesCaptionNotPreview() {
        let base = chatMediaEditorLayout(size: size, safeInsets: insets, mediaSize: CGSize(width: 4032.0, height: 3024.0), toolbarHeight: 48.0, captionPanelHeight: 52.0, keyboardHeight: 0.0)
        let up = chatMediaEditorLayout(size: size, safeInsets: insets, mediaSize: CGSize(width: 4032.0, height: 3024.0), toolbarHeight: 48.0, captionPanelHeight: 52.0, keyboardHeight: 336.0)
        XCTAssertEqual(up.previewFrame, base.previewFrame)
        XCTAssertEqual(up.captionPanelFrame.maxY, 852.0 - 336.0)
    }

    func testToolsPreviewLeavesRoomForPanelAboveToolbar() {
        let frame = chatMediaEditorToolPreviewFrame(kind: .tools, size: size, safeInsets: insets, mediaSize: CGSize(width: 3024.0, height: 4032.0), toolbarHeight: 49.0)
        XCTAssertEqual(frame.minY, 59.0, accuracy: 0.5)
        XCTAssertEqual(frame.maxY, 852.0 - 34.0 - 49.0 - 8.0 - 180.0, accuracy: 0.5)
        XCTAssertEqual(frame.width / frame.height, 0.75, accuracy: 0.01)
        XCTAssertEqual(frame.midX, 393.0 / 2.0, accuracy: 0.5)
    }

    func testPaintPreviewUsesLegacyPaintPanels() {
        let frame = chatMediaEditorToolPreviewFrame(kind: .paint, size: size, safeInsets: insets, mediaSize: CGSize(width: 1080.0, height: 1920.0), toolbarHeight: 49.0)
        XCTAssertEqual(frame.minY, 59.0 + 44.0, accuracy: 0.5)
        XCTAssertEqual(frame.height, 852.0 - 59.0 - 34.0 - 49.0 - 44.0 - 79.0, accuracy: 0.5)
    }

    func testChatToolsPreviewUsesLegacyPanelSize() {
        let frame = chatMediaEditorToolPreviewFrame(kind: .chatTools, size: size, safeInsets: insets, mediaSize: CGSize(width: 1080.0, height: 4000.0), toolbarHeight: 49.0)
        XCTAssertEqual(frame.minY, 59.0, accuracy: 0.5)
        XCTAssertEqual(frame.maxY, 852.0 - 34.0 - 49.0 - 115.0, accuracy: 0.5)
        let wide = chatMediaEditorToolPreviewFrame(kind: .chatTools, size: size, safeInsets: insets, mediaSize: CGSize(width: 3024.0, height: 4032.0), toolbarHeight: 49.0)
        XCTAssertEqual(wide.midY, 59.0 + (852.0 - 34.0 - 49.0 - 115.0 - 59.0) / 2.0, accuracy: 0.5)
    }

    func testRecipientLabelSitsTopLeftAtTheEdgeInset() {
        let layout = chatMediaEditorRecipientLayout(size: size, safeInsets: insets, arrowSize: CGSize(width: 10.0, height: 12.0), labelSize: CGSize(width: 80.0, height: 16.0))
        XCTAssertEqual(layout.arrowFrame, CGRect(x: 16.0, y: 59.0 + 16.0, width: 10.0, height: 12.0))
        XCTAssertEqual(layout.labelFrame, CGRect(x: 32.0, y: 59.0 + 14.0, width: 80.0, height: 16.0))
    }

    func testRecipientLabelWidthIsCapped() {
        let layout = chatMediaEditorRecipientLayout(size: size, safeInsets: insets, arrowSize: CGSize(width: 10.0, height: 12.0), labelSize: CGSize(width: 1000.0, height: 16.0))
        XCTAssertEqual(layout.labelFrame.width, 393.0 - 150.0)
        XCTAssertEqual(layout.arrowFrame.minY, 59.0 + 16.0)
    }

    func testRecipientLabelKeepsBelowStatusBarOnlyInset() {
        let layout = chatMediaEditorRecipientLayout(size: CGSize(width: 375.0, height: 667.0), safeInsets: UIEdgeInsets(top: 20.0, left: 0.0, bottom: 0.0, right: 0.0), arrowSize: CGSize(width: 10.0, height: 12.0), labelSize: CGSize(width: 80.0, height: 16.0))
        XCTAssertEqual(layout.arrowFrame.minY, 36.0)
    }

    // iPhone Duo's unfolded screen in portrait (669x951, the island's 82pt band as the top inset): the recipient row sits
    // on the island's clock line with the check button, and a long name stops short of the check, moved left of the
    // island.
    func testRecipientRowSitsOnTheStatusIslandsClockLine() {
        let size = CGSize(width: 669.0, height: 951.0)
        let insets = UIEdgeInsets(top: 82.0, left: 0.0, bottom: 20.0, right: 0.0)
        let island = ChatMediaEditorStatusIslandRow(clockLineY: 47.0, trailingInset: 134.0)
        let layout = chatMediaEditorRecipientLayout(size: size, safeInsets: insets, arrowSize: CGSize(width: 10.0, height: 12.0), labelSize: CGSize(width: 80.0, height: 16.0), statusIsland: island)
        XCTAssertEqual(layout.arrowFrame.midY, 47.0)
        XCTAssertEqual(layout.labelFrame.midY, 47.0)
        XCTAssertEqual(layout.arrowFrame.minX, 16.0)
        let check = chatMediaEditorCheckButtonFrame(size: size, safeInsets: insets, statusIsland: island)
        XCTAssertEqual(layout.arrowFrame.midY, check.midY)
        let long = chatMediaEditorRecipientLayout(size: size, safeInsets: insets, arrowSize: CGSize(width: 10.0, height: 12.0), labelSize: CGSize(width: 1000.0, height: 16.0), statusIsland: island)
        XCTAssertEqual(long.labelFrame.maxX, check.minX - 8.0)
        // Without an island the row is where it always was.
        XCTAssertEqual(chatMediaEditorRecipientLayout(size: size, safeInsets: insets, arrowSize: CGSize(width: 10.0, height: 12.0), labelSize: CGSize(width: 80.0, height: 16.0), statusIsland: nil), chatMediaEditorRecipientLayout(size: size, safeInsets: insets, arrowSize: CGSize(width: 10.0, height: 12.0), labelSize: CGSize(width: 80.0, height: 16.0)))
    }

    func testLandscapeToolsPreviewKeepsFullWidth() {
        let frame = chatMediaEditorToolPreviewFrame(kind: .tools, size: size, safeInsets: insets, mediaSize: CGSize(width: 4032.0, height: 3024.0), toolbarHeight: 49.0)
        XCTAssertEqual(frame.width, 393.0, accuracy: 0.5)
        XCTAssertLessThanOrEqual(frame.maxY, 852.0 - 34.0 - 49.0 - 8.0 - 180.0 + 0.5)
    }

    func testVideoScrubberSitsInLegacyHeaderAboveCaption() {
        let captionBase: CGFloat = 52.0
        let toolbarMinY = 852.0 - 34.0 - 49.0
        let layout = chatMediaEditorLayout(size: size, safeInsets: insets, mediaSize: CGSize(width: 1080.0, height: 1920.0), toolbarHeight: 49.0, captionPanelHeight: captionBase + 10.0, keyboardHeight: 0.0)
        let headerFrame = chatMediaEditorVideoHeaderFrame(size: size, toolbarMinY: toolbarMinY, captionBaseHeight: captionBase)
        XCTAssertEqual(headerFrame, CGRect(x: 0.0, y: toolbarMinY - 74.0 - captionBase, width: 393.0, height: 72.0))
        let scrubberFrame = chatMediaEditorScrubberFrame(size: size, safeInsets: insets, headerFrame: headerFrame, scrubberHeight: 40.0)
        XCTAssertEqual(scrubberFrame.minX, 9.0, accuracy: 0.5)
        XCTAssertEqual(scrubberFrame.width, 393.0 - 18.0, accuracy: 0.5)
        XCTAssertEqual(scrubberFrame.midY, headerFrame.midY, accuracy: 0.5)
        XCTAssertLessThanOrEqual(scrubberFrame.maxY, layout.captionPanelFrame.minY)
        XCTAssertEqual(layout.previewFrame.midY, 852.0 / 2.0, accuracy: 0.5)
    }

    func testScrubberFramesCoverTrackWidth() {
        XCTAssertEqual(chatMediaEditorScrubberFramesCount(trackWidth: 384.0, mediaSize: CGSize(width: 1920.0, height: 1080.0)), 6)
        XCTAssertEqual(chatMediaEditorScrubberFramesCount(trackWidth: 384.0, mediaSize: CGSize(width: 1080.0, height: 1920.0)), 15)
        XCTAssertEqual(chatMediaEditorScrubberFramesCount(trackWidth: 0.0, mediaSize: CGSize(width: 1920.0, height: 1080.0)), 1)
    }

    func testUnfoldedLandscapeVideoKeepsTheTrimmerAndToolbarAtTheBottom() {
        let size = CGSize(width: 951.0, height: 669.0)
        let insets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 20.0, right: 84.0)
        let statusBlock = CGRect(x: 951.0 - 84.0, y: 0.0, width: 84.0, height: 120.0)
        let layout = chatMediaEditorLayout(size: size, safeInsets: insets, mediaSize: CGSize(width: 1920.0, height: 1080.0), toolbarHeight: 49.0, captionPanelHeight: 62.0, keyboardHeight: 0.0)
        XCTAssertEqual(layout.toolbarFrame, CGRect(x: 0.0, y: 669.0 - 20.0 - 49.0, width: 951.0, height: 49.0))

        let header = chatMediaEditorVideoHeaderFrame(size: size, toolbarMinY: layout.toolbarFrame.minY, captionBaseHeight: 52.0)
        let scrubber = chatMediaEditorScrubberFrame(size: size, safeInsets: insets, headerFrame: header, scrubberHeight: 44.0)
        XCTAssertGreaterThan(scrubber.minY, size.height / 2.0)
        XCTAssertLessThan(scrubber.maxY, layout.toolbarFrame.minY)
        XCTAssertEqual(scrubber.minX, 9.0)
        XCTAssertEqual(scrubber.maxX, 951.0 - 84.0 - 9.0)

        let check = chatMediaEditorCheckButtonFrame(size: size, safeInsets: insets)
        XCTAssertFalse(check.intersects(statusBlock))
    }

    func testToolPreviewCentresOnTheScreenWhenItClearsTheStrip() {
        let unfoldedLandscape = chatMediaEditorToolPreviewFrame(kind: .tools, size: CGSize(width: 951.0, height: 669.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 20.0, right: 84.0), mediaSize: CGSize(width: 4032.0, height: 3024.0), toolbarHeight: 49.0)
        XCTAssertEqual(unfoldedLandscape.midX, 475.5, accuracy: 0.5)
        let foldedLandscape = chatMediaEditorToolPreviewFrame(kind: .paint, size: CGSize(width: 678.0, height: 466.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 20.0, right: 84.0), mediaSize: CGSize(width: 4032.0, height: 3024.0), toolbarHeight: 49.0)
        XCTAssertEqual(foldedLandscape.midX, 339.0, accuracy: 0.5)
        XCTAssertLessThanOrEqual(foldedLandscape.maxX, 678.0 - 84.0)
    }

    func testToolPreviewKeepsToTheBandWhenTheScreenCentreReachesTheStrip() {
        let frame = chatMediaEditorToolPreviewFrame(kind: .tools, size: CGSize(width: 466.0, height: 678.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 20.0, right: 84.0), mediaSize: CGSize(width: 4032.0, height: 3024.0), toolbarHeight: 49.0)
        XCTAssertEqual(frame.midX, 191.0, accuracy: 0.5)
        XCTAssertLessThanOrEqual(frame.maxX, 466.0 - 84.0 + 0.5)
    }

    func testToolPreviewWithEqualInsetsIsUnchanged() {
        let insets = UIEdgeInsets(top: 59.0, left: 0.0, bottom: 34.0, right: 0.0)
        let frame = chatMediaEditorToolPreviewFrame(kind: .tools, size: CGSize(width: 402.0, height: 874.0), safeInsets: insets, mediaSize: CGSize(width: 4032.0, height: 3024.0), toolbarHeight: 49.0)
        XCTAssertEqual(frame.midX, 201.0, accuracy: 0.5)
    }

    func testCropContainerCentresOnTheScreenInLandscapeBesideAStrip() {
        let landscape = chatMediaEditorCropContainerFrame(size: CGSize(width: 951.0, height: 669.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 20.0, right: 84.0), toolbarHeight: 49.0, hasRotationWheel: true, hasPerspective: true)
        XCTAssertEqual(landscape.midX, 475.5, accuracy: 0.5)
        XCTAssertEqual(landscape.maxX, 951.0 - 84.0, accuracy: 0.5)
        let portrait = chatMediaEditorCropContainerFrame(size: CGSize(width: 466.0, height: 678.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 20.0, right: 84.0), toolbarHeight: 49.0, hasRotationWheel: true, hasPerspective: true)
        XCTAssertEqual(portrait.minX, 0.0)
        XCTAssertEqual(portrait.width, 382.0)
    }
}
