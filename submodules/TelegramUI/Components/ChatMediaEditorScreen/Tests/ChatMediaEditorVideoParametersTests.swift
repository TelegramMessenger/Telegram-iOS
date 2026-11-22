import XCTest
import UIKit
import TelegramCore
import ChatMediaEditorScreen

final class ChatMediaEditorVideoParametersTests: XCTestCase {
    func testTrackDimensionsWinOverAttribute() {
        let result = chatMediaEditorResolveVideoParameters(trackSize: CGSize(width: -1080.0, height: 1920.0), assetDuration: 12.5, attribute: (PixelDimensions(width: 1920, height: 1080), 10.0))
        XCTAssertEqual(result?.dimensions, PixelDimensions(width: 1080, height: 1920))
        XCTAssertEqual(result?.duration, 12.5)
    }

    func testAttributeIsFallbackWhenTrackReadFails() {
        let result = chatMediaEditorResolveVideoParameters(trackSize: nil, assetDuration: .nan, attribute: (PixelDimensions(width: 640, height: 360), 7.0))
        XCTAssertEqual(result?.dimensions, PixelDimensions(width: 640, height: 360))
        XCTAssertEqual(result?.duration, 7.0)
    }

    func testZeroTrackSizeFallsBackToAttribute() {
        let result = chatMediaEditorResolveVideoParameters(trackSize: .zero, assetDuration: 3.0, attribute: (PixelDimensions(width: 640, height: 360), 7.0))
        XCTAssertEqual(result?.dimensions, PixelDimensions(width: 640, height: 360))
        XCTAssertEqual(result?.duration, 3.0)
    }

    func testNothingReadableIsNil() {
        XCTAssertNil(chatMediaEditorResolveVideoParameters(trackSize: nil, assetDuration: 0.0, attribute: nil))
    }

    func testPlaybackDoesNotResumeAfterSendOrDismiss() {
        XCTAssertTrue(chatMediaEditorCanResumePlayback(isSending: false, isInvalidated: false, isDismissing: false))
        XCTAssertFalse(chatMediaEditorCanResumePlayback(isSending: true, isInvalidated: false, isDismissing: false))
        XCTAssertFalse(chatMediaEditorCanResumePlayback(isSending: false, isInvalidated: true, isDismissing: false))
        XCTAssertFalse(chatMediaEditorCanResumePlayback(isSending: false, isInvalidated: false, isDismissing: true))
    }
}
