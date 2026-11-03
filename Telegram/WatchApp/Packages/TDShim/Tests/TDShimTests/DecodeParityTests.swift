import XCTest
@testable import TDShim

final class DecodeParityTests: XCTestCase {

    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    func test_message_textContent_decodes() throws {
        let json = """
        {
          "@type":"message",
          "author_signature":"","auto_delete_in":0,"can_be_saved":false,
          "chat_id":777,"contains_unread_mention":false,"contains_unread_poll_votes":false,
          "content":{"@type":"messageText","text":{"@type":"formattedText","entities":[],"text":"hi"}},
          "date":1715126400,"edit_date":0,"effect_id":"0","fact_check":null,"forward_info":null,
          "has_timestamped_media":false,"id":10,"import_info":null,"interaction_info":null,
          "is_channel_post":false,"is_from_offline":false,"is_outgoing":false,
          "is_paid_star_suggested_post":false,"is_paid_ton_suggested_post":false,"is_pinned":false,
          "media_album_id":"0","paid_message_star_count":0,
          "reply_markup":null,"reply_to":null,"restriction_info":null,"scheduling_state":null,
          "self_destruct_in":0.0,"self_destruct_type":null,"self_destruct_state":null,
          "sender_boost_count":0,"sender_business_bot_user_id":0,
          "sender_id":{"@type":"messageSenderUser","user_id":200},
          "sender_tag":"","sending_state":null,"suggested_post_info":null,"summary_language_code":"",
          "topic_id":null,"unread_reactions":[],"via_bot_user_id":0
        }
        """
        let m = try decoder().decode(Message.self, from: Data(json.utf8))
        XCTAssertEqual(m.id, 10)
        XCTAssertEqual(m.chatId, 777)
        guard case .messageText(let t) = m.content else { return XCTFail("expected messageText") }
        XCTAssertEqual(t.text.text, "hi")
    }

    func test_tdInt64_decodesFromString() throws {
        // TDLib serializes 64-bit ids as quoted strings; TdInt64 must parse them.
        let v = try decoder().decode(TdInt64.self, from: Data("\"123456789012345\"".utf8))
        XCTAssertEqual(v.rawValue, 123456789012345)
    }

    func test_unknownType_foldsToUnsupported() throws {
        let json = #"{"@type":"messageThisDoesNotExist","whatever":1}"#
        let c = try decoder().decode(MessageContent.self, from: Data(json.utf8))
        guard case .unsupported = c else { return XCTFail("unknown @type should fold to .unsupported") }
    }

    func test_unseededUpdate_foldsToUnsupported() throws {
        // A real TDLib update we did NOT seed must not crash; it folds to .unsupported.
        let json = #"{"@type":"updateChatThemes","chat_themes":[]}"#
        let u = try decoder().decode(Update.self, from: Data(json.utf8))
        guard case .unsupported = u else { return XCTFail("unseeded update should fold to .unsupported") }
    }
}
