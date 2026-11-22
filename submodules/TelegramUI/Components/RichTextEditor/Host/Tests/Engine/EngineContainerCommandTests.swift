import XCTest
import UIKit
import RichTextEditorCore
@testable import RichTextEngineEditor

/// R7, slice 3: the Format-menu commands that CREATE a container.
///
/// Semantics mirror the legacy editor's `DocumentCanvasView+ParagraphFormat` exactly, because both
/// composers drive the same Format menu and a user switching editors must not get different results:
///
///  - toggle ON joins every touched block into ONE container, separated by "\n";
///  - toggle OFF (the selection is already exactly that container) splits it back on "\n";
///  - a selection spanning a block with no text representation is REFUSED, not silently destructive.
///
/// The one deliberate difference between the two commands is also legacy's: a code block flattens to
/// PLAIN text, a pull quote PRESERVES inline formatting. That asymmetry is tested directly, since it
/// is the sort of thing a shared helper quietly erases.
@available(iOS 18.4, *)
final class EngineContainerCommandTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor)
        window.makeKeyAndVisible()
    }

    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func paragraphs(_ texts: [String]) -> Document {
        Document(blocks: texts.enumerated().map { index, text in
            .paragraph(ParagraphBlock(id: BlockID("p\(index)"), runs: [TextRun(text: text)]))
        })
    }

    func test_makeCodeBlockTurnsTheCaretParagraphIntoACodeBlock() {
        editor.document = paragraphs(["hello"])
        editor.engineSelectedRange = NSRange(location: 2, length: 0)

        editor.makeCodeBlock()

        XCTAssertEqual(editor.document.blocks.count, 1)
        guard case let .code(code) = editor.document.blocks[0] else {
            return XCTFail("not a code block: \(editor.document.blocks[0])")
        }
        XCTAssertEqual(code.runs.map(\.text).joined(), "hello")
    }

    func test_makeCodeBlockJoinsEveryTouchedParagraphWithNewlines() {
        editor.document = paragraphs(["one", "two"])
        // The flat composer axis joins paragraphs with "\n": "one\ntwo".
        editor.engineSelectedRange = NSRange(location: 0, length: 7)

        editor.makeCodeBlock()

        XCTAssertEqual(editor.document.blocks.count, 1, "the two paragraphs become ONE code block")
        guard case let .code(code) = editor.document.blocks[0] else {
            return XCTFail("not a code block: \(editor.document.blocks[0])")
        }
        XCTAssertEqual(code.runs.map(\.text).joined(), "one\ntwo")
    }

    func test_makeCodeBlockOnACodeBlockTogglesItBackToParagraphs() {
        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), runs: [TextRun(text: "one\ntwo")])),
        ])
        editor.engineSelectedRange = NSRange(location: 0, length: 0)

        editor.makeCodeBlock()

        XCTAssertEqual(editor.document.blocks.count, 2, "split back on the newline")
        for block in editor.document.blocks {
            guard case .paragraph = block else {
                return XCTFail("toggled off into \(block), not a paragraph")
            }
        }
        XCTAssertEqual(editor.document.blocks.compactMap { $0.asParagraph?.runs.map(\.text).joined() },
                       ["one", "two"])
    }

    /// The documented asymmetry, half one.
    func test_makeCodeBlockFlattensInlineFormatting() {
        var bold = CharacterAttributes()
        bold.bold = true
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"),
                                      runs: [TextRun(text: "a", attributes: bold),
                                             TextRun(text: "b")])),
        ])
        editor.engineSelectedRange = NSRange(location: 0, length: 2)

        editor.makeCodeBlock()

        guard case let .code(code) = editor.document.blocks[0] else {
            return XCTFail("not a code block")
        }
        XCTAssertEqual(code.runs.map(\.text).joined(), "ab")
        XCTAssertFalse(code.runs.contains { $0.attributes.bold },
                       "code is plain text — bold inside it would be sent as markup in a code fence")
    }

    /// The documented asymmetry, half two. This is the pair that a shared implementation erases.
    func test_makePullQuotePreservesInlineFormatting() {
        var bold = CharacterAttributes()
        bold.bold = true
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"),
                                      runs: [TextRun(text: "a", attributes: bold),
                                             TextRun(text: "b")])),
        ])
        editor.engineSelectedRange = NSRange(location: 0, length: 2)

        editor.makePullQuote()

        guard case let .pullQuote(quote) = editor.document.blocks[0] else {
            return XCTFail("not a pull quote: \(editor.document.blocks[0])")
        }
        XCTAssertEqual(quote.runs.map(\.text).joined(), "ab")
        XCTAssertTrue(quote.runs.contains { $0.attributes.bold },
                      "a pull quote keeps inline formatting, unlike a code block")
    }

    func test_makePullQuoteOnAPullQuoteTogglesItBackToParagraphs() {
        editor.document = Document(blocks: [
            .pullQuote(PullQuote(id: BlockID("q0"), runs: [TextRun(text: "one\ntwo")])),
        ])
        editor.engineSelectedRange = NSRange(location: 0, length: 0)

        editor.makePullQuote()

        XCTAssertEqual(editor.document.blocks.count, 2)
        XCTAssertEqual(editor.document.blocks.compactMap { $0.asParagraph?.runs.map(\.text).joined() },
                       ["one", "two"])
    }

    /// A container command must never be a silent delete. `.media` has no text representation, so a
    /// selection spanning one is refused outright — the legacy editor's rule, and the reason the
    /// refusal happens BEFORE the edit rather than inside it.
    func test_aSelectionSpanningANonTextBlockIsRefused() {
        let media = MediaBlock(id: BlockID("m0"), mediaID: "m", kind: .image,
                               naturalSize: Size2D(width: 100, height: 100))
        let before = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "one")])),
            .media(media),
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "two")])),
        ])
        // `.media` still traps in the bridge, so this document cannot be SET on the editor. Assert on
        // the decision function instead, which is where the refusal lives and what the command asks.
        XCTAssertFalse(RichTextEngineEditorView.containerCommandIsAllowed(over: before.blocks),
                       "a range covering media must be refused; joining it would delete the media")
        XCTAssertTrue(RichTextEngineEditorView.containerCommandIsAllowed(
            over: [before.blocks[0], before.blocks[2]]),
                      "CONTROL: two plain paragraphs are allowed, so the check is not always-false")
    }
}
