import XCTest
import Postbox
@testable import TelegramCore

/// widget-sandbox v0.2 (W2 plan, Task 6; design §4 calls 8, 10; tgw-format.md "Forwarding is allowed to any chat"): a
/// forward's local echo shows the widget as the copy the server will make (no queries, no chat state) until the
/// server's message replaces it, and keeps its sender's header even under "hide sender names" (the server keeps it).
final class ForwardedWidgetEchoTests: XCTestCase {
    private func widget() -> TelegramMediaWidget {
        return TelegramMediaWidget(width: 300, height: 0, payload: Data("<p>w</p>".utf8), isCopy: false, canQuery: true, backgroundQuery: true, chatData: Data("c".utf8), publicData: Data("p".utf8), widgetId: 42)
    }

    func testTheEchoOfAWidgetIsItsForwardedCopy() {
        let echoed = forwardedMediaForLocalEcho(self.widget())
        XCTAssertTrue(echoed.isEqual(to: self.widget().forwardedCopy()))
    }

    func testOtherMediaIsUnchanged() {
        let image = TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.CloudImage, id: 1), representations: [], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        XCTAssertTrue(forwardedMediaForLocalEcho(image) === image)
    }

    func testAWidgetKeepsItsSenderUnderHiddenNames() {
        let image = TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.CloudImage, id: 1), representations: [], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        XCTAssertTrue(forwardKeepsSenderHeader(media: [self.widget()]))
        XCTAssertFalse(forwardKeepsSenderHeader(media: []))
        XCTAssertFalse(forwardKeepsSenderHeader(media: [image]))
    }
}
