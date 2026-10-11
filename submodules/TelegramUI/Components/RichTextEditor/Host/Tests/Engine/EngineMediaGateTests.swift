import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// The surface-gate rules for a media unit (spec §5). Every rule reachable through two doors is
/// tested through both: the collapsed caret at the first-refusal handler and the range at the gate.
@available(iOS 18.4, *)
final class EngineMediaGateTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!
    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    func item(_ id: String, kind: MediaKind = .image) -> MediaItem { MediaItem(mediaID: id, kind: kind, naturalSize: Size2D(width: 1000, height: 500)) }
    func photo(_ id: String, _ caption: String = "") -> Block {
        .media(MediaBlock(id: BlockID(id), items: [item("m-\(id)")], caption: caption.isEmpty ? [] : [TextRun(text: caption)]))
    }
    func audio(_ id: String) -> Block { .media(MediaBlock(id: BlockID(id), items: [item("m-\(id)", kind: .audio)])) }
    func para(_ id: String, _ text: String) -> Block { .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)])) }
    func strings() -> [String] { editor.engine.attributedBlocks.map { $0.string.replacingOccurrences(of: "\u{FFFC}", with: "▣") } }
    func kinds() -> [String] {
        editor.currentRoles.map { role in
            if role.owningTable != nil { return "cell" }
            if let kind = role.secondaryKind { return "secondary.\(kind)" }
            switch role.shape { case .media: return "media"; case .buttonRow: return "buttonRow"; case .code: return "code"; case .pullQuote: return "pullQuote"; case .collapsedQuote: return "collapsedQuote"; case .paragraph: return "std" }
        }
    }
    func load(_ blocks: [Block]) { editor.document = Document(blocks: blocks); XCTAssertTrue(editor.engine.becomeFirstResponder()) }
    func caret(_ at: Int) { editor.engineSelectedRange = NSRange(location: at, length: 0) }
    func rangeReplace(_ range: NSRange, _ text: String) {
        let start = editor.engine.position(from: editor.engine.beginningOfDocument, offset: range.location)!
        let end = editor.engine.position(from: start, offset: range.length)!
        editor.engine.replace(editor.engine.textRange(from: start, to: end)!, withText: text)
    }
    func turn() { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }

    // Layout of ["before", photo a "cap", "after"] on the engine axis:
    // before 0..6 | ▣ 7 (offsets 7 before, 8 after) | cap 9..12 | after 13..18

    // MARK: - §5.1 the atom's two stops

    func test_typingBeforeTheAtomOpensAParagraphAbove() {
        load([para("p0", "before"), photo("a", "cap")])
        caret(7)
        editor.engine.insertText("x")
        XCTAssertEqual(strings(), ["before", "x", "▣", "cap"])
        XCTAssertEqual(kinds(), ["std", "std", "media", "secondary.mediaCaption"])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 8, length: 0), "at the end of the text")
    }

    func test_returnBeforeTheAtomOpensAnEmptyParagraphAbove() {
        load([photo("a", "cap")])
        caret(0)
        editor.engine.insertText("\n")
        XCTAssertEqual(strings(), ["", "▣", "cap"])
        XCTAssertEqual(kinds(), ["std", "media", "secondary.mediaCaption"])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 0, length: 0))
    }

    func test_aMultiLinePasteBeforeTheAtomIsOneParagraphPerLine() {
        load([photo("a", "cap")])
        caret(0)
        editor.engine.insertText("one\ntwo")
        XCTAssertEqual(strings(), ["one", "two", "▣", "cap"])
        XCTAssertEqual(kinds(), ["std", "std", "media", "secondary.mediaCaption"])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 7, length: 0))
    }

    func test_typingAfterTheAtomLandsAtTheCaptionsStart() {
        load([photo("a", "cap")])
        caret(1)
        editor.engine.insertText("x")
        XCTAssertEqual(strings(), ["▣", "xcap"])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 3, length: 0))
    }

    func test_returnAfterTheAtomIsReturnAtTheCaptionsStart() {
        load([photo("a", "cap")])
        caret(1)
        editor.engine.insertText("\n")
        turn()
        XCTAssertEqual(strings(), ["▣", "", "cap"], "an empty caption stays; the caption moved below as a body paragraph")
        XCTAssertEqual(kinds(), ["media", "secondary.mediaCaption", "std"])
    }

    func test_typingAfterACaptionlessAtomOpensAParagraphBelow() {
        load([audio("a")])
        caret(1)
        editor.engine.insertText("x")
        XCTAssertEqual(strings(), ["▣", "x"])
        XCTAssertEqual(kinds(), ["media", "std"])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 3, length: 0))
    }

    func test_returnAfterACaptionlessAtomOpensAnEmptyParagraphBelow() {
        load([audio("a"), para("p1", "after")])
        caret(1)
        editor.engine.insertText("\n")
        XCTAssertEqual(strings(), ["▣", "", "after"])
        XCTAssertEqual(kinds(), ["media", "std", "std"])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 2, length: 0))
    }

    func test_theAtomIsNeverTypedInto() {
        load([para("p0", "before"), photo("a", "cap")])
        for stop in [7, 8] {
            caret(stop)
            editor.engine.insertText("q")
            XCTAssertEqual(editor.engine.attributedBlocks[editor.mediaAtomIndex(ofBlock: BlockID("a"))!].string, "\u{FFFC}",
                           "typing at stop \(stop) must not land on the atom's line")
        }
    }

    // MARK: - §5.2 two steps, one discriminator

    func test_backspaceAfterTheAtomSelectsItThenDeletesUnitAndCaption() {
        load([para("p0", "before"), photo("a", "cap"), para("p1", "after")])
        caret(8)
        editor.engine.deleteBackward()
        XCTAssertEqual(strings(), ["before", "▣", "cap", "after"], "first press: nothing deleted")
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 7, length: 1), "the atom is selected")
        editor.engine.deleteBackward()
        XCTAssertEqual(strings(), ["before", "", "after"], "second press: media and caption gone, an empty paragraph in place")
        XCTAssertEqual(kinds(), ["std", "std", "std"])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 7, length: 0))
    }

    func test_backspaceAtCaptionStartSelectsTheAtom_bothDoors() {
        load([photo("a", "cap")])
        caret(2)                                    // the caret door
        editor.engine.deleteBackward()
        XCTAssertEqual(strings(), ["▣", "cap"])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 0, length: 1))
        load([photo("a", "cap")])
        rangeReplace(NSRange(location: 1, length: 1), "")   // the range door: the join "\n"
        XCTAssertEqual(strings(), ["▣", "cap"])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 0, length: 1))
    }

    func test_typingOverASelectedAtomDropsTheUnitWithTheTextInItsPlace() {
        load([photo("a", "cap"), para("p1", "after")])
        editor.engineSelectedRange = NSRange(location: 0, length: 1)
        editor.engine.insertText("z")
        XCTAssertEqual(strings(), ["z", "after"])
        XCTAssertEqual(kinds(), ["std", "std"])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 1, length: 0))
    }

    func test_aTapSelectedAtomDeletesOnOnePress() {
        load([para("p0", "before"), photo("a", "cap")])
        editor.selectAtomUnit(at: 1)
        editor.engine.deleteBackward()
        XCTAssertEqual(strings(), ["before", ""])
        XCTAssertEqual(kinds(), ["std", "std"])
    }

    func test_backspaceBeforeTheAtomActsOnThePreviousBlock() {
        load([para("p0", "before"), photo("a", "cap")])
        caret(7)
        editor.engine.deleteBackward()
        XCTAssertEqual(strings(), ["befor", "▣", "cap"], "the previous block's last grapheme")
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 5, length: 0))
        load([para("p0", ""), photo("a", "cap")])
        caret(1)
        editor.engine.deleteBackward()
        XCTAssertEqual(strings(), ["▣", "cap"], "an empty previous paragraph is deleted")
        XCTAssertEqual(kinds(), ["media", "secondary.mediaCaption"])
        load([photo("a", "cap")])
        caret(0)
        editor.engine.deleteBackward()
        XCTAssertEqual(strings(), ["▣", "cap"], "a leading atom: no-op")
    }

    func test_backspaceBeforeAnAtomThatFollowsAnotherUnitSelectsThatUnit() {
        load([audio("a"), photo("b", "cap")])
        caret(2)   // before b's atom: "▣\n▣\ncap"
        editor.engine.deleteBackward()
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 0, length: 1), "a's atom is selected, never deleted in one press")
    }

    // MARK: - §5.3 ranges entering a unit

    func test_selectAllAndBackspaceDropsTheUnit() {
        load([para("p0", "before"), photo("a", "cap"), para("p1", "after")])
        editor.engineSelectedRange = NSRange(location: 0, length: 18)
        editor.engine.deleteBackward()
        XCTAssertEqual(strings(), [""])
        XCTAssertEqual(kinds(), ["std"])
    }

    func test_aRangeFromAboveThroughTheAtomIntoTheCaptionKeepsTheUnitAndTruncatesTheCaption() {
        load([para("p0", "before"), photo("a", "caption"), para("p1", "after")])
        editor.engineSelectedRange = NSRange(location: 3, length: 9)   // "ore\n▣\ncap" -> keeps "bef", "tion"
        editor.engine.deleteBackward()
        XCTAssertEqual(strings(), ["bef", "▣", "tion", "after"])
        XCTAssertEqual(kinds(), ["std", "media", "secondary.mediaCaption", "std"])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 3, length: 0))
    }

    func test_aRangeFromTheCaptionIntoTheParagraphBelowKeepsBothAsTheirOwnBlocks() {
        load([photo("a", "caption"), para("p1", "after")])
        editor.engineSelectedRange = NSRange(location: 5, length: 7)    // "tion\naf" -> "cap", "ter"
        editor.engine.deleteBackward()
        XCTAssertEqual(strings(), ["▣", "cap", "ter"])
        XCTAssertEqual(kinds(), ["media", "secondary.mediaCaption", "std"])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 5, length: 0))
    }

    func test_aRangeThatCoversAtomAndWholeCaptionDropsTheUnitIntoTheParagraphAbove() {
        load([para("p0", "before"), photo("a", "cap"), para("p1", "after")])
        editor.engineSelectedRange = NSRange(location: 3, length: 12)   // "ore\n▣\ncap\naf"
        editor.engine.deleteBackward()
        XCTAssertEqual(strings(), ["befter"])
        XCTAssertEqual(kinds(), ["std"])
    }

    func test_typingOverARangeThatEntersTheCaptionPutsTheTextOutsideTheUnit() {
        load([para("p0", "before"), photo("a", "caption")])
        editor.engineSelectedRange = NSRange(location: 3, length: 9)
        editor.engine.insertText("X")
        XCTAssertEqual(strings(), ["befX", "▣", "tion"])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 4, length: 0))
    }

    // MARK: - §5.5 Backspace at the start of the block after a unit

    func test_backspaceAtTheStartOfTheBlockAfterAUnitTravelsOrDeletesAnEmptyOne_bothDoors() {
        load([photo("a", "cap"), para("p1", "after")])           // "▣\ncap\nafter": after starts at 6
        caret(6); editor.engine.deleteBackward()
        XCTAssertEqual(strings(), ["▣", "cap", "after"], "never merges")
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 5, length: 0), "the caption's end")
        load([photo("a", "cap"), para("p1", "after")])
        rangeReplace(NSRange(location: 5, length: 1), "")          // the join, the range door
        XCTAssertEqual(strings(), ["▣", "cap", "after"])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 5, length: 0))
        load([audio("a"), para("p1", "")])                          // "▣\n": the empty block after a caption-less unit
        caret(2); editor.engine.deleteBackward()
        XCTAssertEqual(strings(), ["▣"], "an empty block is deleted")
        XCTAssertEqual(kinds(), ["media"])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 1, length: 0), "after the atom")
    }

    /// The two combinations the pair above leaves out: an EMPTY block after a CAPTIONED unit (the
    /// caret lands at the caption's end, and the empty paragraph goes with it) and a NON-EMPTY block
    /// after a CAPTION-LESS unit (nothing is deleted and the caret lands after the atom, there being
    /// no caption to land at the end of).
    func test_anEmptyBlockAfterACaptionedUnitIsDeletedAndTheCaretLandsAtTheCaptionsEnd() {
        load([photo("a", "cap"), para("p1", "")])                 // "▣\ncap\n": the empty block starts at 6
        caret(6); editor.engine.deleteBackward()
        XCTAssertEqual(strings(), ["▣", "cap"])
        XCTAssertEqual(kinds(), ["media", "secondary.mediaCaption"])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 5, length: 0), "the caption's end")
    }

    func test_aNonEmptyBlockAfterACaptionlessUnitIsKeptAndTheCaretLandsAfterTheAtom() {
        load([audio("a"), para("p1", "after")])                    // "▣\nafter": after starts at 2
        caret(2); editor.engine.deleteBackward()
        XCTAssertEqual(strings(), ["▣", "after"], "never merges, and a non-empty block is never deleted")
        XCTAssertEqual(kinds(), ["media", "std"])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 1, length: 0), "after the atom: there is no caption")
    }

    /// The travel half of §5.5 is unconditional, the DELETION half is not: an empty block that a
    /// container still declares — a cell, a language line, a quote's first child — must not be
    /// removed positionally out from under it.
    func test_backspaceAtTheStartOfAnEmptyCellAfterAUnitTravelsButNeverDeletesTheCell() {
        let table = TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 100)],
                               rows: [Row(id: BlockID("r"), cells: [Cell(id: BlockID("c"))])])
        load([photo("a", "cap"), .table(table)])                    // "▣\ncap\n": the empty cell starts at 6
        caret(6); editor.engine.deleteBackward()
        XCTAssertEqual(kinds(), ["media", "secondary.mediaCaption", "cell"], "the cell's role survives")
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 5, length: 0), "the caret travelled to the caption's end")
    }

    // MARK: - §5.7 refused commands, and the one exception

    /// `makeCodeBlock`/`makePullQuote` flatten their touched blocks to text (§7 of the R7 design),
    /// and a media unit has none to gather — both still refuse a range that touches one.
    /// `wrapInBlockQuote` does NOT flatten — a quote's children are blocks, kept as they stand
    /// (R7-nesting task 5) — so a media unit is now a legal quote child and this third refusal is
    /// gone: the atom and its caption simply move one level deeper, unchanged, so the ••• menu and
    /// the caption still address the same roles, now inside the new quote.
    func test_codeAndPullQuoteRefuseARangeTouchingAUnitButQuoteWrapsIt() {
        load([para("p0", "before"), photo("a", "cap")])
        editor.engineSelectedRange = NSRange(location: 0, length: 12)
        editor.makeCodeBlock()
        XCTAssertEqual(kinds(), ["std", "media", "secondary.mediaCaption"])
        editor.makePullQuote()
        XCTAssertEqual(kinds(), ["std", "media", "secondary.mediaCaption"], "the second container command refuses too")
        editor.wrapInBlockQuote()
        XCTAssertEqual(kinds(), ["std", "media", "secondary.mediaCaption", "secondary.blockQuoteAuthor"])
        XCTAssertTrue(editor.currentRoles.allSatisfy { $0.containerDepth == 1 },
                      "the paragraph, the atom and its caption all moved inside the new quote")
        guard case let .blockQuote(quote)? = editor.document.blocks.first, quote.children.count == 2,
              case .media = quote.children[1] else { return XCTFail("\(editor.document.blocks)") }
    }
}
