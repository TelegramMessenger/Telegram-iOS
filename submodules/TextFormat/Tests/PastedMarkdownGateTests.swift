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

    // MARK: - Source blank lines (`pastedMarkdownContentResolvingBlankLines`)

    private var blankLine: ChatInputBlock {
        return para([])
    }

    func test_blankLines_keptWhenEntityExpressible() {
        var bold = ChatInputInlineAttributes(); bold.bold = true
        let content = ChatInputContent(blocks: [
            para([ChatInputRun(text: "Position:", attributes: bold), ChatInputRun(text: " Butler\nEmployment: Full-time")]),
            blankLine,
            para([ChatInputRun(text: "Second paragraph")])
        ])
        XCTAssertEqual(pastedMarkdownContentResolvingBlankLines(content, keepsBlankLines: true), content)
    }

    func test_blankLines_droppedWhenContentNeedsRichMessage() {
        let content = ChatInputContent(blocks: [
            para([ChatInputRun(text: "Title")], style: .heading2),
            blankLine,
            para([ChatInputRun(text: "Body")]),
            blankLine,
            para([ChatInputRun(text: "item")], list: ChatInputListMembership(marker: .bullet, level: 0))
        ])
        XCTAssertEqual(pastedMarkdownContentResolvingBlankLines(content, keepsBlankLines: true), ChatInputContent(blocks: [
            para([ChatInputRun(text: "Title")], style: .heading2),
            para([ChatInputRun(text: "Body")]),
            para([ChatInputRun(text: "item")], list: ChatInputListMembership(marker: .bullet, level: 0))
        ]))
    }

    func test_blankLines_droppedWhenHostDoesNotKeepThem() {
        let content = ChatInputContent(blocks: [para([ChatInputRun(text: "one")]), blankLine, para([ChatInputRun(text: "two")])])
        XCTAssertEqual(pastedMarkdownContentResolvingBlankLines(content, keepsBlankLines: false), ChatInputContent(blocks: [
            para([ChatInputRun(text: "one")]),
            para([ChatInputRun(text: "two")])
        ]))
    }

    func test_blankLines_doNotMakePlainTextRicher() {
        let content = ChatInputContent(blocks: [para([ChatInputRun(text: "one")]), blankLine, para([ChatInputRun(text: "two")])])
        XCTAssertFalse(pastedMarkdownContentIsRicherThanPlain(pastedMarkdownContentResolvingBlankLines(content, keepsBlankLines: true)))
    }
}
