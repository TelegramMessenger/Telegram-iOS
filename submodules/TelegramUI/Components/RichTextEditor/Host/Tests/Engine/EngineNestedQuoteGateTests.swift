import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// Nesting design §6: every Return and Backspace rule reads the caret's INNERMOST quote and moves one
/// level; a replacement across blocks drops a nested quote whole and refuses an endpoint in a cell.
@available(iOS 18.4, *)
final class EngineNestedQuoteGateTests: XCTestCase {
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
    private func table(_ id: String) -> Block {
        .table(TableBlock(id: BlockID(id), columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
                          rows: [Row(id: BlockID("\(id)r"), cells: [Cell(id: BlockID("\(id)a"), blocks: [para("\(id)ap", "a")]),
                                                                   Cell(id: BlockID("\(id)b"), blocks: [para("\(id)bp", "b")])])]))
    }
    private func roles() -> [String] {
        editor.currentRoles.map { role in
            let kind: String
            if role.owningTable != nil { kind = "cell" }
            else if let secondary = role.secondaryKind { kind = "\(secondary)" }
            else { switch role.shape { case .media: kind = "media"; case .buttonRow: kind = "buttonRow"; case .code: kind = "code"; case .pullQuote: kind = "pullQuote"; case .collapsedQuote: kind = "collapsedQuote"; case .paragraph: kind = "p" } }
            return "\(kind)@\(role.containerDepth)"
        }
    }
    private func strings() -> [String] { editor.engine.attributedBlocks.map(\.string) }
    private func load(_ blocks: [Block]) { editor.document = Document(blocks: blocks); XCTAssertTrue(editor.engine.becomeFirstResponder()) }
    private func caret(_ at: Int) { editor.engineSelectedRange = NSRange(location: at, length: 0) }
    private func rangeReplace(_ range: NSRange, _ text: String) {
        let start = editor.engine.position(from: editor.engine.beginningOfDocument, offset: range.location)!
        let end = editor.engine.position(from: start, offset: range.length)!
        editor.engine.replace(editor.engine.textRange(from: start, to: end)!, withText: text)
    }

    // The nested document most cases use, on the engine axis:
    //   one 0..3 | two 4..7 | (q2 author, empty) 8 | three 9..14 | (q author, empty) 15
    private var nested: [Block] { [quote("q", [para("a", "one"), quote("q2", [para("b", "two")]), para("c", "three")])] }

    // MARK: §6.1 Return

    func test_returnOnTheEmptyLastChildOfAnInnerQuoteLeavesItForTheOuterQuote() {
        load([quote("q", [para("a", "one"), quote("q2", [para("b", "two"), para("c", "")])])])
        // one 0..3 | two 4..7 | c 8 | q2 author 9 | q author 10
        XCTAssertEqual(roles(), ["p@1", "p@2", "p@2", "blockQuoteAuthor@2", "blockQuoteAuthor@1"])
        caret(8)
        editor.engine.insertText("\n")
        XCTAssertEqual(roles(), ["p@1", "p@2", "blockQuoteAuthor@2", "p@1", "blockQuoteAuthor@1"], "the empty child is now a paragraph in the OUTER quote, after the inner one")
        XCTAssertEqual(strings(), ["one", "two", "", "", ""])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 9, length: 0))
    }

    func test_returnInAWhollyEmptyInnerQuoteDissolvesItIntoOneParagraphOfTheOuter() {
        load([quote("q", [para("a", "one"), quote("q2", [para("b", ""), para("c", "")])])])
        // one 0..3 | b 4 | c 5 | q author 6 (q2 has no text, so no author line)
        XCTAssertEqual(roles(), ["p@1", "p@2", "p@2", "blockQuoteAuthor@1"])
        caret(5)
        editor.engine.insertText("\n")
        XCTAssertEqual(roles(), ["p@1", "p@1", "blockQuoteAuthor@1"])
        XCTAssertEqual(strings(), ["one", "", ""])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 4, length: 0))
    }

    func test_returnMidChildAtDepthTwoStaysAtDepthTwo() {
        load(nested)
        caret(5)   // t|wo
        editor.engine.insertText("\n")
        XCTAssertEqual(roles(), ["p@1", "p@2", "p@2", "blockQuoteAuthor@2", "p@1", "blockQuoteAuthor@1"])
        XCTAssertEqual(strings(), ["one", "t", "wo", "", "three", ""])
    }

    /// A media CAPTION reports the quote as its innermost too, and its role index sits inside the
    /// media unit — so the unit-based lookup FINDS it where the old primaries-only lookup declined.
    /// Left admitted, Return in a caption inside a quote took the quote's trailing exit: the
    /// caption's role removed, its text merged into the atom's block, a paragraph minted after the
    /// author line. It is the top-level caption behaviour at depth: the caption splits and settle
    /// declares a body paragraph after it, in the SAME quote.
    func test_returnInAMediaCaptionInsideAQuoteSplitsTheCaptionAndStaysInTheQuote() {
        load([quote("q", [para("a", "one"),
                          .media(MediaBlock(id: BlockID("m"),
                                            items: [MediaItem(mediaID: "i", kind: .image,
                                                              naturalSize: Size2D(width: 1000, height: 500))]))])])
        // one 0..3 | atom 4 | caption 6 | q author 7
        XCTAssertEqual(roles(), ["p@1", "media@1", "mediaCaption@1", "blockQuoteAuthor@1"])
        caret(6)
        editor.engine.insertText("\n")
        XCTAssertEqual(roles(), ["p@1", "media@1", "mediaCaption@1", "p@1", "blockQuoteAuthor@1"],
                       "the quote, the atom and its caption all stand")
        XCTAssertEqual(strings(), ["one", "\u{FFFC}", "", "", ""])
    }

    // MARK: §6.1 Return inside a nested leaf body — legacy's double-Return exits, at depth

    /// A leaf body inside a quote reports that quote as its innermost, so the quote branch used to
    /// take the Return first and forward a raw "\n": the engine split the code block in two and
    /// settle's rejoin put a line separator back, which LOOKED right while legacy's double-Return
    /// exits did not exist at depth. The leaf branch now runs first, and forwards U+2028 directly —
    /// which is also what the same key with a non-empty selection already did.
    func test_returnInsideANestedCodeBlockInsertsALineSeparator() {
        load([quote("q", [para("a", "one"), .code(CodeBlock(id: BlockID("cd"), language: nil, runs: [TextRun(text: "x")]))])])
        // one 0..3 | language 4 | x 5..6 | q author 7
        XCTAssertEqual(roles(), ["p@1", "codeLanguage@1", "code@1", "blockQuoteAuthor@1"])
        caret(6)   // the end of "x"
        editor.engine.insertText("\n")
        XCTAssertEqual(roles(), ["p@1", "codeLanguage@1", "code@1", "blockQuoteAuthor@1"], "still one code block")
        XCTAssertEqual(strings(), ["one", "", "x\u{2028}", ""])
    }

    /// And the second Return takes the blank last line away and opens a body paragraph after the code
    /// block — INSIDE the quote, because `decideReturnInLeafBody` mints at the body's own ancestry.
    func test_asecondReturnLeavesANestedCodeBlockForTheQuoteItIsIn() {
        load([quote("q", [para("a", "one"), .code(CodeBlock(id: BlockID("cd"), language: nil, runs: [TextRun(text: "x")]))])])
        caret(6)
        editor.engine.insertText("\n")
        editor.engineSelectedRange = NSRange(location: 7, length: 0)   // after the blank last line
        editor.engine.insertText("\n")
        XCTAssertEqual(roles(), ["p@1", "codeLanguage@1", "code@1", "p@1", "blockQuoteAuthor@1"],
                       "the paragraph is a child of the quote, not a block after it")
        XCTAssertEqual(strings(), ["one", "", "x", "", ""])
    }

    // MARK: §6.2 Backspace

    func test_backspaceAtTheStartOfTheFirstOfSeveralChildrenLiftsItOutOneLevel_bothDoors() {
        load([quote("q", [para("a", "one"), quote("q2", [para("b", "two"), para("c", "three")])])])
        // one 0..3 | two 4..7 | three 8..13 | q2 author 14 | q author 15
        caret(4); editor.engine.deleteBackward()
        XCTAssertEqual(roles(), ["p@1", "p@1", "p@2", "blockQuoteAuthor@2", "blockQuoteAuthor@1"], "b is the inner quote's preceding sibling now")
        XCTAssertEqual(strings(), ["one", "two", "three", "", ""], "nothing merged")
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 4, length: 0))
        load([quote("q", [para("a", "one"), quote("q2", [para("b", "two"), para("c", "three")])])])
        rangeReplace(NSRange(location: 3, length: 1), "")   // the join, the range door
        XCTAssertEqual(roles(), ["p@1", "p@1", "p@2", "blockQuoteAuthor@2", "blockQuoteAuthor@1"])
        XCTAssertEqual(strings(), ["one", "two", "three", "", ""])
    }

    func test_backspaceAtTheStartOfAnEmptyFirstChildRemovesIt() {
        load([quote("q", [quote("q2", [para("b", ""), para("c", "three")])])])
        // b 0 | three 1..6 | q2 author 7 | q author 8
        caret(0); editor.engine.deleteBackward()
        XCTAssertEqual(roles(), ["p@2", "blockQuoteAuthor@2", "blockQuoteAuthor@1"])
        XCTAssertEqual(strings(), ["three", "", ""])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 0, length: 0), "at the next child's start")
    }

    func test_backspaceAtTheStartOfALoneChildUnwrapsTheInnerQuoteOnly() {
        load(nested)
        caret(4); editor.engine.deleteBackward()
        XCTAssertEqual(roles(), ["p@1", "p@1", "p@1", "blockQuoteAuthor@1"], "q2 is gone, its author line with it; q stands")
        XCTAssertEqual(strings(), ["one", "two", "three", ""])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 4, length: 0))
    }

    func test_backspaceAtTheStartOfTheBlockAfterANestedQuoteTravelsToItsAuthorLine() {
        load(nested)
        caret(9); editor.engine.deleteBackward()
        XCTAssertEqual(strings(), ["one", "two", "", "three", ""], "never merges")
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 8, length: 0), "the end of the inner quote's author line")
    }

    func test_backspaceAtTheStartOfAnEmptyBlockAfterANestedQuoteRemovesIt() {
        load([quote("q", [quote("q2", [para("b", "two")]), para("c", "")])])
        // two 0..3 | q2 author 4 | c 5 | q author 6
        caret(5); editor.engine.deleteBackward()
        XCTAssertEqual(roles(), ["p@2", "blockQuoteAuthor@2", "blockQuoteAuthor@1"])
        XCTAssertEqual(strings(), ["two", "", ""])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 4, length: 0))
    }

    func test_backspaceInsideAnEmptyNestedCodeBlockUncodesItInPlace() {
        load([quote("q", [para("a", "one"), .code(CodeBlock(id: BlockID("cd"), language: nil, runs: []))])])
        // one 0..3 | language 4 | code 5 | q author 6
        XCTAssertEqual(roles(), ["p@1", "codeLanguage@1", "code@1", "blockQuoteAuthor@1"])
        caret(5); editor.engine.deleteBackward()
        XCTAssertEqual(roles(), ["p@1", "p@1", "blockQuoteAuthor@1"], "the empty code block dissolves into a paragraph of the SAME quote")
    }

    // MARK: §6.3 replacements across blocks

    func test_aRangeAcrossANestedQuoteDropsItWhole() {
        load(nested)
        rangeReplace(NSRange(location: 2, length: 9), "")   // on|e … th|ree
        XCTAssertEqual(strings(), ["onree", ""])
        XCTAssertEqual(roles(), ["p@1", "blockQuoteAuthor@1"])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 2, length: 0))
    }

    func test_selectAllAndBackspaceOverNestedQuotesLeavesOneEmptyParagraph() {
        load(nested)
        let length = editor.engine.attributedBlocks.reduce(0) { $0 + $1.length } + max(0, editor.engine.attributedBlocks.count - 1)
        editor.engineSelectedRange = NSRange(location: 0, length: length)
        editor.engine.deleteBackward()
        XCTAssertEqual(strings(), [""])
        XCTAssertEqual(roles(), ["p@0"])
    }

    func test_aRangeEnteringANestedQuoteKeepsTheEndpointChild() {
        load(nested)
        rangeReplace(NSRange(location: 2, length: 3), "")   // on|e \n t|wo: the outer child and the inner child merge
        XCTAssertEqual(strings(), ["onwo", "three", ""])
        XCTAssertEqual(roles(), ["p@1", "p@1", "blockQuoteAuthor@1"],
                       "the survivor keeps the START block's role (depth 1); the inner quote's author line has no "
                       + "primary within it any more and is EMPTY, so settleOrphanedSecondaryLines removes it with "
                       + "its quote rather than leaving a blank paragraph in the outer one")
    }

    func test_aRangeWithAnEndpointInsideANestedCellIsRefused() {
        load([quote("q", [table("t"), para("c", "after")])])
        // a 0..1 | b 2..3 | after 4..9 | q author 10
        let before = strings()
        rangeReplace(NSRange(location: 1, length: 5), "")
        XCTAssertEqual(strings(), before, "an endpoint inside a cell of a table the range does not cover: refused")
    }

    // MARK: Container commands reach a nested container's own level, never the top

    /// `touchedContainers` resolves a container at ANY depth now (`Document.blocksByID`), which is
    /// what lets the dissolve above reach a nested code block. `applyContainerCommand` still looks
    /// its endpoints up in `document.blocks` — the TOP level — so a nested child falls out at that
    /// lookup and the command is a no-op.
    ///
    /// The case is the one Task 1's review recorded as deferred: before `blocksByID` a quote child
    /// resolved to NOTHING, so a selection over a quote's child and a top-level paragraph left the
    /// paragraph as the only touched container and the command silently code-blocked that alone,
    /// half-applying itself. It refuses outright now.
    func test_makeCodeBlockOverAQuoteChildAndATopLevelParagraphIsANoOp() {
        load([quote("q", [para("b", "")]), para("p", "after")])
        // b 0 | after 1..5 (an empty quote has no author line)
        XCTAssertEqual(roles(), ["p@1", "p@0"])
        let before = editor.document
        editor.engineSelectedRange = NSRange(location: 0, length: 4)
        editor.makeCodeBlock()
        XCTAssertEqual(editor.document, before,
                       "neither the quote's child nor the paragraph beside it is code-blocked: \(editor.document.blocks)")
        XCTAssertEqual(roles(), ["p@1", "p@0"])
    }

    // MARK: §6.2 The exits are the CHILD's, whatever kind of block the child is

    /// A quote's lone child is a CODE BLOCK. Backspace at the start of the child — which for a code
    /// block is the start of its always-visible language line, not its body — must dissolve the
    /// quote one level, exactly as it does for a lone paragraph child. The exit used to be gated on
    /// `shape.paragraph`, so it declined for every child kind but a paragraph and the boundary rule
    /// admitted the keystroke instead: the caret stepped out of the quote and nothing else happened.
    func test_backspaceAtTheStartOfALoneCodeChildUnwrapsTheQuote() {
        load([para("p", "before"), .blockQuote(BlockQuote(id: BlockID("q"),
                                                          children: [.code(CodeBlock(id: BlockID("cd"), language: "swift",
                                                                                     runs: [TextRun(text: "x")]))]))])
        // before 0..5 | swift 7..11 | x 13 | q author 15
        XCTAssertEqual(roles(), ["p@0", "codeLanguage@1", "code@1", "blockQuoteAuthor@1"])
        caret(7); editor.engine.deleteBackward()
        XCTAssertEqual(roles(), ["p@0", "codeLanguage@0", "code@0"], "the quote dissolved; the code block is whole at top level")
        XCTAssertEqual(strings(), ["before", "swift", "x"])
    }

    /// And the lift: the first of several children leaves the quote as ONE unit. A code block is two
    /// engine blocks, so a lift that moved the caret's role alone would tear the language line off
    /// its body and leave a code block half in and half out of the quote.
    func test_backspaceAtTheStartOfAFirstCodeChildLiftsTheWholeCodeBlockOut() {
        load([.blockQuote(BlockQuote(id: BlockID("q"),
                                     children: [.code(CodeBlock(id: BlockID("cd"), language: "swift", runs: [TextRun(text: "x")])),
                                                para("c", "three")]))])
        // swift 0..4 | x 6 | three 8..12 | q author 14
        XCTAssertEqual(roles(), ["codeLanguage@1", "code@1", "p@1", "blockQuoteAuthor@1"])
        caret(0); editor.engine.deleteBackward()
        XCTAssertEqual(roles(), ["codeLanguage@0", "code@0", "p@1", "blockQuoteAuthor@1"],
                       "both of the code block's engine blocks left the quote together")
        XCTAssertEqual(strings(), ["swift", "x", "three", ""])
    }

    /// The same for a pull quote, whose child unit starts at its BODY. Its previous sibling is a
    /// plain paragraph, so before the widening the boundary rule declined outright and the engine
    /// merged the quoted pull quote's text into the paragraph above.
    func test_backspaceAtTheStartOfALonePullQuoteChildUnwrapsTheQuote() {
        load([para("p", "before"), .blockQuote(BlockQuote(id: BlockID("q"),
                                                          children: [.pullQuote(PullQuote(id: BlockID("pq"),
                                                                                          runs: [TextRun(text: "cited")]))]))])
        // before 0..5 | cited 7..11 | pull-quote author 13 | q author 14
        XCTAssertEqual(roles(), ["p@0", "pullQuote@1", "pullQuoteAuthor@1", "blockQuoteAuthor@1"])
        caret(7); editor.engine.deleteBackward()
        XCTAssertEqual(roles(), ["p@0", "pullQuote@0", "pullQuoteAuthor@0"],
                       "the pull quote left the quote with its author line, which is INSIDE the child unit")
        XCTAssertEqual(strings(), ["before", "cited", ""])
    }

    /// A second line INSIDE a child is not the child's START, so it takes no exit. Without that test
    /// the widened rule would unwrap the quote from a pull quote's author line — the author line's own
    /// innermost quote is Q, and its index sits inside Q's first child unit.
    func test_backspaceAtTheStartOfAQuotedPullQuotesAuthorLineIsAWall() {
        load([.blockQuote(BlockQuote(id: BlockID("q"),
                                     children: [.pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "cited")],
                                                                     author: [TextRun(text: "Ada")]))]))])
        // cited 0..4 | Ada 6..8 | q author 10
        XCTAssertEqual(roles(), ["pullQuote@1", "pullQuoteAuthor@1", "blockQuoteAuthor@1"])
        caret(6); editor.engine.deleteBackward()
        XCTAssertEqual(roles(), ["pullQuote@1", "pullQuoteAuthor@1", "blockQuoteAuthor@1"], "the quote stands")
        XCTAssertEqual(strings(), ["cited", "Ada", ""])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 5, length: 0), "the caret travelled to the body's end")
    }

    /// Both doors, for the widened rule: the range delivery of the same keystroke takes the same exit.
    func test_backspaceAtTheStartOfALoneCodeChildUnwrapsTheQuote_rangeDoor() {
        load([para("p", "before"), .blockQuote(BlockQuote(id: BlockID("q"),
                                                          children: [.code(CodeBlock(id: BlockID("cd"), language: "swift",
                                                                                     runs: [TextRun(text: "x")]))]))])
        rangeReplace(NSRange(location: 6, length: 1), "")   // the join before the language line
        XCTAssertEqual(roles(), ["p@0", "codeLanguage@0", "code@0"])
        XCTAssertEqual(strings(), ["before", "swift", "x"])
    }

    // MARK: The two doors of one Backspace decide in the same order

    /// UIKit delivers a Backspace at a block's start either as a collapsed caret or as the RANGE
    /// covering the join with the block above. The caret door dissolves an empty container BEFORE it
    /// asks the list and quote-child rules; the range door asked neither — so a quote whose children
    /// are ALL empty dissolved through one door and merely merged two of its children through the
    /// other, keeping a quote the user had just emptied.
    func test_backspaceInAWhollyEmptyQuoteDissolvesItThroughBothDoors() {
        load([quote("q", [para("a", ""), para("b", ""), para("c", "")])])
        XCTAssertEqual(roles(), ["p@1", "p@1", "p@1"], "an empty quote has no author line")
        caret(1); editor.engine.deleteBackward()
        XCTAssertEqual(roles(), ["p@0"], "the caret door dissolves the quote")
        XCTAssertEqual(strings(), [""])

        load([quote("q", [para("a", ""), para("b", ""), para("c", "")])])
        rangeReplace(NSRange(location: 0, length: 1), "")   // the join before the second child
        XCTAssertEqual(roles(), ["p@0"], "and so does the range door")
        XCTAssertEqual(strings(), [""])
    }

    /// The finding's own two-child shape, pinned as the CONVERGENT case: `replaceAcrossBlocks`
    /// covers the whole quote here (both its primaries lie inside the range), so it already dropped
    /// the quote rather than keeping it. Kept so a future change to either door has to keep them
    /// agreeing on this shape too.
    func test_backspaceInAQuoteOfTwoEmptyChildrenDissolvesItThroughBothDoors() {
        load([quote("q", [para("a", ""), para("b", "")])])
        caret(1); editor.engine.deleteBackward()
        XCTAssertEqual(roles(), ["p@0"])
        load([quote("q", [para("a", ""), para("b", "")])])
        rangeReplace(NSRange(location: 0, length: 1), "")
        XCTAssertEqual(roles(), ["p@0"])
    }

    // MARK: an empty CONTAINER child is not an empty quote (device, K3 2026-09-08)

    /// A quote whose LONE child is an empty code block. The quote-emptiness arm ran first and
    /// `childrenAreEmpty` counted the code block's empty body as an empty child — a code block's
    /// only PRIMARY role is its body, its language line being secondary — so `unmakeContainer`
    /// replaced the quote's whole span with one paragraph and a single Backspace destroyed the code
    /// block AND the quote. Every other test of the container arm at depth gives the quote a
    /// non-empty sibling, which is the shape that hid it.
    func test_backspaceInAQuotesLoneEmptyCodeChildUncodesItAndKeepsTheQuote() {
        load([quote("q", [.code(CodeBlock(id: BlockID("cd"), language: nil, runs: []))])])
        // The code block is a CHILD, and a child is content however empty its text: the quote has
        // something to attribute from the moment it holds one (2026-09-11).
        XCTAssertEqual(roles(), ["codeLanguage@1", "code@1", "blockQuoteAuthor@1"])
        caret(0); editor.engine.deleteBackward()
        XCTAssertEqual(roles(), ["p@1"], "the code block un-codes into a paragraph OF THE QUOTE; the quote stands")
        XCTAssertEqual(strings(), [""])
    }

    /// …and only the NEXT Backspace dissolves the quote, one level per keystroke.
    func test_theSecondBackspaceThenDissolvesTheQuote() {
        load([quote("q", [.code(CodeBlock(id: BlockID("cd"), language: nil, runs: []))])])
        caret(0); editor.engine.deleteBackward()
        XCTAssertEqual(roles(), ["p@1"])
        editor.engine.deleteBackward()
        XCTAssertEqual(roles(), ["p@0"], "the emptied quote dissolves on the next press")
    }

    /// The same shape for a quote's lone empty PULL QUOTE child, whose primary role is likewise its
    /// body with a secondary author line.
    func test_backspaceInAQuotesLoneEmptyPullQuoteChildKeepsTheQuote() {
        load([quote("q", [.pullQuote(PullQuote(id: BlockID("pq"), runs: []))])])
        XCTAssertEqual(roles(), ["pullQuote@1", "blockQuoteAuthor@1"],
                       "an empty pull quote is ONE role of its own — and the QUOTE holding it has a "
                       + "child, so it carries an author line (2026-09-11)")
        caret(0); editor.engine.deleteBackward()
        XCTAssertEqual(roles(), ["p@1"], "the pull quote dissolves into a paragraph of the quote; the quote stands")
    }

    /// A quote holding an empty paragraph beside a nested quote is not empty either: dissolving it
    /// whole would flatten the nested quote into the same single paragraph.
    func test_aQuoteHoldingANestedQuoteIsNotEmptyEvenWhenEveryLineIsBlank() {
        load([quote("q", [para("a", ""), quote("q2", [para("b", "")])])])
        XCTAssertEqual(roles(), ["p@1", "p@2", "blockQuoteAuthor@1"],
                       "the INNER quote holds one empty paragraph and has nothing to attribute; the "
                       + "outer holds a nested quote, which is a child and therefore content")
        caret(0); editor.engine.deleteBackward()
        XCTAssertNotEqual(roles(), ["p@0"], "the nested quote is not flattened away with its parent")
    }

    // MARK: §8.5 amended — insertion lands where the caret is, at any depth (device, K3 2026-09-08)

    /// A table asked for with the caret inside a quote becomes a CHILD of that quote. The anchor was
    /// looked up in the TOP-LEVEL block list, so a caret inside a quote matched nothing and the
    /// fallback appended the grid at the END of the document.
    func test_aTableInsertedInsideAQuoteBecomesItsChild() {
        load([quote("q", [para("a", "one")])])
        caret(3)
        editor.insertTable(rows: 1, cols: 2)
        XCTAssertEqual(roles(), ["p@1", "cell@1", "cell@1", "blockQuoteAuthor@1"],
                       "the cells are inside the quote, after the paragraph the caret was in")
    }

    /// One indent per level: the same at depth 2.
    func test_aTableInsertedInsideANestedQuoteTakesBothLevels() {
        load([quote("q", [quote("q2", [para("b", "two")])])])
        caret(3)
        editor.insertTable(rows: 1, cols: 1)
        XCTAssertEqual(roles().filter { $0.hasPrefix("cell") }, ["cell@2"], "the cell is two quotes deep")
    }

    /// An EMPTY quoted paragraph is replaced by the grid rather than followed by it, as legacy does
    /// at the top level — and the replacement keeps the quote.
    func test_aTableReplacesTheEmptyQuotedParagraphTheCaretIsIn() {
        load([quote("q", [para("a", "one"), para("b", "")])])
        caret(4)
        editor.insertTable(rows: 1, cols: 1)
        XCTAssertEqual(roles(), ["p@1", "cell@1", "blockQuoteAuthor@1"], "the blank child became the table")
    }

    /// A top-level insert is unchanged.
    func test_aTableInsertedAtTopLevelIsUnchanged() {
        load([para("a", "one")])
        caret(3)
        editor.insertTable(rows: 1, cols: 2)
        XCTAssertEqual(roles(), ["p@0", "cell@0", "cell@0"])
    }

    /// A photo asked for with the caret inside a quote lands in the quote. It was a no-op: legacy's
    /// v1 rule refused media inside a quote, and the guard outlived the render half that made a
    /// quoted medium work, so to a user holding a quote the + button simply did nothing.
    func test_aPhotoInsertedInsideAQuoteLandsInTheQuote() {
        load([quote("q", [para("a", "one")])])
        caret(3)
        editor.insertMedia(mediaID: "m1", naturalSize: CGSize(width: 1000, height: 500), kind: .image, caption: [])
        XCTAssertEqual(roles(), ["p@1", "media@1", "mediaCaption@1", "blockQuoteAuthor@1"],
                       "the atom and its caption are children of the quote")
    }

    /// …and the atom the insert stamps is measured against the quote's NARROWED line, not the full
    /// column (§4.4, probe P1): the attributes carry the caret's ancestry, so a quoted atom
    /// subtracts the quote's leading indent AND its trailing inset where a top-level one subtracts
    /// nothing. Read off the attachment itself, so the assertion fails the moment the stamped
    /// reduction goes back to a constant.
    func test_theAtomAnInsertStampsInAQuoteCarriesTheQuotesIndent() {
        load([para("top", ""), quote("q", [para("a", "one")])])
        caret(0)
        editor.insertMedia(mediaID: "m0", naturalSize: CGSize(width: 1000, height: 500), kind: .image, caption: [])
        caret(flatOffsetOfFirst("one") + 3)
        editor.insertMedia(mediaID: "m1", naturalSize: CGSize(width: 1000, height: 500), kind: .image, caption: [])
        let indents = editor.engine.attributedBlocks.compactMap { block -> CGFloat? in
            guard block.length > 0 else { return nil }
            return (block.attribute(.attachment, at: 0, effectiveRange: nil) as? MediaTextAttachment)?.horizontalIndent
        }
        XCTAssertEqual(indents, [0, editor.bridge.styleSheet.quoteIndent + editor.bridge.styleSheet.quoteTrailingInset],
                       "the top-level atom subtracts nothing; the quoted one subtracts both of the quote's insets")
    }

    /// The flat offset of the first block whose string equals `text`.
    private func flatOffsetOfFirst(_ text: String) -> Int {
        var start = 0
        for block in editor.engine.attributedBlocks {
            if block.string == text { return start }
            start += block.length + 1
        }
        return 0
    }

    // MARK: a container child is not the quote's own content (device, K3 pass 2, 2026-09-08)

    /// Deleting the only photo in a quote took the quote with it. `coveredUnit` walked the ANCESTRY
    /// first, and `containerIsCovered` judges a quote by its primary blocks losing all their text —
    /// a media atom IS a primary block, so emptying the only child emptied the quote by that test
    /// and both were dropped. The leaf child is asked first now, and the survivor lands in the quote
    /// that held it.
    func test_deletingTheOnlyPhotoInAQuoteKeepsTheQuote() {
        load([quote("q", [.media(MediaBlock(id: BlockID("m"), mediaID: "x", kind: .image,
                                            naturalSize: Size2D(width: 1000, height: 500), caption: []))])])
        XCTAssertEqual(roles(), ["media@1", "mediaCaption@1", "blockQuoteAuthor@1"])
        caret(2)
        editor.engine.deleteBackward()
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 0, length: 1), "first press selects the atom")
        editor.engine.deleteBackward()
        XCTAssertEqual(roles(), ["p@1"], "the photo goes, the quote stays with an empty paragraph")
    }

    /// …and the NEXT press dissolves the emptied quote, one level per action.
    func test_theNextPressThenDissolvesTheQuoteThePhotoLeftEmpty() {
        load([quote("q", [.media(MediaBlock(id: BlockID("m"), mediaID: "x", kind: .image,
                                            naturalSize: Size2D(width: 1000, height: 500), caption: []))])])
        caret(2); editor.engine.deleteBackward(); editor.engine.deleteBackward()
        XCTAssertEqual(roles(), ["p@1"])
        editor.engine.deleteBackward()
        XCTAssertEqual(roles(), ["p@0"])
    }

    /// Select-all over a quote still drops it whole: the survivor belongs to the PARENT of a dropped
    /// quote, where it belongs to the QUOTE for a dropped child. Both come from the same rule, so
    /// this is the case that says the rule is about the holder and not about the leaf.
    func test_selectAllOverAQuoteHoldingOnlyAPhotoStillDropsTheQuote() {
        load([quote("q", [.media(MediaBlock(id: BlockID("m"), mediaID: "x", kind: .image,
                                            naturalSize: Size2D(width: 1000, height: 500), caption: []))],
                    author: "who")])
        let total = editor.engine.attributedBlocks.reduce(0) { $0 + $1.length } + editor.engine.attributedBlocks.count - 1
        rangeReplace(NSRange(location: 0, length: total), "")
        XCTAssertEqual(roles(), ["p@0"], "the whole quote goes, leaving one top-level paragraph")
    }

    /// Return in the last cell of a table that is a quote's last child adds a paragraph INSIDE the
    /// quote. The role after that cell is the quote's AUTHOR LINE, so "is there a next role" said
    /// yes and the caret was parked in the author field instead — Return did nothing visible.
    func test_returnInTheLastCellOfAQuotedTableAddsAParagraphInTheQuote() {
        load([quote("q", [.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 100)],
                                            rows: [Row(id: BlockID("tr"),
                                                       cells: [Cell(id: BlockID("tc"), blocks: [para("tp", "a")])])]))])])
        XCTAssertEqual(roles(), ["cell@1", "blockQuoteAuthor@1"])
        caret(1)
        editor.engine.insertText("\n")
        XCTAssertEqual(roles(), ["cell@1", "p@1", "blockQuoteAuthor@1"],
                       "a new paragraph inside the quote, before the author line")
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 2, length: 0), "and the caret is in it")
    }

    /// Tab past the last cell takes the same path, so it gets the same paragraph.
    func test_tabPastTheLastCellOfAQuotedTableAddsAParagraphInTheQuote() {
        load([quote("q", [.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 100)],
                                            rows: [Row(id: BlockID("tr"),
                                                       cells: [Cell(id: BlockID("tc"), blocks: [para("tp", "a")])])]))])])
        caret(1)
        editor.moveCaretToNextTableCell()
        XCTAssertEqual(roles(), ["cell@1", "p@1", "blockQuoteAuthor@1"])
    }

    // MARK: removing a quote's author line must not throw the caret away (device, K3 pass 3)

    /// A quote emptied by one Backspace: settle removes the author line, and its caret restore read
    /// "the caret is in the line" and dropped the caret into the quote's FIRST block.
    ///
    /// The empty block above is the point. `range.location - 1` is the separator BEFORE the author
    /// line, and a caret there belongs to the block above — the two offsets coincide only when that
    /// block is empty, which is why every earlier fixture (whose blocks carried text) missed it.
    ///
    /// Fixtured on a TABLE until 2026-09-11, when a child became content in its own right: a quote
    /// holding a table now keeps its author line through this edit (the case below), so that shape
    /// no longer reaches the removal this guards. Bare paragraphs are the shape that still does.
    func test_deletingTheLastCharacterInAQuoteKeepsTheCaretInItsParagraph() {
        load([quote("q", [para("a", ""), para("b", "")])])
        XCTAssertEqual(roles(), ["p@1", "p@1"], "two empty paragraphs are nothing to attribute")
        caret(1)
        editor.engine.insertText("x")
        XCTAssertEqual(roles(), ["p@1", "p@1", "blockQuoteAuthor@1"],
                       "typing gives the quote content, so its author line appears")
        let paragraph = editor.engineSelectedRange.location - 1
        editor.engine.deleteBackward()
        XCTAssertEqual(roles(), ["p@1", "p@1"], "emptying it takes the author line away again")
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: paragraph, length: 0),
                       "and the caret stays in the paragraph it was in, not in the first block")
    }

    /// The same edit over the original fixture — an EMPTY table, what the toolbar inserts, inside a
    /// quote. The table is a CHILD, so the quote has something to attribute from the moment it holds
    /// one and the author line never comes or goes here (K3, 2026-09-11).
    func test_aQuotedTableKeepsItsAuthorLineThroughTheSameEdit() {
        load([quote("q", [.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
                                            rows: [Row(id: BlockID("tr"),
                                                       cells: [Cell(id: BlockID("tc0"), blocks: [para("tp0", "")]),
                                                               Cell(id: BlockID("tc1"), blocks: [para("tp1", "")])])]))])])
        XCTAssertEqual(roles(), ["cell@1", "cell@1", "blockQuoteAuthor@1"],
                       "an empty table is still a child, and a quote holding one has an author line")
        caret(1)
        editor.engine.insertText("\n")          // Return in the last cell -> a paragraph after the table
        XCTAssertEqual(roles(), ["cell@1", "cell@1", "p@1", "blockQuoteAuthor@1"])
        editor.engine.insertText("x")
        XCTAssertEqual(roles(), ["cell@1", "cell@1", "p@1", "blockQuoteAuthor@1"])
        let paragraph = editor.engineSelectedRange.location - 1
        editor.engine.deleteBackward()
        XCTAssertEqual(roles(), ["cell@1", "cell@1", "p@1", "blockQuoteAuthor@1"],
                       "and emptying the paragraph does not take it away")
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: paragraph, length: 0),
                       "the caret stays in the paragraph either way")
    }

    // MARK: container commands act where the caret is (D, 2026-09-08)

    /// Code over a paragraph inside a quote makes a code block THERE. `applyContainerCommand`
    /// resolved its endpoints in the TOP-LEVEL block list, so a container inside a quote matched
    /// nothing and the command returned before mutating — Format ▸ Code and Format ▸ Pull quote were
    /// dead menu items anywhere inside a quote, silently. The same shape as `insertTable`'s.
    func test_makeCodeBlockInsideAQuoteNestsTheCodeBlock() {
        load([quote("q", [para("a", "one")])])
        caret(1)
        editor.makeCodeBlock()
        XCTAssertEqual(roles(), ["codeLanguage@1", "code@1", "blockQuoteAuthor@1"],
                       "a code block that is the quote's child; the quote keeps its author line")
        XCTAssertEqual(strings(), ["", "one", ""])
    }

    /// And the toggle back off, in place.
    func test_makeCodeBlockTwiceInsideAQuoteRestoresTheParagraph() {
        load([quote("q", [para("a", "one")])])
        caret(1)
        editor.makeCodeBlock()
        XCTAssertEqual(roles(), ["codeLanguage@1", "code@1", "blockQuoteAuthor@1"])
        editor.makeCodeBlock()
        XCTAssertEqual(roles(), ["p@1", "blockQuoteAuthor@1"], "back to a paragraph, still inside the quote")
        XCTAssertEqual(strings(), ["one", ""])
    }

    /// A pull quote likewise.
    func test_makePullQuoteInsideAQuoteNestsIt() {
        load([quote("q", [para("a", "one"), para("b", "two")])])
        caret(1)
        editor.makePullQuote()
        XCTAssertEqual(roles(), ["pullQuote@1", "pullQuoteAuthor@1", "p@1", "blockQuoteAuthor@1"])
    }

    /// A selection spanning a quote's child AND a top-level paragraph still refuses: the two are not
    /// siblings of one parent, so there is no single container for the command to act in. This is
    /// the case `test_makeCodeBlockOverAQuoteChildAndATopLevelParagraphIsANoOp` already pins, kept
    /// honest here against the new sibling-aware splice.
    func test_makeCodeBlockAcrossAQuoteBoundaryIsStillANoOp() {
        load([quote("q", [para("a", "one")]), para("b", "two")])
        let before = roles()
        rangeSelect(NSRange(location: 0, length: 8))
        editor.makeCodeBlock()
        XCTAssertEqual(roles(), before, "no single parent holds both, so nothing happens")
    }

    private func rangeSelect(_ range: NSRange) { editor.engineSelectedRange = range }

    // MARK: R7-details §3.5 — a container's contents are CHILD UNITS

    func test_containerContentsCountsChildrenNotRoles() {
        load([quote("q", [para("a", "one"),
                          .code(CodeBlock(id: BlockID("cd"), language: "swift", runs: [TextRun(text: "x")]))])])
        // Roles: a@1, codeLanguage@1, code@1, q author@1 — FOUR roles, TWO children.
        let contents = editor.contents(of: BlockID("q"), around: 0)
        XCTAssertEqual(contents.units.count, 2, "a code block is ONE child made of two roles")
        XCTAssertFalse(contents.isEmpty)
    }

    /// The defect this type exists to make unwritable: a container child is not an empty paragraph,
    /// however blank its lines are.
    func test_aContainerChildIsNeverAnEmptyChild() {
        load([quote("q", [.code(CodeBlock(id: BlockID("cd"), language: nil, runs: []))])])
        XCTAssertFalse(editor.contents(of: BlockID("q"), around: 0).isEmpty,
                       "an empty CODE BLOCK child does not make the quote empty")
    }

    func test_aQuoteOfBlankParagraphsIsEmpty() {
        load([quote("q", [para("a", ""), para("b", "")])])
        XCTAssertTrue(editor.contents(of: BlockID("q"), around: 0).isEmpty)
    }

    /// An empty NESTED quote presents as one empty paragraph role, so "is this a DIRECT child" is
    /// part of the question.
    func test_aNestedQuoteIsNotAnEmptyDirectChild() {
        load([quote("q", [para("a", ""), quote("q2", [para("b", "")])])])
        XCTAssertFalse(editor.contents(of: BlockID("q"), around: 0).isEmpty)
    }

    /// A unit knows which roles it owns, so a rule can lift or drop a child WHOLE.
    func test_aUnitCoversEveryRoleOfItsChild() {
        load([quote("q", [.code(CodeBlock(id: BlockID("cd"), language: "swift", runs: [TextRun(text: "x")]))])])
        let contents = editor.contents(of: BlockID("q"), around: 0)
        guard let unit = contents.unit(containing: 1) else { return XCTFail("no unit over the code body") }
        XCTAssertEqual(unit.span, 0...1, "the language line and the body are one child")
    }
}
