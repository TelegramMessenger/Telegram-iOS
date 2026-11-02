import XCTest
import UIKit
import Display
import ChatMediaEditorScreen

final class ChatMediaEditorLandscapeTests: XCTestCase {
    let size = CGSize(width: 874.0, height: 402.0)
    let insets = UIEdgeInsets(top: 0.0, left: 62.0, bottom: 20.0, right: 62.0)

    func testToolbarSide() {
        XCTAssertNil(chatMediaEditorToolbarSide(size: CGSize(width: 402.0, height: 874.0), orientation: .portrait, isTablet: false))
        XCTAssertNil(chatMediaEditorToolbarSide(size: size, orientation: .landscapeLeft, isTablet: true))
        XCTAssertEqual(chatMediaEditorToolbarSide(size: size, orientation: .landscapeLeft, isTablet: false), .left)
        XCTAssertEqual(chatMediaEditorToolbarSide(size: size, orientation: .landscapeRight, isTablet: false), .right)
        XCTAssertEqual(chatMediaEditorToolbarSide(size: size, orientation: nil, isTablet: false), .right)
    }

    func testColumnFrame() {
        XCTAssertEqual(chatMediaEditorLandscapeColumnFrame(size: size, safeInsets: insets, side: .left), CGRect(x: 62.0, y: 26.0, width: 49.0, height: 350.0))
        XCTAssertEqual(chatMediaEditorLandscapeColumnFrame(size: size, safeInsets: insets, side: .right), CGRect(x: 763.0, y: 26.0, width: 49.0, height: 350.0))
    }

    func testContentRect() {
        XCTAssertEqual(chatMediaEditorLandscapeContentRect(size: size, safeInsets: insets, side: .left, panelWidth: 0.0), CGRect(x: 111.0, y: 0.0, width: 701.0, height: 382.0))
        XCTAssertEqual(chatMediaEditorLandscapeContentRect(size: size, safeInsets: insets, side: .right, panelWidth: 0.0), CGRect(x: 62.0, y: 0.0, width: 701.0, height: 382.0))
    }

    func testLandscapeLayoutPreviewFitsContentRect() {
        let layout = chatMediaEditorLayout(size: size, safeInsets: insets, mediaSize: CGSize(width: 3000.0, height: 2000.0), toolbarHeight: 49.0, captionPanelHeight: 52.0, keyboardHeight: 0.0, toolbarSide: .left)
        XCTAssertEqual(layout.previewFrame, CGRect(x: 175.0, y: 0.0, width: 573.0, height: 382.0))
        XCTAssertEqual(layout.toolbarFrame, CGRect(x: 62.0, y: 26.0, width: 49.0, height: 350.0))
    }

    func testLandscapeCaptionOffScreen() {
        let layout = chatMediaEditorLayout(size: size, safeInsets: insets, mediaSize: CGSize(width: 3000.0, height: 2000.0), toolbarHeight: 49.0, captionPanelHeight: 52.0, keyboardHeight: 0.0, toolbarSide: .right)
        XCTAssertEqual(layout.captionPanelFrame.minY, 402.0)
    }

    func testLandscapeToolPreviewUsesPanelWidth() {
        let frame = chatMediaEditorToolPreviewFrame(kind: .quality, size: size, safeInsets: insets, mediaSize: CGSize(width: 1000.0, height: 1000.0), toolbarHeight: 49.0, toolbarSide: .right)
        XCTAssertEqual(frame.height, 382.0)
        XCTAssertEqual(frame, CGRect(x: 184.0, y: 0.0, width: 382.0, height: 382.0))
    }

    func testPortraitUnchanged() {
        let portraitSize = CGSize(width: 393.0, height: 852.0)
        let portraitInsets = UIEdgeInsets(top: 59.0, left: 0.0, bottom: 34.0, right: 0.0)
        let media = [CGSize(width: 4032.0, height: 3024.0), CGSize(width: 1080.0, height: 2400.0), CGSize(width: 3024.0, height: 4032.0)]
        for mediaSize in media {
            XCTAssertEqual(
                chatMediaEditorLayout(size: portraitSize, safeInsets: portraitInsets, mediaSize: mediaSize, toolbarHeight: 48.0, captionPanelHeight: 52.0, keyboardHeight: 0.0, toolbarSide: nil),
                chatMediaEditorLayout(size: portraitSize, safeInsets: portraitInsets, mediaSize: mediaSize, toolbarHeight: 48.0, captionPanelHeight: 52.0, keyboardHeight: 0.0)
            )
            XCTAssertEqual(
                chatMediaEditorToolPreviewFrame(kind: .tools, size: portraitSize, safeInsets: portraitInsets, mediaSize: mediaSize, toolbarHeight: 49.0, toolbarSide: nil),
                chatMediaEditorToolPreviewFrame(kind: .tools, size: portraitSize, safeInsets: portraitInsets, mediaSize: mediaSize, toolbarHeight: 49.0)
            )
        }
    }

    func testDuoFoldedLandscapeLeftColumnClearsReservedCorner() {
        let duoSize = CGSize(width: 678.0, height: 466.0)
        let duoInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0)
        let corners = ContainerViewLayoutCorners(topLeft: nil, topRight: nil, bottomLeft: nil, bottomRight: CGSize(width: 84.0, height: 82.0))
        let column = chatMediaEditorLandscapeColumnFrame(size: duoSize, safeInsets: duoInsets, side: .left, reservedCorners: corners)
        let block = CGRect(x: duoSize.width - 84.0, y: duoSize.height - 82.0, width: 84.0, height: 82.0)
        XCTAssertFalse(column.intersects(block))
    }

    func testLandscapeVideoHeaderFrame() {
        XCTAssertEqual(chatMediaEditorVideoHeaderFrame(size: size, toolbarMinY: 0.0, captionBaseHeight: 52.0, safeInsets: insets, toolbarSide: .left), CGRect(x: 111.0, y: 318.0, width: 701.0, height: 64.0))
        XCTAssertEqual(chatMediaEditorVideoHeaderFrame(size: size, toolbarMinY: 0.0, captionBaseHeight: 52.0, safeInsets: insets, toolbarSide: .right), CGRect(x: 62.0, y: 318.0, width: 701.0, height: 64.0))
    }

    func testLandscapeVideoHeaderClearsCheckButton() {
        for side in [ChatMediaEditorToolbarSide.left, .right] {
            let checkFrame = chatMediaEditorCheckButtonFrame(size: size, safeInsets: insets, toolbarSide: side)
            let header = chatMediaEditorVideoHeaderFrame(size: size, toolbarMinY: 0.0, captionBaseHeight: 0.0, safeInsets: insets, toolbarSide: side)
            XCTAssertFalse(header.intersects(checkFrame))
        }
    }

    func testLandscapeScrubberFrame() {
        let leftHeader = chatMediaEditorVideoHeaderFrame(size: size, toolbarMinY: 0.0, captionBaseHeight: 0.0, safeInsets: insets, toolbarSide: .left)
        let rightHeader = chatMediaEditorVideoHeaderFrame(size: size, toolbarMinY: 0.0, captionBaseHeight: 0.0, safeInsets: insets, toolbarSide: .right)
        XCTAssertEqual(chatMediaEditorScrubberFrame(size: size, safeInsets: insets, headerFrame: leftHeader, scrubberHeight: 39.0, toolbarSide: .left), CGRect(x: 120.0, y: 330.0, width: 683.0, height: 39.0))
        XCTAssertEqual(chatMediaEditorScrubberFrame(size: size, safeInsets: insets, headerFrame: rightHeader, scrubberHeight: 39.0, toolbarSide: .right), CGRect(x: 71.0, y: 330.0, width: 683.0, height: 39.0))
    }

    func testLandscapeMuteButtonSitsAboveScrubberStart() {
        for (side, x) in [(ChatMediaEditorToolbarSide.left, 127.0), (.right, 78.0)] as [(ChatMediaEditorToolbarSide, CGFloat)] {
            let header = chatMediaEditorVideoHeaderFrame(size: size, toolbarMinY: 0.0, captionBaseHeight: 0.0, safeInsets: insets, toolbarSide: side)
            let mute = chatMediaEditorMuteButtonFrame(headerFrame: header, safeInsets: insets, toolbarSide: side)
            XCTAssertEqual(mute, CGRect(x: x, y: 280.0, width: 40.0, height: 40.0))
            let scrubber = chatMediaEditorScrubberFrame(size: size, safeInsets: insets, headerFrame: header, scrubberHeight: 39.0, toolbarSide: side)
            XCTAssertEqual(mute.minX, header.minX + 16.0)
            XCTAssertEqual(scrubber.minY - mute.maxY, 10.0)
        }
    }

    func testLandscapeCoverButtonFrame() {
        let leftHeader = chatMediaEditorVideoHeaderFrame(size: size, toolbarMinY: 0.0, captionBaseHeight: 0.0, safeInsets: insets, toolbarSide: .left)
        let rightHeader = chatMediaEditorVideoHeaderFrame(size: size, toolbarMinY: 0.0, captionBaseHeight: 0.0, safeInsets: insets, toolbarSide: .right)
        for (header, side) in [(leftHeader, ChatMediaEditorToolbarSide.left), (rightHeader, .right)] {
            let cover = chatMediaEditorCoverButtonFrame(size: size, safeInsets: insets, headerFrame: header, buttonWidth: 100.0, toolbarSide: side)
            XCTAssertEqual(cover.minY, 303.0)
            XCTAssertEqual(cover.size, CGSize(width: 100.0, height: 26.0))
            XCTAssertEqual(cover.midX, header.midX, accuracy: 0.5)
        }
    }

    func testLandscapeRecipientIsCentredOnMediaAreaAtCheckButtonHeight() {
        let arrowSize = CGSize(width: 8.0, height: 12.0)
        let labelSize = CGSize(width: 100.0, height: 16.0)
        for side in [ChatMediaEditorToolbarSide.left, .right] {
            let layout = chatMediaEditorRecipientLayout(size: size, safeInsets: insets, arrowSize: arrowSize, labelSize: labelSize, toolbarSide: side)
            XCTAssertEqual(layout.labelFrame.minX, layout.arrowFrame.maxX + 6.0)
            XCTAssertEqual(layout.arrowFrame.midY, chatMediaEditorCheckButtonFrame(size: size, safeInsets: insets, toolbarSide: side).midY, accuracy: 0.5)
            XCTAssertEqual(layout.labelFrame.minY, layout.arrowFrame.minY - 2.0)
            let contentRect = chatMediaEditorLandscapeContentRect(size: size, safeInsets: insets, side: side, panelWidth: 0.0)
            XCTAssertEqual(layout.arrowFrame.union(layout.labelFrame).midX, contentRect.midX, accuracy: 0.5)
        }
    }

    func testLandscapeCounterCircleIsLevelWithCheckButton() {
        for side in [ChatMediaEditorToolbarSide.left, .right] {
            let check = chatMediaEditorCheckButtonFrame(size: size, safeInsets: insets, toolbarSide: side)
            let counter = chatMediaEditorCounterButtonFrame(size: size, safeInsets: insets, reservedCorners: .none, toolbarMinY: 0.0, captionBaseHeight: 0.0, hasVideoHeader: false, toolbarSide: side)
            XCTAssertEqual(counter.minY + chatMediaEditorCounterCircleFrame.midY, check.midY)
            let recipient = chatMediaEditorRecipientLayout(size: size, safeInsets: insets, arrowSize: CGSize(width: 8.0, height: 12.0), labelSize: CGSize(width: 100.0, height: 16.0), toolbarSide: side)
            XCTAssertFalse(counter.intersects(recipient.labelFrame.union(recipient.arrowFrame)))
        }
    }

    func testPortraitCounterCircleBottomMatchesMuteButton() {
        let size = CGSize(width: 402.0, height: 874.0)
        let safeInsets = UIEdgeInsets(top: 62.0, left: 0.0, bottom: 34.0, right: 0.0)
        let header = chatMediaEditorVideoHeaderFrame(size: size, toolbarMinY: 791.0, captionBaseHeight: 52.0, safeInsets: safeInsets)
        let mute = chatMediaEditorMuteButtonFrame(headerFrame: header, safeInsets: safeInsets)
        let counter = chatMediaEditorCounterButtonFrame(size: size, safeInsets: safeInsets, reservedCorners: .none, toolbarMinY: 791.0, captionBaseHeight: 52.0, hasVideoHeader: true)
        XCTAssertEqual(counter.minY + chatMediaEditorCounterCircleFrame.maxY, mute.maxY)
        XCTAssertEqual(mute.minX, 16.0)
    }

    func testPlayButtonIsHiddenWhileScrubbing() {
        XCTAssertTrue(chatMediaEditorPlayButtonIsVisible(isPlaying: false, hasPlayed: true, isScrubberTracking: false))
        XCTAssertFalse(chatMediaEditorPlayButtonIsVisible(isPlaying: false, hasPlayed: true, isScrubberTracking: true))
        XCTAssertFalse(chatMediaEditorPlayButtonIsVisible(isPlaying: true, hasPlayed: true, isScrubberTracking: false))
    }

    func testPlayButtonIsHiddenBeforePlaybackStarts() {
        XCTAssertFalse(chatMediaEditorPlayButtonIsVisible(isPlaying: false, hasPlayed: false, isScrubberTracking: false))
    }

    func testLandscapeLivePhotoButtonFrame() {
        let buttonSize = CGSize(width: 160.0, height: 18.0)
        XCTAssertEqual(chatMediaEditorLivePhotoButtonFrame(size: size, safeInsets: insets, keyboardHeight: 0.0, buttonSize: buttonSize, toolbarSide: .left), CGRect(x: 636.0, y: 48.0, width: 160.0, height: 18.0))
        XCTAssertEqual(chatMediaEditorLivePhotoButtonFrame(size: size, safeInsets: insets, keyboardHeight: 0.0, buttonSize: buttonSize, toolbarSide: .right), CGRect(x: 78.0, y: 48.0, width: 160.0, height: 18.0))
    }

    func testLandscapeCameraButtonFrame() {
        XCTAssertEqual(chatMediaEditorCameraButtonFrame(size: size, safeInsets: insets, reservedCorners: .none, toolbarMinY: 0.0, captionBaseHeight: 52.0, hasVideoHeader: true, hasSelection: true, toolbarSide: .left), CGRect(x: 112.0, y: 51.0, width: 44.0, height: 44.0))
        XCTAssertEqual(chatMediaEditorCameraButtonFrame(size: size, safeInsets: insets, reservedCorners: .none, toolbarMinY: 0.0, captionBaseHeight: 52.0, hasVideoHeader: false, hasSelection: false, toolbarSide: .right), CGRect(x: 718.0, y: 1.0, width: 44.0, height: 44.0))
    }

    func testDuoFoldedLandscapeBottomControlsClearReservedCorner() {
        let duoSize = CGSize(width: 678.0, height: 466.0)
        let corners = ContainerViewLayoutCorners(topLeft: nil, topRight: nil, bottomLeft: nil, bottomRight: CGSize(width: 84.0, height: 82.0))
        let block = CGRect(x: 594.0, y: 384.0, width: 84.0, height: 82.0)
        let arrowSize = CGSize(width: 8.0, height: 12.0)
        let labelSize = CGSize(width: 100.0, height: 16.0)
        for duoInsets in [UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0), UIEdgeInsets()] {
            let header = chatMediaEditorVideoHeaderFrame(size: duoSize, toolbarMinY: 0.0, captionBaseHeight: 0.0, safeInsets: duoInsets, toolbarSide: .left, reservedCorners: corners)
            XCTAssertEqual(header, CGRect(x: 49.0, y: 402.0, width: 545.0, height: 64.0))
            XCTAssertFalse(header.intersects(block))
            let mute = chatMediaEditorMuteButtonFrame(headerFrame: header, safeInsets: duoInsets, toolbarSide: .left)
            XCTAssertEqual(mute, CGRect(x: 65.0, y: 364.0, width: 40.0, height: 40.0))
            let recipient = chatMediaEditorRecipientLayout(size: duoSize, safeInsets: duoInsets, arrowSize: arrowSize, labelSize: labelSize, toolbarSide: .left)
            XCTAssertFalse(recipient.labelFrame.intersects(block))
        }
    }

    func testDuoFoldedLandscapeRightBottomControlsKeepBand() {
        let duoSize = CGSize(width: 678.0, height: 466.0)
        let duoInsets = UIEdgeInsets(top: 0.0, left: 84.0, bottom: 0.0, right: 0.0)
        let corners = ContainerViewLayoutCorners(topLeft: CGSize(width: 84.0, height: 82.0), topRight: nil, bottomLeft: nil, bottomRight: nil)
        let header = chatMediaEditorVideoHeaderFrame(size: duoSize, toolbarMinY: 0.0, captionBaseHeight: 0.0, safeInsets: duoInsets, toolbarSide: .right, reservedCorners: corners)
        XCTAssertEqual(header, CGRect(x: 84.0, y: 402.0, width: 545.0, height: 64.0))
        XCTAssertEqual(chatMediaEditorMuteButtonFrame(headerFrame: header, safeInsets: duoInsets, toolbarSide: .right), CGRect(x: 100.0, y: 364.0, width: 40.0, height: 40.0))
    }

    func testColumnShortenedAtReservedCornerOnItsSide() {
        let duoSize = CGSize(width: 678.0, height: 466.0)
        let duoInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0)
        let corners = ContainerViewLayoutCorners(topLeft: nil, topRight: nil, bottomLeft: CGSize(width: 84.0, height: 82.0), bottomRight: nil)
        let column = chatMediaEditorLandscapeColumnFrame(size: duoSize, safeInsets: duoInsets, side: .left, reservedCorners: corners)
        XCTAssertEqual(column, CGRect(x: 0.0, y: 26.0, width: 49.0, height: 358.0))
    }

    func testToolsPanelFrameLeft() {
        XCTAssertEqual(chatMediaEditorLandscapeToolsPanelFrame(size: size, safeInsets: insets, side: .left), CGRect(x: 111.0, y: 0.0, width: 220.0, height: 382.0))
    }

    func testToolsPanelFrameRight() {
        XCTAssertEqual(chatMediaEditorLandscapeToolsPanelFrame(size: size, safeInsets: insets, side: .right), CGRect(x: 543.0, y: 0.0, width: 220.0, height: 382.0))
    }

    func testToolsPanelFrameAdjoinsColumnAndContent() {
        for side in [ChatMediaEditorToolbarSide.left, .right] {
            let column = chatMediaEditorLandscapeColumnFrame(size: size, safeInsets: insets, side: side)
            let panel = chatMediaEditorLandscapeToolsPanelFrame(size: size, safeInsets: insets, side: side)
            let content = chatMediaEditorLandscapeContentRect(size: size, safeInsets: insets, side: side, panelWidth: chatMediaEditorLandscapeToolsPanelWidth)
            XCTAssertFalse(panel.intersects(column))
            XCTAssertFalse(panel.intersects(content))
            switch side {
            case .left:
                XCTAssertEqual(panel.minX, column.maxX)
                XCTAssertEqual(panel.maxX, content.minX)
            case .right:
                XCTAssertEqual(panel.maxX, column.minX)
                XCTAssertEqual(panel.minX, content.maxX)
            }
        }
    }

    func testToolsPreviewFrameLandscape() {
        let frame = chatMediaEditorToolPreviewFrame(kind: .chatTools, size: size, safeInsets: insets, mediaSize: CGSize(width: 1000.0, height: 1000.0), toolbarHeight: 49.0, toolbarSide: .left)
        XCTAssertEqual(frame, CGRect(x: 380.5, y: 0.0, width: 382.0, height: 382.0))
        let content = chatMediaEditorLandscapeContentRect(size: size, safeInsets: insets, side: .left, panelWidth: 220.0)
        XCTAssertTrue(content.contains(frame))
        XCTAssertFalse(frame.intersects(chatMediaEditorLandscapeToolsPanelFrame(size: size, safeInsets: insets, side: .left)))
    }
}
