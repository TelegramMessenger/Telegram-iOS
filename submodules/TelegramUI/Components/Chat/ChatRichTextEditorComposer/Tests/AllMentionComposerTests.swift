import XCTest
import AccountContext
import TelegramCore
import TextFormat
import RichTextEditorCore
@testable import ChatRichTextEditorComposer

final class AllMentionComposerTests: XCTestCase {
    func testAutocompleteReplacementUsesUTF16AndPreservesHeading() throws {
        let content = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .heading1, runs: [ChatInputRun(text: "Пятница")])),
            .paragraph(ChatInputParagraph(runs: [ChatInputRun(text: "👋 @al")]))
        ])
        // "Пятница\n👋 @al": the UTF-16 query including @ is [11, 14).
        let before = ChatTextInputState(content: content, selectionRange: 14 ..< 14)
        let replacement = NSMutableAttributedString(attributedString: allMentionInputString())
        replacement.append(NSAttributedString(string: " "))
        let after = before.replacingFlatRange(NSRange(location: 11, length: 3), with: replacement)

        XCTAssertEqual(after.content.plainText, "Пятница\n👋 @all ")
        XCTAssertEqual(after.selectionRange, 16 ..< 16)
        guard case let .paragraph(heading) = after.content.blocks[0],
              case let .paragraph(body) = after.content.blocks[1] else {
            return XCTFail("Expected both paragraphs to survive")
        }
        XCTAssertEqual(heading.style, .heading1)
        XCTAssertEqual(try XCTUnwrap(body.runs.first(where: { $0.text == "@all" })).attributes.entity, .allMention)
        XCTAssertNil(try XCTUnwrap(body.runs.last).attributes.entity, "The trailing space must not extend the atom")
    }

    func testNativeDocumentRoundTripKeepsCollectiveIdentityAndOrdinaryMention() {
        let content = ChatInputContent(blocks: [.paragraph(ChatInputParagraph(runs: [
            ChatInputRun(text: "@all", attributes: ChatInputInlineAttributes(entity: .allMention)),
            ChatInputRun(text: " "),
            ChatInputRun(text: "Мария", attributes: ChatInputInlineAttributes(entity: .mention(EnginePeer.Id(123))))
        ]))])
        let editorDocument = document(fromChatInputContent: content, registerEmoji: { _, _ in EmojiRef(id: "0", instanceID: "0") }, registerMedia: { _ in "" })
        let restored = chatInputContent(fromDocument: editorDocument, resolveEmoji: { _ in nil }, resolveMedia: { _ in nil })
        XCTAssertEqual(restored, content)
    }
}
