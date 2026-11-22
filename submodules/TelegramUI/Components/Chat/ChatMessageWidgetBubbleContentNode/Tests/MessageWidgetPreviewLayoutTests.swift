import XCTest
import TelegramCore
import MessageWidget
@testable import ChatMessageWidgetBubbleContentNode

/// An inline result's widget preview (widget-sandbox v0.2, sdk-v1 §2.16; W3 plan Task 2): sized as its sent bubble lays
/// it out, drawn at most 240 pt tall in a results row (the user, 2026-10-27: a taller widget is scaled down, never up),
/// and shown only for a widget result while widgets are on.
final class MessageWidgetPreviewLayoutTests: XCTestCase {
    private func contentSize(_ width: Int32, _ height: Int32, reported: CGFloat? = nil) -> CGSize {
        return MessageWidgetPreviewLayout.contentSize(anchors: MessageWidgetAnchors(width: width, height: height), availableWidth: 350.0, reportedHeight: reported)
    }

    func testAnAutoSizedWidgetTakesTheWidthAndThePlaceholderHeight() {
        XCTAssertEqual(self.contentSize(0, 0), CGSize(width: 350.0, height: 160.0))
    }

    func testAReportedHeightReplacesThePlaceholder() {
        XCTAssertEqual(self.contentSize(0, 0, reported: 90.0), CGSize(width: 350.0, height: 90.0))
        XCTAssertEqual(self.contentSize(0, 0, reported: 20.0), CGSize(width: 350.0, height: 50.0))
        XCTAssertEqual(self.contentSize(0, 0, reported: 900.0), CGSize(width: 350.0, height: 600.0))
    }

    func testAFixedAnchorKeepsItsSize() {
        XCTAssertEqual(self.contentSize(260, 400), CGSize(width: 260.0, height: 400.0))
        XCTAssertEqual(self.contentSize(120, 30), CGSize(width: 200.0, height: 50.0))
    }

    func testATallWidgetIsScaledDownToTheRow() {
        let fitted = MessageWidgetPreviewLayout.fitted(CGSize(width: 350.0, height: 400.0), in: CGSize(width: 350.0, height: MessageWidgetPreviewLayout.maximumListHeight))
        XCTAssertEqual(fitted.size.width, 210.0, accuracy: 0.001)
        XCTAssertEqual(fitted.size.height, 240.0, accuracy: 0.001)
        XCTAssertEqual(fitted.scale, 0.6, accuracy: 0.0001)
    }

    func testAShortWidgetIsNotScaledUp() {
        let fitted = MessageWidgetPreviewLayout.fitted(CGSize(width: 350.0, height: 100.0), in: CGSize(width: 350.0, height: MessageWidgetPreviewLayout.maximumListHeight))
        XCTAssertEqual(fitted.size, CGSize(width: 350.0, height: 100.0))
        XCTAssertEqual(fitted.scale, 1.0)
    }

    func testOnlyAWidgetResultWithWidgetsOnIsPreviewed() {
        let media = TelegramMediaWidget(width: 0, height: 0, payload: Data([1]))
        let message = ChatContextResultMessage.widget(media: media, caption: "", entities: nil, replyMarkup: nil)
        XCTAssertTrue(messageWidgetPreviewWidget(message, renderingEnabled: true) === media)
        XCTAssertNil(messageWidgetPreviewWidget(message, renderingEnabled: false))
        XCTAssertNil(messageWidgetPreviewWidget(.auto(caption: "x", entities: nil, replyMarkup: nil), renderingEnabled: true))
    }
}
