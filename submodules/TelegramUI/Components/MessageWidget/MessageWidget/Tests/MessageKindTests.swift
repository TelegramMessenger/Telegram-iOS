import XCTest
@testable import MessageWidget

/// widget-sandbox v0.2.2's WIDGET_MESSAGE_KINDS (packages/core/src/shared/sdk-policy.ts): the server's flags for each
/// kind of message, which the conformance runner and the DEBUG insertion pass as a message's context.
final class MessageKindTests: XCTestCase {
    func testTheMessageKindsMatchUpstream() {
        let viewer = MessageWidgetViewer(id: 7, firstName: "Tester")
        let table: [(String, MessageWidgetMessageKind, MessageWidgetContext)] = [
            ("private", .private, MessageWidgetContext(isCopy: false, canQuery: true, backgroundQuery: true, chatType: .private, viewer: viewer)),
            ("group", .group, MessageWidgetContext(isCopy: false, canQuery: true, backgroundQuery: false, chatType: .group, viewer: viewer)),
            ("via-bot", .viaBot, MessageWidgetContext(isCopy: false, canQuery: true, backgroundQuery: false, chatType: .private, viewer: viewer)),
            ("no-queries", .noQueries, MessageWidgetContext(isCopy: false, canQuery: false, backgroundQuery: false, chatType: .private, viewer: viewer)),
            ("live-copy", .liveCopy, MessageWidgetContext(isCopy: true, canQuery: true, backgroundQuery: false, chatType: .private, viewer: viewer)),
            ("copy", .copy, MessageWidgetContext(isCopy: true, canQuery: false, backgroundQuery: false, chatType: .private, viewer: viewer)),
            ("preview", .preview, MessageWidgetContext(isCopy: false, canQuery: false, backgroundQuery: false, chatType: .private, viewer: nil, isPreview: true)),
        ]
        for (name, kind, context) in table {
            XCTAssertEqual(MessageWidgetMessageKind(rawValue: name), kind, name)
            XCTAssertEqual(kind.context(viewer: viewer), context, name)
        }
        XCTAssertNil(MessageWidgetMessageKind(rawValue: "channel"))
    }
}
