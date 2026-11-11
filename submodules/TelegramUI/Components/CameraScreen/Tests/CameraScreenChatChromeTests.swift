import XCTest

final class CameraScreenChatChromeTests: XCTestCase {
    func testChatTrailingButtonFollowsBatchCount() {
        XCTAssertEqual(cameraScreenChatTrailingButton(mode: .chat, isTablet: false, batchCount: 0), .flip)
        XCTAssertEqual(cameraScreenChatTrailingButton(mode: .chat, isTablet: false, batchCount: 1), .done)
        XCTAssertEqual(cameraScreenChatTrailingButton(mode: .chat, isTablet: false, batchCount: 100), .done)
        XCTAssertNil(cameraScreenChatTrailingButton(mode: .chat, isTablet: true, batchCount: 0))
        XCTAssertNil(cameraScreenChatTrailingButton(mode: .chat, isTablet: true, batchCount: 3))
        for mode in [CameraScreenModeKind.story, .sticker, .avatar] {
            XCTAssertNil(cameraScreenChatTrailingButton(mode: mode, isTablet: false, batchCount: 0))
            XCTAssertNil(cameraScreenChatTrailingButton(mode: mode, isTablet: false, batchCount: 2))
        }
    }

    func testCloseButtonPlacement() {
        XCTAssertTrue(cameraScreenShowsBottomCloseButton(mode: .chat, isTablet: false))
        XCTAssertFalse(cameraScreenShowsBottomCloseButton(mode: .chat, isTablet: true))
        XCTAssertFalse(cameraScreenShowsTopCancelButton(mode: .chat, isTablet: false))
        XCTAssertTrue(cameraScreenShowsTopCancelButton(mode: .chat, isTablet: true))
        for mode in [CameraScreenModeKind.story, .sticker, .avatar] {
            for isTablet in [false, true] {
                XCTAssertFalse(cameraScreenShowsBottomCloseButton(mode: mode, isTablet: isTablet))
                XCTAssertTrue(cameraScreenShowsTopCancelButton(mode: mode, isTablet: isTablet))
            }
        }
    }

    func testTopFlipOnlyWithBatchItems() {
        XCTAssertFalse(cameraScreenShowsTopFlipButton(mode: .chat, isTablet: false, batchCount: 0))
        XCTAssertTrue(cameraScreenShowsTopFlipButton(mode: .chat, isTablet: false, batchCount: 1))
        XCTAssertFalse(cameraScreenShowsTopFlipButton(mode: .chat, isTablet: true, batchCount: 1))
        for mode in [CameraScreenModeKind.story, .sticker, .avatar] {
            XCTAssertFalse(cameraScreenShowsTopFlipButton(mode: mode, isTablet: false, batchCount: 0))
            XCTAssertFalse(cameraScreenShowsTopFlipButton(mode: mode, isTablet: false, batchCount: 5))
        }
    }

    func testFlashSitsAtTheRightEdgeInChat() {
        XCTAssertEqual(cameraScreenTopFlashTrailingOffset(mode: .chat, isTablet: false), 0.0)
        XCTAssertEqual(cameraScreenTopFlashTrailingOffset(mode: .chat, isTablet: true), 50.0)
        for mode in [CameraScreenModeKind.story, .sticker, .avatar] {
            XCTAssertEqual(cameraScreenTopFlashTrailingOffset(mode: mode, isTablet: false), 50.0)
            XCTAssertEqual(cameraScreenTopFlashTrailingOffset(mode: mode, isTablet: true), 50.0)
        }
    }

    func testBottomButtonsShareTheModeControlUnderlay() {
        XCTAssertEqual(cameraScreenModeControlUnderlayAlpha, 0.11)
        XCTAssertEqual(cameraScreenBottomButtonSize, 48.0)
    }

    func testViewfinderCorners() {
        XCTAssertEqual(cameraScreenPreviewCornerRadius(mode: .chat), 0.0)
        XCTAssertEqual(cameraScreenPlaceholderCornerRadius(mode: .chat), 0.0)
        for mode in [CameraScreenModeKind.story, .sticker, .avatar] {
            XCTAssertEqual(cameraScreenPreviewCornerRadius(mode: mode), 30.0)
            XCTAssertEqual(cameraScreenPlaceholderCornerRadius(mode: mode), 11.0)
        }
    }

    func testDismissMovesOnlyViewfinderInChat() {
        XCTAssertTrue(cameraScreenDismissMovesOnlyViewfinder(mode: .chat))
        for mode in [CameraScreenModeKind.story, .sticker, .avatar] {
            XCTAssertFalse(cameraScreenDismissMovesOnlyViewfinder(mode: mode))
        }
    }

    func testDismissInterfaceHidesAtOnce() {
        XCTAssertEqual(cameraScreenDismissInterfaceAppearance(isDismissing: false), CameraScreenDismissInterfaceAppearance.visible)
        XCTAssertEqual(cameraScreenDismissInterfaceAppearance(isDismissing: true), CameraScreenDismissInterfaceAppearance.hidden)
        XCTAssertEqual(CameraScreenDismissInterfaceAppearance.hidden, CameraScreenDismissInterfaceAppearance(alpha: 0.0, blurRadius: cameraScreenDismissInterfaceMaxBlurRadius))
        XCTAssertEqual(CameraScreenDismissInterfaceAppearance.visible, CameraScreenDismissInterfaceAppearance(alpha: 1.0, blurRadius: 0.0))
        XCTAssertGreaterThanOrEqual(cameraScreenDismissInterfaceAnimationDuration, 0.2)
        XCTAssertLessThanOrEqual(cameraScreenDismissInterfaceAnimationDuration, 0.25)
    }

    func testDismissCompletesAtThirtyPercent() {
        XCTAssertFalse(cameraScreenModalDismissCompletes(translation: 299.0, velocity: 0.0, height: 1000.0))
        XCTAssertTrue(cameraScreenModalDismissCompletes(translation: 301.0, velocity: 0.0, height: 1000.0))
        XCTAssertTrue(cameraScreenModalDismissCompletes(translation: -301.0, velocity: 0.0, height: 1000.0))
        XCTAssertTrue(cameraScreenModalDismissCompletes(translation: 10.0, velocity: 1001.0, height: 1000.0))
        XCTAssertTrue(cameraScreenModalDismissCompletes(translation: 10.0, velocity: -1001.0, height: 1000.0))
        XCTAssertFalse(cameraScreenModalDismissCompletes(translation: 10.0, velocity: 1000.0, height: 1000.0))
    }
}
