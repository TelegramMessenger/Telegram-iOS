import XCTest
import TelegramCore
import Postbox

final class SynchronizeableChatInputStateTests: XCTestCase {
    // MARK: - Faithful persistence round-trip (the real storage path)

    // SynchronizeableChatInputState is persisted by encoding the enclosing
    // InternalChatInterfaceState via AdaptedPostboxEncoder/Decoder. Both its
    // encode(to:) and init(from:) open a keyed container, so encoding the
    // struct itself directly through the same encoder/decoder is a faithful
    // check of the exact bytes that hit the draft store / cloud.

    func test_textEntities_roundTripsViaAdaptedPostbox() throws {
        let state = SynchronizeableChatInputState(
            replySubject: nil,
            content: .textEntities(text: "hello", entities: [MessageTextEntity(range: 0 ..< 5, type: .Bold)]),
            timestamp: 123,
            textSelection: 1 ..< 3,
            messageEffectId: 42,
            suggestedPost: nil
        )

        let data = try AdaptedPostboxEncoder().encode(state)
        let decoded = try AdaptedPostboxDecoder().decode(SynchronizeableChatInputState.self, from: data)

        XCTAssertEqual(decoded, state)
        if case let .textEntities(text, entities) = decoded.content {
            XCTAssertEqual(text, "hello")
            XCTAssertEqual(entities, [MessageTextEntity(range: 0 ..< 5, type: .Bold)])
        } else {
            XCTFail("expected .textEntities after round-trip")
        }
        // The legacy flat encoding is unchanged: text/entities survive byte-for-byte.
        XCTAssertEqual(decoded.text, "hello")
        XCTAssertEqual(decoded.entities, [MessageTextEntity(range: 0 ..< 5, type: .Bold)])
        XCTAssertEqual(decoded.textSelection, 1 ..< 3)
        XCTAssertEqual(decoded.messageEffectId, 42)
    }

    func test_instantPage_roundTripsViaAdaptedPostbox() throws {
        let page = InstantPage(
            blocks: [.paragraph(.plain("hello"))],
            media: [:],
            isComplete: true,
            rtl: false,
            url: "",
            views: nil
        )
        let state = SynchronizeableChatInputState(
            replySubject: nil,
            content: .instantPage(page),
            timestamp: 7,
            textSelection: nil,
            messageEffectId: nil,
            suggestedPost: nil
        )

        let data = try AdaptedPostboxEncoder().encode(state)
        let decoded = try AdaptedPostboxDecoder().decode(SynchronizeableChatInputState.self, from: data)

        XCTAssertEqual(decoded, state)
        if case let .instantPage(decodedPage) = decoded.content {
            XCTAssertEqual(decodedPage, page)
        } else {
            XCTFail("expected .instantPage after round-trip")
        }
    }

    // MARK: - Derived accessors

    func test_derivedAccessors_textEntities() {
        let state = SynchronizeableChatInputState(
            replySubject: nil,
            content: .textEntities(text: "abc", entities: [MessageTextEntity(range: 0 ..< 3, type: .Italic)]),
            timestamp: 0,
            textSelection: nil,
            messageEffectId: nil,
            suggestedPost: nil
        )
        XCTAssertEqual(state.text, "abc")
        XCTAssertEqual(state.entities, [MessageTextEntity(range: 0 ..< 3, type: .Italic)])
    }

    func test_derivedAccessors_instantPage_fallsBackToPlainTextNoEntities() {
        let page = InstantPage(
            blocks: [.paragraph(.plain("line one")), .paragraph(.plain("line two"))],
            media: [:],
            isComplete: true,
            rtl: false,
            url: "",
            views: nil
        )
        let state = SynchronizeableChatInputState(
            replySubject: nil,
            content: .instantPage(page),
            timestamp: 0,
            textSelection: nil,
            messageEffectId: nil,
            suggestedPost: nil
        )
        // Old clients see the plainText projection and no entities.
        XCTAssertEqual(state.text, page.plainText)
        XCTAssertEqual(state.text, "line one\nline two")
        XCTAssertTrue(state.entities.isEmpty)
    }

    // MARK: - Equatable distinguishes the two content kinds

    func test_equatable_distinguishesContentKinds() {
        let page = InstantPage(
            blocks: [.paragraph(.plain("hello"))],
            media: [:],
            isComplete: true,
            rtl: false,
            url: "",
            views: nil
        )
        let textState = SynchronizeableChatInputState(
            replySubject: nil,
            content: .textEntities(text: "hello", entities: []),
            timestamp: 0,
            textSelection: nil,
            messageEffectId: nil,
            suggestedPost: nil
        )
        let pageState = SynchronizeableChatInputState(
            replySubject: nil,
            content: .instantPage(page),
            timestamp: 0,
            textSelection: nil,
            messageEffectId: nil,
            suggestedPost: nil
        )
        // Same derived plainText, but distinct content kinds → not equal.
        XCTAssertEqual(textState.text, pageState.text)
        XCTAssertNotEqual(textState, pageState)
    }

    // MARK: - The text:entities: forwarding init still produces .textEntities

    func test_textEntitiesInit_forwardsToContent() {
        let state = SynchronizeableChatInputState(
            replySubject: nil,
            text: "fwd",
            entities: [],
            timestamp: 0,
            textSelection: nil,
            messageEffectId: nil,
            suggestedPost: nil
        )
        guard case .textEntities = state.content else {
            return XCTFail("text:entities: init should produce .textEntities content")
        }
        XCTAssertEqual(state.text, "fwd")
    }
}
