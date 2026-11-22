import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// Nesting design §3.4 / §4.1: every child kind legacy allows inside a block quote, and a quote in a
/// quote, set on the editor and read back equal — with the roles the flatten stamps.
@available(iOS 18.4, *)
final class EngineNestedQuoteRoundTripTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!
    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    private func quote(_ id: String, _ children: [Block], author: String = "") -> Block {
        .blockQuote(BlockQuote(id: BlockID(id), children: children, author: author.isEmpty ? [] : [TextRun(text: author)]))
    }
    private func photo(_ id: String, _ caption: String) -> Block {
        .media(MediaBlock(id: BlockID(id), items: [MediaItem(mediaID: "m-\(id)", kind: .image, naturalSize: Size2D(width: 1000, height: 500))],
                          caption: caption.isEmpty ? [] : [TextRun(text: caption)]))
    }
    /// A cell's inner paragraph is given the SAME id as its cell: a table cell's paragraph id is
    /// never preserved on read-back (`EngineDocumentBridge.block(for:from:)`'s `.tableCell` case
    /// always rebuilds it as the cell's own id — a pre-existing convention orthogonal to nesting,
    /// which is why `EngineTableRoundTripTests` never asserts full `Document` equality either).
    /// Matching the two ids here lets `roundTrip`'s full-equality check hold for the table itself.
    private func table(_ id: String) -> Block {
        .table(TableBlock(id: BlockID(id), columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
                          rows: [Row(id: BlockID("\(id)r"), cells: [
                              Cell(id: BlockID("\(id)a"), blocks: [para("\(id)a", "a")]),
                              Cell(id: BlockID("\(id)b"), blocks: [para("\(id)b", "b")])])]))
    }
    /// One tag per engine block: kind at depth.
    private func roles() -> [String] {
        editor.currentRoles.map { role in
            let kind: String
            if role.owningTable != nil { kind = "cell" }
            else if let secondary = role.secondaryKind { kind = "\(secondary)" }
            else { switch role.shape { case .media: kind = "media"; case .buttonRow: kind = "buttonRow"; case .code: kind = "code"; case .pullQuote: kind = "pullQuote"; case .collapsedQuote: kind = "collapsedQuote"; case .paragraph: kind = "p" } }
            return "\(kind)@\(role.containerDepth)"
        }
    }
    private func roundTrip(_ blocks: [Block], file: StaticString = #filePath, line: UInt = #line) {
        editor.document = Document(blocks: blocks)
        XCTAssertEqual(editor.document.blocks, blocks, "the document must read back as it was set", file: file, line: line)
    }

    /// Places the caret at a flat offset in the engine's own position axis — blocks joined by ONE
    /// separator unit each, the same axis the existing quote tests address via
    /// `editor.engine.position(from:offset:)`.
    private func setCaret(_ offset: Int, file: StaticString = #filePath, line: UInt = #line) {
        let start = editor.engine.beginningOfDocument
        guard let position = editor.engine.position(from: start, offset: offset),
              let range = editor.engine.textRange(from: position, to: position) else {
            return XCTFail("could not address offset \(offset)", file: file, line: line)
        }
        editor.engine.selectedTextRange = range
    }

    func test_aCodeBlockInsideAQuote() {
        let code = Block.code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x = 1")]))
        roundTrip([quote("q", [para("a", "before"), code], author: "Ada")])
        XCTAssertEqual(roles(), ["p@1", "codeLanguage@1", "code@1", "blockQuoteAuthor@1"])
    }

    func test_aPullQuoteInsideAQuote() {
        let pull = Block.pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "pulled")], author: [TextRun(text: "Bob")]))
        roundTrip([quote("q", [pull])])
        XCTAssertEqual(roles(), ["pullQuote@1", "pullQuoteAuthor@1", "blockQuoteAuthor@1"])
    }

    func test_aPhotoInsideAQuote() {
        roundTrip([quote("q", [photo("ph", "cap")])])
        XCTAssertEqual(roles(), ["media@1", "mediaCaption@1", "blockQuoteAuthor@1"],
                       "an atom is one character, so the quote has content and an author line")
    }

    func test_anAudioInsideAQuoteHasNoCaptionLine() {
        let audio = Block.media(MediaBlock(id: BlockID("au"), items: [MediaItem(mediaID: "m", kind: .audio, naturalSize: Size2D(width: 0, height: 0))]))
        roundTrip([quote("q", [audio])])
        XCTAssertEqual(roles(), ["media@1", "blockQuoteAuthor@1"])
    }

    func test_aTableInsideAQuote() {
        roundTrip([quote("q", [para("a", "x"), table("t")])])
        XCTAssertEqual(roles(), ["p@1", "cell@1", "cell@1", "blockQuoteAuthor@1"])
    }

    func test_aQuoteInsideAQuoteWithAnAuthorAtEachLevel() {
        roundTrip([quote("q", [para("a", "outer"), quote("q2", [para("b", "inner")], author: "Inner"), para("c", "after")], author: "Outer")])
        XCTAssertEqual(roles(), ["p@1", "p@2", "blockQuoteAuthor@2", "p@1", "blockQuoteAuthor@1"])
    }

    func test_anEmptyNestedQuoteGetsOneEmptyChildAndOnlyTheOuterAuthorLine() {
        editor.document = Document(blocks: [quote("q", [quote("q2", [])])])
        XCTAssertEqual(roles(), ["p@2", "blockQuoteAuthor@1"],
                       "the inner holds one rescued empty paragraph and has nothing to attribute; "
                       + "the outer holds the inner, and a child is content (2026-09-11)")
        guard case let .blockQuote(outer)? = editor.document.blocks.first,
              case let .blockQuote(inner)? = outer.children.first else { return XCTFail("\(editor.document.blocks)") }
        XCTAssertEqual(inner.children.count, 1)
    }

    func test_threeLevelsDeep() {
        roundTrip([quote("q", [quote("q2", [quote("q3", [para("d", "deep")])])])])
        XCTAssertEqual(roles(), ["p@3", "blockQuoteAuthor@3", "blockQuoteAuthor@2", "blockQuoteAuthor@1"])
    }

    func test_nestedTextIsFifteenPointAndIndentedOnceMorePerLevel() {
        editor.document = Document(blocks: [para("p0", "plain"), quote("q", [para("a", "one"), quote("q2", [para("b", "two")])])])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        func font(_ block: Int) -> UIFont? { editor.engine.id_renderedTextForBlock(at: UInt(block))?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont }
        XCTAssertEqual(font(1)?.pointSize ?? 0, 15, accuracy: 0.5)
        XCTAssertEqual(font(2)?.pointSize ?? 0, 15, accuracy: 0.5, "assign, never multiply: depth 2 is still 15pt")
        // "plain" 0..4 | one 6..8 | two 10..12
        func inkX(_ range: NSRange, block: Int) -> CGFloat {
            (editor.engine.id_rects(forCanonicalRange: range).map(\.cgRectValue).first?.minX ?? 0) - editor.engine.id_frameForBlock(at: UInt(block)).minX
        }
        let plain = inkX(NSRange(location: 0, length: 5), block: 0)
        let one = inkX(NSRange(location: 6, length: 3), block: 1)
        let two = inkX(NSRange(location: 10, length: 3), block: 2)
        XCTAssertEqual(one - plain, editor.bridge.styleSheet.quoteIndent, accuracy: 1.0)
        XCTAssertEqual(two - one, editor.bridge.styleSheet.quoteIndent, accuracy: 1.0, "one quoteIndent more per level")
    }

    // MARK: - Editing a nested SECONDARY line keeps `render(role:from:)` in step with `flatten`
    //
    // `flatten` indents every nested secondary line (`.codeLanguage`, `.pullQuoteAuthor`,
    // `.mediaCaption`) by `quoteIndent * depth` (via `emit`). `render(role:from:)` — the function
    // settle calls to re-derive a block's presentation — must agree, or two things go wrong, each
    // caught a different way below:
    //
    // (1) `verifyPresentationIsDerived` compares every block's LIVE storage against a fresh
    //     `render(role:from:)` after every settle. A nested secondary line that has never been
    //     EDITED still holds the correct indent `flatten` gave it at the document set, so editing
    //     some OTHER block (leaving the target line untouched) is what exposes a `render(role:from:)`
    //     that disagrees with it — the touched block's own edit does NOT: `normalisePresentation`
    //     rewrites a touched block's storage to equal whatever `render(role:from:)` says (right
    //     BEFORE verification runs), so a bugged line self-heals into internal consistency the
    //     instant it is edited and a drift check against it can never fire again. `verify` calls
    //     `assertionFailure` — which ABORTS the test run — the moment it finds one, so each case
    //     below touches an untouched sibling FIRST and a case simply RUNNING TO COMPLETION at all
    //     is the evidence for this half.
    // (2) Because of that self-healing, editing the target line ITSELF is a silent regression
    //     `verify` structurally cannot see — its own indent visibly drops from view. Each case below
    //     also captures the target line's `headIndent` before touching it, edits it, and asserts the
    //     indent is unchanged afterward — the direct check for this half.

    /// `id_renderedTextForBlock`'s stored `.paragraphStyle.headIndent` for one engine block — the
    /// live presentation, independent of any layout pass (attributes are set at document-set /
    /// settle time, not by `layoutSubviews`).
    private func headIndent(_ block: Int) -> CGFloat? {
        (editor.engine.id_renderedTextForBlock(at: UInt(block))?
            .attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.headIndent
    }

    func test_editingANestedCodeLanguageLineDoesNotDriftItsIndent() {
        let code = Block.code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x")]))
        editor.document = Document(blocks: [quote("q", [para("a", "one"), code])])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        guard let indentBefore = headIndent(1) else { return XCTFail("no language-line geometry") }

        // Touch the quote's own (empty, present because "one" is non-empty content) author line —
        // block 3, untouched by anything above — leaving the language line untouched too, so THIS
        // settle's verify compares its still-pristine, correctly indented storage against a fresh
        // `render(role:from:)`. See (1) above.
        setCaret(16)
        editor.engine.insertText("!")

        // "one" (3) + separator (1) = 4: the language line ("swift") starts at 4, ends at 9. Its
        // start is unaffected by the edit above (block 3 sits after it).
        setCaret(9)
        editor.engine.insertText("y")

        XCTAssertEqual(editor.engine.attributedBlocks.map(\.string), ["one", "swifty", "let x", "!"])
        XCTAssertEqual(headIndent(1), indentBefore, "the language line keeps the indent it had a moment ago — see (2) above")
    }

    func test_editingANestedPullQuoteAuthorLineDoesNotDriftItsIndent() {
        let pull = Block.pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "pulled")], author: [TextRun(text: "Bob")]))
        editor.document = Document(blocks: [quote("q", [pull])])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        guard let indentBefore = headIndent(1) else { return XCTFail("no author-line geometry") }

        // Touch the quote's own (empty) author line — block 2, after the pull quote's author —
        // leaving IT untouched for this settle's verify. See (1) above.
        setCaret(11)
        editor.engine.insertText("!")

        // "pulled" (6) + separator (1) = 7: the author line ("Bob") starts at 7, ends at 10.
        setCaret(10)
        editor.engine.insertText("!")

        XCTAssertEqual(editor.engine.attributedBlocks.map(\.string), ["pulled", "Bob!", "!"])
        XCTAssertEqual(headIndent(1), indentBefore, "the author line keeps the indent it had a moment ago — see (2) above")
    }

    func test_editingANestedMediaCaptionLineDoesNotDriftItsIndent() {
        editor.document = Document(blocks: [quote("q", [photo("ph", "cap")])])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        guard let indentBefore = headIndent(1) else { return XCTFail("no caption-line geometry") }

        // Touch the quote's own (empty) author line — block 2, after the caption — leaving IT
        // untouched for this settle's verify. See (1) above.
        setCaret(6)
        editor.engine.insertText("!")

        // The atom is one attachment character; the caption ("cap") starts right after its
        // separator, at offset 2 — unaffected by the edit above (block 2 sits after it).
        setCaret(2)
        editor.engine.insertText("x")

        XCTAssertEqual(editor.engine.attributedBlocks.map(\.string), ["\u{FFFC}", "xcap", "!"])
        XCTAssertEqual(headIndent(1), indentBefore, "the caption line keeps the indent it had a moment ago — see (2) above")
    }
}
