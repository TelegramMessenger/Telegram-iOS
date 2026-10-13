import XCTest
import Foundation
import TelegramCore
@testable import TextFormat

/// Inline formatting INSIDE a quote, across the flat `NSAttributedString` projection
/// (`ChatTextInputState.inputText` → `attributedString(from:)`).
///
/// This projection is not only what the legacy composer field displays — the normal send path
/// serialises it (`expandedInputStateAttributedString(composeInputState.inputText)` → entities), and
/// so does the draft sync. So anything it drops is dropped from the sent message too: the projection
/// used to render an expanded quote as `content.plainText`, and a custom emoji inside one arrived at
/// the recipient as its `alt` text.
final class ChatInputQuoteInlineAttributeTests: XCTestCase {
    private let emojiFileId: Int64 = 1234567890

    private func customEmojiRun(_ text: String) -> ChatInputRun {
        var attributes = ChatInputInlineAttributes()
        attributes.entity = .customEmoji(fileId: self.emojiFileId, file: nil, enableAnimation: true)
        return ChatInputRun(text: text, attributes: attributes)
    }

    private func boldRun(_ text: String) -> ChatInputRun {
        var attributes = ChatInputInlineAttributes()
        attributes.bold = true
        return ChatInputRun(text: text, attributes: attributes)
    }

    private func quote(collapsed: Bool, runs: [ChatInputRun]) -> ChatInputContent {
        return ChatInputContent(blocks: [
            .blockQuote(ChatInputBlockQuote(
                content: ChatInputContent(blocks: [.paragraph(ChatInputParagraph(runs: runs))]),
                collapsed: collapsed))
        ])
    }

    /// What the send path actually serialises.
    private func sendableString(_ content: ChatInputContent) -> NSAttributedString {
        return expandedInputStateAttributedString(attributedString(from: content))
    }

    private func customEmojiIds(in string: NSAttributedString) -> [Int64] {
        var ids: [Int64] = []
        string.enumerateAttribute(ChatTextInputAttributes.customEmoji, in: NSRange(location: 0, length: string.length), options: []) { value, _, _ in
            if let value = value as? ChatTextInputTextCustomEmojiAttribute {
                ids.append(value.fileId)
            }
        }
        return ids
    }

    // MARK: The regression

    func test_customEmojiSurvivesAnExpandedQuote() {
        let content = self.quote(collapsed: false, runs: [
            ChatInputRun(text: "look "),
            self.customEmojiRun("🌟")
        ])
        XCTAssertEqual(self.customEmojiIds(in: self.sendableString(content)), [self.emojiFileId])
    }

    /// The collapsed form always worked — it stows the whole attributed string in `.collapsedBlock`,
    /// which `expandedInputStateAttributedString` splices back in — so the bug only showed on expanded
    /// quotes. Pinned so the two forms cannot drift apart again.
    func test_customEmojiSurvivesACollapsedQuote() {
        let content = self.quote(collapsed: true, runs: [
            ChatInputRun(text: "look "),
            self.customEmojiRun("🌟")
        ])
        XCTAssertEqual(self.customEmojiIds(in: self.sendableString(content)), [self.emojiFileId])
    }

    /// Custom emoji was the reported symptom; the projection was dropping EVERY inline attribute in a
    /// quote, so fixing only the emoji would have left bold, links and the rest still failing.
    func test_boldSurvivesAnExpandedQuote() {
        let string = self.sendableString(self.quote(collapsed: false, runs: [self.boldRun("shouted")]))
        var foundBold = false
        string.enumerateAttribute(ChatTextInputAttributes.bold, in: NSRange(location: 0, length: string.length), options: []) { value, _, _ in
            if value != nil {
                foundBold = true
            }
        }
        XCTAssertTrue(foundBold)
    }

    // MARK: The things the fix must not disturb

    /// The projection's characters are the flat axis every selection offset is measured against, so
    /// recursing into the quote instead of taking `plainText` must not change a single one.
    func test_flatTextIsUnchangedByTheRecursion() {
        let content = self.quote(collapsed: false, runs: [
            ChatInputRun(text: "look "),
            self.customEmojiRun("🌟"),
            ChatInputRun(text: " there")
        ])
        XCTAssertEqual(attributedString(from: content).string, content.plainText)
    }

    /// A multi-paragraph quote still separates its paragraphs with exactly one newline, and still
    /// matches `plainText`.
    func test_flatTextIsUnchangedForAMultiParagraphQuote() {
        let content = ChatInputContent(blocks: [
            .blockQuote(ChatInputBlockQuote(
                content: ChatInputContent(blocks: [
                    .paragraph(ChatInputParagraph(runs: [ChatInputRun(text: "first")])),
                    .paragraph(ChatInputParagraph(runs: [self.customEmojiRun("🌟")]))
                ]),
                collapsed: false))
        ])
        XCTAssertEqual(attributedString(from: content).string, content.plainText)
        XCTAssertEqual(self.customEmojiIds(in: self.sendableString(content)), [self.emojiFileId])
    }

    /// The whole quote is still marked as a quote — that is what becomes `messageEntityBlockquote`.
    func test_theQuoteAttributeStillCoversTheWholeQuote() {
        let content = self.quote(collapsed: false, runs: [
            ChatInputRun(text: "look "),
            self.customEmojiRun("🌟")
        ])
        let string = attributedString(from: content)
        var covered = 0
        string.enumerateAttribute(ChatTextInputAttributes.block, in: NSRange(location: 0, length: string.length), options: []) { value, range, _ in
            if let value = value as? ChatTextInputTextQuoteAttribute, case .quote = value.kind {
                covered += range.length
            }
        }
        XCTAssertEqual(covered, string.length)
    }

    /// A code block nested in a quote keeps its own block kind: the quote attribute fills the gaps
    /// around it rather than overwriting the more specific one.
    func test_nestedCodeBlockKeepsItsOwnBlockKind() {
        let content = ChatInputContent(blocks: [
            .blockQuote(ChatInputBlockQuote(
                content: ChatInputContent(blocks: [
                    .paragraph(ChatInputParagraph(runs: [ChatInputRun(text: "see")])),
                    .code(ChatInputCode(language: "swift", runs: [ChatInputRun(text: "let x = 1")]))
                ]),
                collapsed: false))
        ])
        let string = attributedString(from: content)
        var sawCode = false
        string.enumerateAttribute(ChatTextInputAttributes.block, in: NSRange(location: 0, length: string.length), options: []) { value, _, _ in
            if let value = value as? ChatTextInputTextQuoteAttribute, case .code = value.kind {
                sawCode = true
            }
        }
        XCTAssertTrue(sawCode, "the inner code block must not be overwritten by the quote attribute")
    }
}
