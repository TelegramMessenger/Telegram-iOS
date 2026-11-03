// Tests/RichTextEditorCoreTests/DocumentFragmentAtomAndPartialItemTests.swift
import XCTest
@testable import RichTextEditorCore

/// Core halves of the composer harness's p16 fixes (2026-09-25):
///
/// - A range PART of one list item's text extracts as text, not as an item (`extractFragment`), so a
///   paste folds it inline; all of an item's text, or a range past it, still extracts as the item
///   (harness `HarnessPartialFragmentPasteTests`).
/// - A fragment spliced into a text region that holds RUNS (a pull quote's body, a details title, a
///   caption) keeps its inline atoms — a pull-quote fragment used to take the plain-text branch and
///   left a custom emoji as a bare `U+FFFC` (harness `HarnessPullQuoteFragmentAtomPasteTests`).
/// - PLAIN text — code, a one-line field, the plain-text pasteboard, a table converted to text — takes an
///   atom's text (`runsPlainText`, which `blockPlainText` uses): a custom emoji its alt text, never its
///   attachment character (harness `HarnessAtomFlatteningTests`).
final class DocumentFragmentAtomAndPartialItemTests: XCTestCase {
    private func item(_ text: String, checked: Bool? = nil) -> Block {
        .paragraph(ParagraphBlock(id: .generate(), style: .body,
                                  list: ListMembership(marker: checked == nil ? .bullet : .checklist, checked: checked),
                                  runs: [TextRun(text: text)]))
    }

    private func emojiRun(alt: String? = "😀") -> TextRun {
        TextRun(text: "\u{FFFC}", attributes: CharacterAttributes(emoji: EmojiRef(id: "1", instanceID: "i1", altText: alt)))
    }

    private func bareAttachments(_ runs: [TextRun]) -> Int {
        runs.filter { $0.text.contains("\u{FFFC}") && $0.attributes.emoji == nil && $0.attributes.button == nil }.count
    }

    // MARK: partial list item

    func test_extract_partOfOneItem_isText() {
        // [• "one"]: text at globals 1..<4.
        let fragment = Document(blocks: [item("one")]).extractFragment(globalFrom: 2, globalTo: 4)
        guard case .paragraph(let p)? = fragment.blocks.first else { return XCTFail("no paragraph") }
        XCTAssertEqual(p.text, "ne")
        XCTAssertNil(p.list, "a part of one item's text is text")
        XCTAssertTrue(isInlineMergeable(.paragraph(p), intoHostStyle: .body))
    }

    func test_extract_partOfACheckedItem_carriesNoCheck() {
        let fragment = Document(blocks: [item("done", checked: true)]).extractFragment(globalFrom: 2, globalTo: 4)
        guard case .paragraph(let p)? = fragment.blocks.first else { return XCTFail("no paragraph") }
        XCTAssertNil(p.list)
    }

    /// Control: all of an item's text is still the item.
    func test_extract_allOfAnItemsText_isTheItem() {
        let fragment = Document(blocks: [item("one")]).extractFragment(globalFrom: 1, globalTo: 4)
        guard case .paragraph(let p)? = fragment.blocks.first else { return XCTFail("no paragraph") }
        XCTAssertEqual(p.list?.marker, .bullet)
    }

    /// Control: a range reaching past one item keeps every item it covers.
    func test_extract_acrossItems_keepsTheItems() {
        let document = Document(blocks: [item("one"), item("two")])
        // "ne" of the first item through "t" of the second.
        let fragment = document.extractFragment(globalFrom: 2, globalTo: document.globalTextStart(ofBlockAt: 1) + 1)
        XCTAssertEqual(fragment.blocks.count, 2)
        for block in fragment.blocks {
            guard case .paragraph(let p) = block else { return XCTFail("not a paragraph") }
            XCTAssertEqual(p.list?.marker, .bullet)
        }
    }

    func test_paste_partOfAnItem_intoAnotherItem_foldsInline() {
        let document = Document(blocks: [item("one"), item("two")])
        let fragment = document.extractFragment(globalFrom: 2, globalTo: 4)
        let caret = document.globalTextStart(ofBlockAt: 1) + 1
        let result = document.replacingRange(globalFrom: caret, globalTo: caret, with: fragment)
        XCTAssertEqual(result.document.blocks.count, 2)
        guard case .paragraph(let p) = result.document.blocks[1] else { return XCTFail("not a paragraph") }
        XCTAssertEqual(p.text, "tnewo")
        XCTAssertEqual(p.list?.marker, .bullet)
    }

    // MARK: atoms into a pull quote / a one-line region

    func test_pullQuoteFragment_pastedIntoAPullQuote_keepsItsCustomEmoji() {
        let quote = PullQuote(id: .generate(), runs: [TextRun(text: "pq "), emojiRun(), TextRun(text: " x")])
        let document = Document(blocks: [.pullQuote(quote)])
        // The pull quote's text starts two tokens in; copy "pq 😀" (0..<4).
        let fragment = document.extractFragment(globalFrom: 2, globalTo: 6)
        guard case .pullQuote? = fragment.blocks.first else { return XCTFail("precondition: a pull-quote fragment") }
        let result = document.replacingRange(globalFrom: 4, globalTo: 4, with: fragment)
        guard case .pullQuote(let pasted) = result.document.blocks[0] else { return XCTFail("the pull quote is gone") }
        XCTAssertEqual(bareAttachments(pasted.runs), 0, "the pasted custom emoji lost its entity")
        XCTAssertEqual(pasted.runs.filter { $0.attributes.emoji != nil }.count, 2)
        let ids = Set(pasted.runs.compactMap { $0.attributes.emoji?.instanceID })
        XCTAssertEqual(ids.count, 2, "the pasted emoji must be a fresh occurrence")
    }

    func test_pullQuoteFragment_pastedIntoADetailsTitle_keepsItsCustomEmoji() {
        let fragment = Document(blocks: [.pullQuote(PullQuote(id: .generate(), runs: [TextRun(text: "a "), emojiRun()]))])
        let details = DetailsBlock(id: .generate(), title: [TextRun(text: "T")],
                                   children: [.paragraph(ParagraphBlock(id: .generate(), runs: [TextRun(text: "b")]))])
        let document = Document(blocks: [.details(details)])
        // The title's text starts two tokens in; paste after "T".
        let result = document.replacingRange(globalFrom: 3, globalTo: 3, with: fragment)
        guard case .details(let pasted) = result.document.blocks[0] else { return XCTFail("the details is gone") }
        XCTAssertEqual(bareAttachments(pasted.title), 0)
        XCTAssertEqual(pasted.title.filter { $0.attributes.emoji != nil }.count, 1)
    }

    // MARK: atoms as plain text

    func test_plainText_takesAnAtomsText() {
        let button = ButtonRef(label: [TextRun(text: "Go")], action: .url("https://t.me"))
        let runs = [TextRun(text: "a "), emojiRun(), TextRun(text: " "), emojiRun(alt: nil),
                    TextRun(text: "\u{FFFC}", attributes: CharacterAttributes(button: button)),
                    TextRun(text: "x^2", attributes: CharacterAttributes(formula: "x^2"))]
        XCTAssertEqual(runsPlainText(runs), "a 😀 Gox^2")
        XCTAssertEqual(blockPlainText(.paragraph(ParagraphBlock(id: .generate(), runs: runs))), "a 😀 Gox^2")
        XCTAssertEqual(blockPlainText(.pullQuote(PullQuote(id: .generate(), runs: runs))), "a 😀 Gox^2")
    }

    func test_tableFlattenedText_takesAnAtomsText() {
        let cell = Cell(id: .generate(), blocks: [.paragraph(ParagraphBlock(id: .generate(), runs: [TextRun(text: "a"), emojiRun()]))])
        let other = Cell(id: .generate(), blocks: [.paragraph(ParagraphBlock(id: .generate(), runs: [TextRun(text: "yb")]))])
        let table = TableBlock(id: .generate(), columns: [ColumnSpec(width: 90), ColumnSpec(width: 90)],
                               rows: [Row(id: .generate(), cells: [cell, other])])
        XCTAssertEqual(tableFlattenedText(table), ["a😀 yb"])
    }

    func test_emojiFragment_pastedIntoCode_becomesItsAltText() {
        let code = CodeBlock(id: .generate(), runs: [TextRun(text: "let")])
        let document = Document(blocks: [.code(code)])
        let fragment = Document(blocks: [.paragraph(ParagraphBlock(id: .generate(), runs: [emojiRun()]))])
        let caret = document.globalTextStart(ofBlockAt: 0) + 3
        let result = document.replacingRange(globalFrom: caret, globalTo: caret, with: fragment)
        guard case .code(let pasted) = result.document.blocks[0] else { return XCTFail("the code block is gone") }
        XCTAssertEqual(pasted.text, "let😀")
    }
}
