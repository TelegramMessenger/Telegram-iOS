import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// R7-details §6: the title takes the exits its body cannot, and the block above a details' body is
/// its TITLE — a field, not text to merge into.
@available(iOS 18.4, *)
final class EngineDetailsGateTests: XCTestCase {
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
    private func details(_ id: String, title: String, _ children: [Block], expanded: Bool = true) -> Block {
        .details(DetailsBlock(id: BlockID(id), title: title.isEmpty ? [] : [TextRun(text: title)],
                              children: children, expanded: expanded))
    }
    private func roles() -> [String] {
        editor.currentRoles.map { role in
            let kind: String
            if role.owningTable != nil { kind = "cell" }
            else if let secondary = role.secondaryKind { kind = "\(secondary)" }
            else {
                switch role.shape {
                case .media: kind = "media"; case .buttonRow: kind = "buttonRow"
                case .code: kind = "code"
                case .pullQuote: kind = "pullQuote"; case .collapsedQuote: kind = "collapsedQuote"
                case .paragraph: kind = "p"
                }
            }
            return "\(kind)@\(role.containerDepth)"
        }
    }
    private func strings() -> [String] { editor.engine.attributedBlocks.map(\.string) }
    private func load(_ blocks: [Block]) {
        editor.document = Document(blocks: blocks)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
    }
    private func caret(_ at: Int) { editor.engineSelectedRange = NSRange(location: at, length: 0) }
    private func rangeReplace(_ range: NSRange, _ text: String) {
        let start = editor.engine.position(from: editor.engine.beginningOfDocument, offset: range.location)!
        let end = editor.engine.position(from: start, offset: range.length)!
        editor.engine.replace(editor.engine.textRange(from: start, to: end)!, withText: text)
    }

    // MARK: §6.1 Return

    /// A language line's Return, exactly: the caret moves into the body and no text is inserted.
    func test_returnInTheTitleMovesIntoTheBody() {
        load([details("d", title: "T", [para("a", "one")])])
        caret(1)                                   // end of "T"
        editor.engine.insertText("\n")
        XCTAssertEqual(strings(), ["T", "one"], "no text was inserted")
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 2, length: 0), "at the body's start")
    }

    func test_returnOnTheEmptyLastChildLeavesTheDetails() {
        load([details("d", title: "T", [para("a", "one"), para("b", "")])])
        caret(6)                                   // the empty last child
        editor.engine.insertText("\n")
        XCTAssertEqual(roles(), ["detailsTitle@1", "p@1", "p@0"],
                       "the empty child became a paragraph in the details' PARENT")
    }

    // MARK: §6.2 Backspace

    /// Decision 5: the title is the heading the user typed, so an unwrap KEEPS it as a paragraph —
    /// unlike a quote's unwrap, which drops its author line because an attribution is metadata.
    func test_backspaceAtTheStartOfTheTitleUnwrapsAndKeepsTheTitleText() {
        load([para("before", "x"), details("d", title: "T", [para("a", "one")])])
        caret(2)                                   // start of "T"
        editor.engine.deleteBackward()
        XCTAssertEqual(roles(), ["p@0", "p@0", "p@0"])
        XCTAssertEqual(strings(), ["x", "T", "one"], "the title survives as a paragraph")
    }

    /// The block above the first body child is the TITLE, and body text must not merge up into a
    /// heading — so it is a wall and the caret travels to the title's end.
    func test_backspaceAtTheStartOfTheFirstBodyChildIsAWall() {
        load([details("d", title: "T", [para("a", "one"), para("b", "two")])])
        caret(2)                                   // start of "one"
        editor.engine.deleteBackward()
        XCTAssertEqual(strings(), ["T", "one", "two"], "nothing merged")
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 1, length: 0), "at the title's end")
    }

    /// A wholly empty details un-details in place — legacy's `startsEmptyContainer` shape.
    func test_backspaceInAWhollyEmptyDetailsUnDetailsIt() {
        load([details("d", title: "", [para("a", "")])])
        caret(1)                                   // the empty body child
        editor.engine.deleteBackward()
        XCTAssertEqual(roles(), ["p@0"])
    }

    // MARK: §6.3 ranges

    func test_aRangeOverTheWholeDetailsDropsIt() {
        load([details("d", title: "T", [para("a", "one")]), para("after", "z")])
        rangeReplace(NSRange(location: 0, length: 5), "")
        XCTAssertEqual(roles(), ["p@0", "p@0"], "the details went whole, title included")
    }

    /// A details that is a QUOTE's only child is a CHILD container: covering it drops the details and
    /// leaves the quote standing (the `coveredUnit` leaf-first rule, inherited from R7-nesting).
    func test_aRangeOverADetailsInsideAQuoteLeavesTheQuote() {
        load([.blockQuote(BlockQuote(id: BlockID("q"),
                                     children: [details("d", title: "T", [para("a", "one")])]))])
        rangeReplace(NSRange(location: 0, length: 5), "")
        XCTAssertTrue(editor.currentRoles.contains { $0.containerDepth >= 1 },
                      "the quote survives the details being dropped")
    }

    // MARK: the review wave

    /// The empty-container dissolve asks `ContainerContents.isEmpty`, which counts CHILD UNITS —
    /// and a container's own owned line is deliberately not a child. For a quote that is right (an
    /// author is a field). For a details it destroys authored content: decision 5 says the title is
    /// the heading the user typed.
    ///
    /// This is the first thing a user does with the feature: insert a details, type a title, hit
    /// Backspace once to fix a typo. The body child is still empty, so the whole block — title
    /// included — collapsed to one empty paragraph.
    func test_backspaceInATitleDoesNotDissolveADetailsWhoseBodyIsMerelyEmpty() {
        load([details("d", title: "Notes", [para("a", "")])])
        caret(5)                                   // end of "Notes"
        editor.engine.deleteBackward()
        XCTAssertEqual(roles(), ["detailsTitle@1", "p@1"], "the details survives")
        XCTAssertEqual(strings(), ["Note", ""], "and Backspace deleted one character of the title")
    }

    /// The same rule from the body side: §6.2 says the start of the first body child is a WALL.
    func test_backspaceAtTheStartOfAnEmptyBodyChildUnderATitledDetailsIsAWall() {
        load([details("d", title: "Notes", [para("a", "")])])
        caret(6)                                   // the empty body child
        editor.engine.deleteBackward()
        XCTAssertEqual(roles(), ["detailsTitle@1", "p@1"])
        XCTAssertEqual(strings(), ["Notes", ""], "nothing was destroyed")
    }

    /// `flatOffsetOfFirstBodyBlock` matched on `innermostAncestor?.details?.id`, which a body child
    /// that is ITSELF an ancestor container never satisfies — its innermost ancestor is its own
    /// container. So Return in the title of a details whose first child is a quote (or another
    /// details) moved nowhere and the keystroke was vetoed: Return did nothing at all.
    func test_returnInTheTitleMovesIntoABodyThatIsItselfAContainer() {
        load([.details(DetailsBlock(id: BlockID("d"), title: [TextRun(text: "T")],
                                    children: [.blockQuote(BlockQuote(id: BlockID("q"),
                                                                      children: [para("a", "one")]))],
                                    expanded: true))])
        caret(1)                                   // end of "T"
        editor.engine.insertText("\n")
        // Three blocks, not two: a quote with content carries an author line. Nothing was INSERTED,
        // which is what this pins — the title's Return is a caret move.
        XCTAssertEqual(strings(), ["T", "one", ""], "no text was inserted")
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 2, length: 0), "at the quoted body's start")
    }

    /// §6.3: only a range WHOLLY covering the details drops it. Coverage filtered the span to
    /// primaries, so a range over the body alone reported the whole thing covered and took the title
    /// — content the selection never touched.
    func test_aRangeOverTheBodyAloneKeepsTheTitle() {
        load([details("d", title: "T", [para("a", "one")]), para("after", "z")])
        rangeReplace(NSRange(location: 2, length: 5), "")   // "one" .. end of "z"
        XCTAssertTrue(strings().contains("T"), "the title the selection never reached survives")
    }

    /// BOTH DOORS. The caret door's wall is `consumeBackspaceAtARegionBoundary`; delivered as the
    /// join range the same keystroke fell through to `replaceAcrossBlocks`, which MERGES — so the
    /// body's text was pulled up into the title where the caret door refused it.
    func test_theRangeDoorWallsAtADetailsFirstBodyChildToo() {
        load([details("d", title: "Notes", [para("a", "one")])])
        rangeReplace(NSRange(location: 5, length: 1), "")   // the join between title and body
        XCTAssertEqual(strings(), ["Notes", "one"], "nothing merged up into the heading")
    }

    /// …and the same door must not empty the details of its last child, which leaves a container
    /// settle then has to decide about.
    func test_theRangeDoorDoesNotEmptyADetailsOfItsLastChild() {
        load([details("d", title: "Notes", [para("a", "")])])
        rangeReplace(NSRange(location: 5, length: 1), "")
        XCTAssertEqual(roles(), ["detailsTitle@1", "p@1"])
        XCTAssertEqual(strings(), ["Notes", ""])
    }

    // MARK: the K3 pass, 2026-09-08

    /// K3 #1. Tab is the title's other exit: a language line has none, but a title sits above a body
    /// the way a form field sits above the next, and Tab is what a user reaches for.
    func test_tabInTheTitleOfAnExpandedDetailsMovesIntoTheBody() {
        load([details("d", title: "T", [para("a", "one")])])
        caret(1)
        // The WIRING, not just the rule: without a key command claiming Tab in a title the rule is
        // unreachable, which is how the chevron's tap went missing for a whole rung.
        XCTAssertTrue(editor.keyCommands?.contains { $0.input == "\t" && $0.modifierFlags.isEmpty } ?? false,
                      "a title claims Tab")
        editor.moveCaretOutOfDetailsTitle()
        XCTAssertEqual(strings(), ["T", "one"], "no text was inserted")
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 2, length: 0), "at the body's start")
    }

    /// K3 #2. A COLLAPSED details has no body on the engine's axis, and unfolding it is not what the
    /// user asked for — they asked to leave. Both exits land on the block AFTER the details, at its
    /// own level, and mint one when there is none.
    func test_tabInTheTitleOfACollapsedDetailsGoesToTheBlockAfterIt() {
        load([details("d", title: "T", [para("a", "one")], expanded: false), para("after", "z")])
        caret(1)
        editor.moveCaretOutOfDetailsTitle()
        XCTAssertEqual(roles(), ["detailsTitle@1", "p@0"], "still folded")
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 2, length: 0), "at the block after it")
    }

    func test_returnInTheTitleOfACollapsedDetailsMintsAParagraphAfterIt() {
        load([details("d", title: "T", [para("a", "one")], expanded: false)])
        caret(1)
        editor.engine.insertText("\n")
        XCTAssertEqual(roles(), ["detailsTitle@1", "p@0"], "still folded, and a paragraph beside it")
        XCTAssertEqual(strings(), ["T", ""])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 2, length: 0))
    }

    /// K3 #4. The paragraph after a details must stay outside it. Backspace anywhere in a FOLLOWING
    /// paragraph was pulling the first one into the block.
    func test_backspaceInAParagraphAfterADetailsLeavesItOutsideTheBlock() {
        load([details("d", title: "T", [para("a", "one")]), para("x", "abc"), para("y", "def")])
        caret(8)                                   // inside "abc"
        editor.engine.deleteBackward()
        XCTAssertEqual(roles(), ["detailsTitle@1", "p@1", "p@0", "p@0"], "the paragraph is still outside")
        XCTAssertEqual(strings(), ["T", "one", "ac", "def"])
    }

    private func table(_ id: String) -> Block {
        .table(TableBlock(id: BlockID(id), columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
                          rows: [Row(id: BlockID("\(id)r"),
                                     cells: [Cell(id: BlockID("\(id)c0"), blocks: [para("\(id)p0", "")]),
                                             Cell(id: BlockID("\(id)c1"), blocks: [para("\(id)p1", "")])])]))
    }

    /// K3 #4 is NOT reproduced by any of these, and they are kept as the boundary of what was
    /// checked: a paragraph after a details stays outside it through BOTH doors, whether the details'
    /// body ends in a paragraph or in a table, and whether the Backspace is at the paragraph's start,
    /// mid-text, or in a later paragraph of the run.
    func test_aParagraphAfterADetailsStaysOutsideItThroughBothDoors() {
        for endsInATable in [false, true] {
            let body: [Block] = endsInATable ? [table("t")] : [para("a", "one")]
            // `p1` is the FIRST paragraph after the block — the one the K3 report says moves in.
            load([details("d", title: "T", body), para("p1", "aaa"), para("p2", "bbb")])
            let before = roles()
            let p1 = editor.currentRoles.count - 2
            caret(editor.flatOffset(ofRoleAt: p1) + 1)
            editor.engine.deleteBackward()                       // caret door, mid-text of p1
            XCTAssertEqual(roles(), before, "caret door, endsInATable=\(endsInATable)")

            load([details("d", title: "T", body), para("p1", "aaa"), para("p2", "bbb")])
            // The join between the DETAILS and p1, which is the boundary in question — not the one
            // between p1 and p2, where two plain paragraphs merge and SHOULD.
            let join = editor.flatOffset(ofRoleAt: editor.currentRoles.count - 2) - 1
            rangeReplace(NSRange(location: join, length: 1), "")
            XCTAssertEqual(roles(), before, "range door, endsInATable=\(endsInATable)")
        }
    }

    /// The type-then-backspace sequence, which is what produced the pass-3 defect on this branch.
    func test_typingThenBackspacingAfterADetailsLeavesTheParagraphOutside() {
        load([details("d", title: "T", [table("t")]), para("p", "")])
        let before = roles()
        caret(flatStartOfLastRole())
        editor.engine.insertText("k")
        editor.engine.deleteBackward()
        XCTAssertEqual(roles(), before)
        XCTAssertEqual(strings().last, "")
    }

    private func flatStartOfLastRole() -> Int {
        editor.engine.attributedBlocks.dropLast().reduce(0) { $0 + $1.length + 1 }
    }

    func test_probeRangeDoorJoinAfterADetails() {
        load([details("d", title: "T", [para("a", "one")]), para("x", "abc")])
        let before = roles()
        rangeReplace(NSRange(location: 5, length: 1), "")   // the join before "abc"
        XCTAssertEqual(roles(), before, "PROBE D: still outside")
        XCTAssertEqual(strings(), ["T", "one", "abc"], "PROBE D strings: \(strings())")
    }

    func test_probeRangeDoorJoinAfterADetailsEndingInATable() {
        load([details("d", title: "T", [table("t")]), para("x", "abc")])
        let before = roles()
        let start = flatStartOfLastRole()
        rangeReplace(NSRange(location: start - 1, length: 1), "")
        XCTAssertEqual(roles(), before, "PROBE E: still outside")
        XCTAssertEqual(strings().last, "abc", "PROBE E strings: \(strings())")
    }

    func test_probeTypeThenBackspaceInAParagraphAfterADetails() {
        load([details("d", title: "T", [para("a", "one")]), para("x", "")])
        let before = roles()
        caret(6)
        editor.engine.insertText("k")
        editor.engine.deleteBackward()
        XCTAssertEqual(roles(), before, "PROBE F: still outside")
        XCTAssertEqual(strings(), ["T", "one", ""], "PROBE F strings: \(strings())")
    }

    func test_probeTypeThenBackspaceAfterADetailsEndingInATable() {
        load([details("d", title: "T", [table("t")]), para("x", "")])
        let before = roles()
        caret(flatStartOfLastRole())
        editor.engine.insertText("k")
        editor.engine.deleteBackward()
        XCTAssertEqual(roles(), before, "PROBE G: still outside — got \(roles())")
        XCTAssertEqual(strings().last, "", "PROBE G strings: \(strings())")
    }

    func test_probeBackspaceInTheThirdParagraphAfterADetails() {
        load([details("d", title: "T", [para("a", "one")]),
              para("p1", "aaa"), para("p2", "bbb"), para("p3", "ccc")])
        let before = roles()
        caret(16)                                  // inside "ccc"
        editor.engine.deleteBackward()
        XCTAssertEqual(roles(), before, "PROBE H: got \(roles())")
        XCTAssertEqual(strings(), ["T", "one", "aaa", "bbb", "cc"], "PROBE H strings: \(strings())")
    }

    func test_probeBackspaceInTheThirdParagraphAfterADetailsWithATable() {
        load([details("d", title: "T", [table("t")]),
              para("p1", "aaa"), para("p2", "bbb"), para("p3", "ccc")])
        let before = roles()
        caret(flatStartOfLastRole() + 2)
        editor.engine.deleteBackward()
        XCTAssertEqual(roles(), before, "PROBE I: got \(roles())")
        XCTAssertEqual(strings().suffix(3).joined(separator: "|"), "aaa|bbb|cc", "PROBE I strings: \(strings())")
    }

    /// The shape the K3 report actually describes: a details holding a table, several paragraphs
    /// after it, and a Backspace somewhere in them — with a LAYOUT pass in between, which is what a
    /// device does and a bare harness edit does not.
    func test_probeBackspaceAfterALayoutPassWithATableInTheDetails() {
        load([details("d", title: "T", [table("t")]), para("p1", "aaa"), para("p2", "bbb")])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        let before = roles()
        caret(flatStartOfLastRole() + 2)
        editor.engine.deleteBackward()
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        XCTAssertEqual(roles(), before, "PROBE J: got \(roles())")
    }
}
