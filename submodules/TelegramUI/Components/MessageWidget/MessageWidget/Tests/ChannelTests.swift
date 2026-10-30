import XCTest
@testable import MessageWidget

/// widget-sandbox v0.1.0's `conformance/channel.json`: the posts of the shared test channel, in order, which the debug
/// insertion puts into Saved Messages as local widget messages.
final class ChannelTests: XCTestCase {
    func testTheChannelIsTheConformanceSetInOrder() throws {
        let url = try XCTUnwrap(Bundle(for: ChannelTests.self).resourceURL?.appendingPathComponent("conformance/channel.json"))
        let posts = try MessageWidgetChannel.posts(fromJSON: Data(contentsOf: url))
        XCTAssertEqual(posts.count, 114)
        XCTAssertEqual(posts.first, MessageWidgetChannelPost(widget: "visual/01-boxes.html", width: 0, height: 0, caption: posts.first?.caption ?? "", photos: ["refs/visual/01-boxes.png"]))
        XCTAssertFalse(posts.first?.caption.isEmpty ?? true)
        let sizeHint = posts.filter { $0.widget == "visual/sdk/17-size-hint.html" }.map { [$0.width, $0.height] }
        XCTAssertEqual(sizeHint, [[0, 0], [0, 300], [300, 0], [300, 300]])
        XCTAssertEqual(posts.first(where: { $0.widget == "visual/12-theme.html" })?.photos.count, 2)
        XCTAssertEqual(posts.filter { $0.widget.hasPrefix("auto/") }.count, 61)
    }

    /// widget-sandbox v0.2.1: a post says how the test bot sends it (`message`), the DEBUG insertion's flags and state.
    func testAPostCarriesItsMessageSpec() throws {
        let url = try XCTUnwrap(Bundle(for: ChannelTests.self).resourceURL?.appendingPathComponent("conformance/channel.json"))
        let posts = try MessageWidgetChannel.posts(fromJSON: Data(contentsOf: url))
        XCTAssertEqual(posts.first { $0.widget == "visual/sdk/16-state-edit.html" }?.message, MessageWidgetChannelMessage(kind: .private, chatData: "0", publicData: "0"))
        XCTAssertNil(posts.first?.message)
        XCTAssertEqual(posts.filter { $0.message != nil }.count, 16)
    }

    /// widget-sandbox v0.4.0: a widget the client draws its time over is posted without a caption, then with its caption
    /// above it; every other post has its caption below.
    func testTheTimeCornerPostsSayWhereTheirCaptionIs() throws {
        let url = try XCTUnwrap(Bundle(for: ChannelTests.self).resourceURL?.appendingPathComponent("conformance/channel.json"))
        let posts = try MessageWidgetChannel.posts(fromJSON: Data(contentsOf: url))
        XCTAssertEqual(posts.filter { $0.widget == "visual/17-time-corner.html" }.map(\.captionPlacement), [.none, .above])
        XCTAssertEqual(posts.filter { $0.widget == "auto/36-safe-area.html" }.map(\.captionPlacement), [.none, .above])
        XCTAssertEqual(posts.first?.captionPlacement, .below)
        XCTAssertEqual(posts.filter { $0.captionPlacement != .below }.count, 4)
    }

    func testAPostWithoutRequiredFieldsIsRefused() {
        XCTAssertThrowsError(try MessageWidgetChannel.posts(fromJSON: Data("{\"posts\":[{\"width\":0}]}".utf8)))
        XCTAssertThrowsError(try MessageWidgetChannel.posts(fromJSON: Data("[]".utf8)))
    }
}
