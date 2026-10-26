import XCTest
import UIKit
import TelegramCore
import TextFormat
import AccountContext
import ChatPresentationInterfaceState

/// The LEGACY composer's emoji-keyboard insert (`chatTextInputStateInsertingText`) inherits the
/// formatting of the character before the caret, so an emoji typed inside a spoiler stays hidden.
/// It inherited inline CODE too, which put a custom emoji inside a `Code` entity — an entity the
/// platform lets contain no other — so the message went out with overlapping `Code` and
/// `CustomEmoji` entities and the emoji was liable to be dropped. Found in review of the squash
/// (2026-10-12). Tier 1, and below the panel: the transform is a pure function the chat calls.
final class HarnessEmojiInsertAfterInlineCodeTests: XCTestCase {
    private let customEmojiAttribute = ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 5_000_000_001, file: nil)

    private func customEmoji() -> NSAttributedString {
        NSAttributedString(string: "😀", attributes: [ChatTextInputAttributes.customEmoji: customEmojiAttribute])
    }

    private func insert(_ text: NSAttributedString, after prefix: NSAttributedString) -> NSAttributedString {
        let state = ChatTextInputState(inputText: prefix, selectionRange: prefix.length ..< prefix.length)
        return chatTextInputStateInsertingText(state, text: text).inputText
    }

    private func attributes(of inserted: NSAttributedString, in result: NSAttributedString, after prefixLength: Int) -> [NSAttributedString.Key: Any] {
        XCTAssertGreaterThan(result.length, prefixLength, "precondition: nothing was inserted")
        return result.attributes(at: prefixLength, effectiveRange: nil)
    }

    func testACustomEmojiAfterInlineCodeIsNotCode() {
        let code = NSAttributedString(string: "let", attributes: [ChatTextInputAttributes.monospace: true as NSNumber])
        let result = insert(customEmoji(), after: code)
        let inserted = attributes(of: customEmoji(), in: result, after: code.length)
        XCTAssertNotNil(inserted[ChatTextInputAttributes.customEmoji], "precondition: the custom emoji landed")
        XCTAssertNil(inserted[ChatTextInputAttributes.monospace], "a custom emoji inherited inline code: \(inserted)")

        let entities = generateChatInputTextEntities(result)
        let codeRanges = entities.compactMap { entity -> Range<Int>? in
            if case .Code = entity.type { return entity.range } else { return nil }
        }
        let emojiRanges = entities.compactMap { entity -> Range<Int>? in
            if case .CustomEmoji = entity.type { return entity.range } else { return nil }
        }
        XCTAssertFalse(emojiRanges.isEmpty, "precondition: a CustomEmoji entity is sent")
        XCTAssertFalse(codeRanges.contains { code in emojiRanges.contains { $0.overlaps(code) } },
                       "Code and CustomEmoji overlap: \(entities)")
    }

    /// **A pin, not a regression.** The same question for a CODE BLOCK, the other half of
    /// `Pre`/`Code`: the insert inherits the block at the caret, and the review of the fix wave
    /// (2026-10-12) predicted a `CustomEmoji` sent inside a `Pre`. It does not happen: the returned
    /// `ChatTextInputState` stores a `ChatInputContent`, whose code block holds plain runs, so the emoji
    /// arrives as its alt text and the block stays whole — the engine editor's rule for a code body
    /// (`plainCodeRuns`) reached by another route. Kept so a change to either half is seen.
    func testACustomEmojiInsideACodeBlockGoesInAsItsTextAndKeepsTheBlockWhole() {
        let block = ChatTextInputTextQuoteAttribute(kind: .code(language: "swift"), isCollapsed: false)
        let code = NSAttributedString(string: "let x", attributes: [ChatTextInputAttributes.block: block])
        let state = ChatTextInputState(inputText: code, selectionRange: 3 ..< 3)
        let result = chatTextInputStateInsertingText(state, text: customEmoji()).inputText

        XCTAssertEqual(result.string, "let😀 x")
        XCTAssertNil(result.attributes(at: 3, effectiveRange: nil)[ChatTextInputAttributes.customEmoji],
                     "the model's code block held a custom emoji")
        var blockRanges: [NSRange] = []
        result.enumerateAttribute(ChatTextInputAttributes.block, in: NSRange(location: 0, length: result.length), options: []) { value, range, _ in
            if value != nil { blockRanges.append(range) }
        }
        XCTAssertEqual(blockRanges, [NSRange(location: 0, length: result.length)], "the code block did not stay one block")

        let entities = generateChatInputTextEntities(result)
        XCTAssertFalse(entities.contains { if case .CustomEmoji = $0.type { return true } else { return false } },
                       "a custom emoji was sent inside a Pre: \(entities)")
        XCTAssertTrue(entities.contains { if case .Pre = $0.type { return true } else { return false } }, "precondition: a Pre is sent")
    }

    /// Control: inside a QUOTE block a custom emoji stays a custom emoji and continues the quote.
    func testACustomEmojiInsideAQuoteStaysACustomEmojiInTheQuote() {
        let block = ChatTextInputTextQuoteAttribute(kind: .quote, isCollapsed: false)
        let quote = NSAttributedString(string: "quoted", attributes: [ChatTextInputAttributes.block: block])
        let state = ChatTextInputState(inputText: quote, selectionRange: 3 ..< 3)
        let result = chatTextInputStateInsertingText(state, text: customEmoji()).inputText
        let inserted = result.attributes(at: 3, effectiveRange: nil)
        XCTAssertNotNil(inserted[ChatTextInputAttributes.customEmoji])
        XCTAssertNotNil(inserted[ChatTextInputAttributes.block])
    }

    /// Control: plain text typed after inline code still continues it — only the atom is kept out.
    func testPlainTextAfterInlineCodeStaysCode() {
        let code = NSAttributedString(string: "let", attributes: [ChatTextInputAttributes.monospace: true as NSNumber])
        let result = insert(NSAttributedString(string: "😀"), after: code)
        XCTAssertNotNil(attributes(of: NSAttributedString(string: "😀"), in: result, after: code.length)[ChatTextInputAttributes.monospace])
    }

    /// Control: what the inheritance is FOR still holds — a custom emoji inside a spoiler stays hidden.
    func testACustomEmojiAfterASpoilerStaysHidden() {
        let spoiler = NSAttributedString(string: "secret", attributes: [ChatTextInputAttributes.spoiler: true as NSNumber])
        let result = insert(customEmoji(), after: spoiler)
        XCTAssertNotNil(attributes(of: customEmoji(), in: result, after: spoiler.length)[ChatTextInputAttributes.spoiler])
    }

    /// Control: a custom emoji after bold text still inherits the bold (a bold custom emoji is fine on
    /// the wire; only `Code`/`Pre` exclude other entities).
    func testACustomEmojiAfterBoldStaysBold() {
        let bold = NSAttributedString(string: "bold", attributes: [ChatTextInputAttributes.bold: true as NSNumber])
        let result = insert(customEmoji(), after: bold)
        XCTAssertNotNil(attributes(of: customEmoji(), in: result, after: bold.length)[ChatTextInputAttributes.bold])
    }
}
