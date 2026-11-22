import XCTest
import MtProtoKit
import TelegramApi
@testable import TelegramCore

/// A message widget's network paths (widget-sandbox v0.2, W2 plan): the server's errors mapped as the tag says (design
/// §4 call 5), and the bot's state edits read field by field.
final class WidgetQueriesTests: XCTestCase {
    /// `WIDGET_RESPONSE_TIMEOUT` is a timeout, a flood wait is a rate limit, and everything else, `WIDGET_QUERY_NOT_ALLOWED`
    /// included (sdk-v1 §5.11), is a failure.
    func testErrorsMapAsTheTagSays() {
        let cases: [(Int32, String, BotWidgetQueryError)] = [
            (400, "WIDGET_RESPONSE_TIMEOUT", .timeout),
            (420, "FLOOD_WAIT_5", .rateLimited),
            (400, "WIDGET_QUERY_NOT_ALLOWED", .failed),
            (400, "PEER_ID_INVALID", .failed),
            (-503, "Timeout", .failed),
            (500, "INTERNAL", .failed)
        ]
        for (code, text, expected) in cases {
            XCTAssertEqual(botWidgetQueryError(MTRpcError(errorCode: code, errorDescription: text)), expected, "\(code) \(text)")
        }
    }

    /// `updateMessageWidgetData` (upstream integration.md): an absent field is unchanged, an empty one clears it (stored
    /// as none, as a message parsed without it), any other replaces it.
    func testAFieldIsUnchangedClearedOrSet() {
        XCTAssertEqual(messageWidgetDataChange(nil), .unchanged)
        XCTAssertEqual(messageWidgetDataChange(""), .set(nil))
        XCTAssertEqual(messageWidgetDataChange("x"), .set(Data("x".utf8)))
    }
}
