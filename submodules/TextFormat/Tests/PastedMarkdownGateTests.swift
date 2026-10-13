import XCTest
import Postbox
import TelegramCore
import TextFormat

final class PastedMarkdownGateTests: XCTestCase {
    private func para(_ runs: [ChatInputRun], style: ChatInputParagraphStyle = .body, list: ChatInputListMembership? = nil) -> ChatInputBlock {
        return .paragraph(ChatInputParagraph(style: style, list: list, runs: runs))
    }

    func test_singlePlainParagraph_isNotRicher() {
        let content = ChatInputContent(blocks: [para([ChatInputRun(text: "hello world")])])
        XCTAssertFalse(pastedMarkdownContentIsRicherThanPlain(content))
    }

    func test_multiplePlainParagraphs_isNotRicher() {
        let content = ChatInputContent(blocks: [
            para([ChatInputRun(text: "line one")]),
            para([ChatInputRun(text: "line two")])
        ])
        XCTAssertFalse(pastedMarkdownContentIsRicherThanPlain(content))
    }

    func test_emptyContent_isNotRicher() {
        XCTAssertFalse(pastedMarkdownContentIsRicherThanPlain(ChatInputContent(blocks: [])))
    }

    func test_inlineBold_isRicher() {
        var bold = ChatInputInlineAttributes(); bold.bold = true
        let content = ChatInputContent(blocks: [para([ChatInputRun(text: "hi", attributes: bold)])])
        XCTAssertTrue(pastedMarkdownContentIsRicherThanPlain(content))
    }

    func test_heading_isRicher() {
        let content = ChatInputContent(blocks: [para([ChatInputRun(text: "Title")], style: .heading1)])
        XCTAssertTrue(pastedMarkdownContentIsRicherThanPlain(content))
    }

    func test_codeBlock_isRicher() {
        let content = ChatInputContent(blocks: [.code(ChatInputCode(language: nil, runs: [ChatInputRun(text: "print(1)")]))])
        XCTAssertTrue(pastedMarkdownContentIsRicherThanPlain(content))
    }
}
