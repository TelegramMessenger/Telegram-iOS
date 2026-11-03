import XCTest
import Postbox
import AccountContext
import TelegramCore
import TextFormat

/// The composer-facing replace-range: the five autocomplete panels and ChatTextInputPanelNode all go
/// through this. These are the reported scenarios — a structured composer must survive an autocomplete
/// pick, which it did not when the panels rebuilt state from the flattened `inputText`.
final class ChatTextInputStateReplaceRangeTests: XCTestCase {
    private func para(_ text: String, style: ChatInputParagraphStyle = .body) -> ChatInputBlock {
        return .paragraph(ChatInputParagraph(style: style, runs: text.isEmpty ? [] : [ChatInputRun(text: text)]))
    }

    private func state(_ blocks: [ChatInputBlock]) -> ChatTextInputState {
        let content = ChatInputContent(blocks: blocks)
        return ChatTextInputState(content: content, selectionRange: 0 ..< 0)
    }

    private func styles(_ state: ChatTextInputState) -> [ChatInputParagraphStyle?] {
        return state.content.blocks.map { if case let .paragraph(p) = $0 { return p.style } else { return nil } }
    }

    /// Picking a mention with a heading in the composer.
    func test_plainReplacement_keepsTheHeading() {
        let before = self.state([self.para("Title", style: .heading1), self.para("hi @al")])
        // "Title\nhi @al" — "@al" is flat [9, 12).
        let after = before.replacingFlatRange(NSRange(location: 9, length: 3), with: "@alice ")

        XCTAssertEqual(self.styles(after), [.heading1, .body])
        XCTAssertEqual(after.content.plainText, "Title\nhi @alice ")
        XCTAssertEqual(after.selectionRange, 16 ..< 16, "collapsed caret just past the insert")
    }

    /// Picking a custom emoji: the entity has to land on the model, not just the text.
    func test_attributedReplacement_carriesTheEntity_andKeepsTheHeading() throws {
        let before = self.state([self.para("Title", style: .heading1), self.para("hi :sm")])
        let emoji = ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 7, file: nil)
        let replacement = NSAttributedString(string: "\u{FFFC}", attributes: [ChatTextInputAttributes.customEmoji: emoji])

        let after = before.replacingFlatRange(NSRange(location: 9, length: 3), with: replacement)

        XCTAssertEqual(self.styles(after), [.heading1, .body])
        guard case let .paragraph(p) = after.content.blocks[1],
              case let .customEmoji(fileId, _, _) = try XCTUnwrap(p.runs.last).attributes.entity else {
            return XCTFail("expected the emoji entity on the model")
        }
        XCTAssertEqual(fileId, 7)
    }

    /// A text mention lands as a `.mention` entity, not as bare text.
    func test_mentionReplacement_carriesThePeerId() throws {
        let before = self.state([self.para("hi @al")])
        let peerId = EnginePeer.Id(3)
        let replacement = NSMutableAttributedString()
        replacement.append(NSAttributedString(string: "Alice", attributes: [
            ChatTextInputAttributes.textMention: ChatTextInputTextMentionAttribute(peerId: peerId)
        ]))
        replacement.append(NSAttributedString(string: " "))

        let after = before.replacingFlatRange(NSRange(location: 3, length: 3), with: replacement)

        guard case let .paragraph(p) = after.content.blocks[0],
              case let .mention(resolved) = try XCTUnwrap(p.runs.first(where: { $0.text == "Alice" })).attributes.entity else {
            return XCTFail("expected a mention entity")
        }
        XCTAssertEqual(resolved, peerId)
        XCTAssertEqual(after.content.plainText, "hi Alice ")
    }

    /// Exactly the characters named by the range are replaced — the mention branch widens its range by
    /// one to eat the "@", and an off-by-one here would change what it eats.
    func test_replacesExactlyTheNamedCharacters() {
        let before = self.state([self.para("hi @al there")])
        let after = before.replacingFlatRange(NSRange(location: 3, length: 3), with: "X")
        XCTAssertEqual(after.content.plainText, "hi X there")
    }

    /// A deletion (the clear button's shape).
    func test_emptyReplacementDeletes() {
        let before = self.state([self.para("Title", style: .heading1), self.para("abcdef")])
        let after = before.replacingFlatRange(NSRange(location: 8, length: 2), with: "")
        XCTAssertEqual(self.styles(after), [.heading1, .body])
        XCTAssertEqual(after.content.plainText, "Title\nabef")
    }
}
