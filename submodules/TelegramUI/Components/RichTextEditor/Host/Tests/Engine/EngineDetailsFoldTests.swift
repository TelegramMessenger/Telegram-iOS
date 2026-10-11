import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// R7-details §7: folding MOVES the body between the engine and the role's shape — never copies it,
/// so there is only ever one of it. A folded details' span is exactly one engine block: its title.
@available(iOS 18.4, *)
final class EngineDetailsFoldTests: XCTestCase {
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
            let kind = role.secondaryKind.map { "\($0)" } ?? "p"
            return "\(kind)@\(role.containerDepth)"
        }
    }
    private func strings() -> [String] { editor.engine.attributedBlocks.map(\.string) }
    private func load(_ blocks: [Block]) {
        editor.document = Document(blocks: blocks)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
    }
    private func caret(_ at: Int) { editor.engineSelectedRange = NSRange(location: at, length: 0) }
    private func turn() {
        let expectation = expectation(description: "run loop")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)
    }
    /// Counts deliveries over a WINDOW rather than waiting for the first — a wait cannot see a
    /// duplicate landing a turn later. The setup's own delivery is drained by the `turn()` before the
    /// counter is installed, or every case reads as one more than it should.
    private func deliveries(_ act: () -> Void) -> Int {
        turn()
        var calls = 0
        editor.onChange = { calls += 1 }
        act()
        turn()
        editor.onChange = nil
        return calls
    }

    func test_foldingTakesTheBodyOutOfTheEngineAndKeepsItInTheRole() {
        load([details("d", title: "T", [para("a", "one")])])
        editor.toggleDetailsExpanded(id: BlockID("d"))
        XCTAssertEqual(roles(), ["detailsTitle@1"], "one engine block: the title")
        XCTAssertEqual(strings(), ["T"])
        guard case let .details(read) = editor.document.blocks[0] else { return XCTFail("not a details") }
        XCTAssertEqual(read.expanded, false)
        XCTAssertEqual(read.children.count, 1, "the body is still there, in the model")
        XCTAssertEqual(read.children.first?.asParagraph?.runs.first?.text, "one")
    }

    func test_unfoldingPutsTheBodyBack() {
        load([details("d", title: "T", [para("a", "one")], expanded: false)])
        editor.toggleDetailsExpanded(id: BlockID("d"))
        XCTAssertEqual(roles(), ["detailsTitle@1", "p@1"])
        XCTAssertEqual(strings(), ["T", "one"])
    }

    func test_foldAndUnfoldRoundTripsTheBody() {
        load([details("d", title: "T", [para("a", "one"), para("b", "two")])])
        editor.toggleDetailsExpanded(id: BlockID("d"))
        editor.toggleDetailsExpanded(id: BlockID("d"))
        XCTAssertEqual(strings(), ["T", "one", "two"])
    }

    /// P3: the caret cannot stay in a body that is no longer on the engine's axis.
    ///
    /// A block AFTER the details is what makes this test mean anything. With the details alone the
    /// engine's own out-of-range clamp lands on the title's end by coincidence, and removing the
    /// rescue entirely leaves the case green — measured. Followed by another paragraph, the clamp
    /// would leave the caret pointing into THAT paragraph instead.
    func test_foldingWithTheCaretInTheBodyLandsItAtTheTitlesEnd() {
        load([details("d", title: "T", [para("a", "one")]), para("after", "zzzz")])
        caret(4)                                   // inside "one"
        editor.toggleDetailsExpanded(id: BlockID("d"))
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 1, length: 0), "the title's end")
    }

    func test_foldingWithTheCaretInTheTitleLeavesItThere() {
        load([details("d", title: "Long", [para("a", "one")])])
        caret(2)
        editor.toggleDetailsExpanded(id: BlockID("d"))
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 2, length: 0))
    }

    func test_undoOfAFoldRestoresTheBody() {
        load([details("d", title: "T", [para("a", "one")])])
        editor.toggleDetailsExpanded(id: BlockID("d"))
        XCTAssertEqual(roles(), ["detailsTitle@1"])
        editor.engine.undoManager?.undo()
        XCTAssertEqual(roles(), ["detailsTitle@1", "p@1"], "the body comes back")
        XCTAssertEqual(strings(), ["T", "one"])
    }

    func test_aFoldDeliversExactlyOneChange() {
        load([details("d", title: "T", [para("a", "one")])])
        XCTAssertEqual(deliveries { editor.toggleDetailsExpanded(id: BlockID("d")) }, 1)
    }

    func test_anUnfoldDeliversExactlyOneChange() {
        load([details("d", title: "T", [para("a", "one")], expanded: false)])
        XCTAssertEqual(deliveries { editor.toggleDetailsExpanded(id: BlockID("d")) }, 1)
    }

    /// The parent's shape holds the child's model wholesale, so a nested details' own fold state
    /// survives its parent being folded and unfolded.
    func test_aNestedDetailsKeepsItsStateInsideAFoldedParent() {
        load([details("outer", title: "O",
                      [details("inner", title: "I", [para("a", "one")], expanded: false)])])
        editor.toggleDetailsExpanded(id: BlockID("outer"))
        editor.toggleDetailsExpanded(id: BlockID("outer"))
        guard case let .details(outer) = editor.document.blocks[0],
              case let .details(inner) = outer.children[0] else { return XCTFail("shape lost") }
        XCTAssertEqual(inner.expanded, false, "the inner fold survived the outer one")
        XCTAssertEqual(inner.children.count, 1, "…and so did its hidden body")
    }

    /// §7.3: the hidden body must not reach the presentation probe — two details differing only in
    /// what they have folded away render their titles identically.
    func test_theFoldedBodyIsNotAPresentationKey() {
        let withBody = EngineBlockRole.secondary(
            owner: .details(DetailsShape(id: BlockID("d"), expanded: false,
                                         foldedChildren: [para("a", "one")])),
            line: DetailsShape.titleLineID(BlockID("d")), kind: .detailsTitle,
            within: [.details(DetailsShape(id: BlockID("d"), expanded: false,
                                           foldedChildren: [para("a", "one")]))])
        let without = EngineBlockRole.secondary(
            owner: .details(DetailsShape(id: BlockID("d"), expanded: false, foldedChildren: [])),
            line: DetailsShape.titleLineID(BlockID("d")), kind: .detailsTitle,
            within: [.details(DetailsShape(id: BlockID("d"), expanded: false, foldedChildren: []))])
        XCTAssertEqual(EngineDocumentBridge.probeShapeKey(for: withBody),
                       EngineDocumentBridge.probeShapeKey(for: without))
    }

    // MARK: the review wave — a folded details is a container with no primary, and everything that
    // asks "does this container still have a primary" had to learn that.

    /// §7.1's invariant read as damage: a folded details' span is exactly ONE role, its secondary
    /// title, so a settle that asks "does this container have a primary block" declared every folded
    /// title an orphan and rewrote it to a paragraph — dropping the `.details` ancestor and with it
    /// `foldedChildren`, the ONLY copy of the body.
    ///
    /// No fold test could see it: `setExpanded` goes through the document setter, whose edit
    /// `isApplyingHostDocument` swallows, so settle never runs during a fold. It takes a keystroke
    /// AFTERWARDS, anywhere in the document.
    func test_typingAfterAFoldDoesNotDestroyTheFoldedDetails() {
        load([details("d", title: "T", [para("a", "one")]), para("after", "")])
        editor.toggleDetailsExpanded(id: BlockID("d"))
        XCTAssertEqual(roles(), ["detailsTitle@1", "p@0"])
        caret(2)                                   // the trailing paragraph
        editor.engine.insertText("x")
        XCTAssertEqual(roles(), ["detailsTitle@1", "p@0"], "the folded details is still a details")
        guard case let .details(read) = editor.document.blocks[0] else { return XCTFail("not a details") }
        XCTAssertEqual(read.children.count, 1, "and its hidden body is still there")
        XCTAssertEqual(read.children.first?.asParagraph?.runs.first?.text, "one")
    }

    /// The same shape at the coverage rule: with no primary in its span a folded details reported
    /// itself never covered, so Select All + Backspace left it standing — and the deleted body was
    /// still in the model, ready to be sent.
    func test_selectAllOverAFoldedDetailsDropsItAndItsHiddenBody() {
        load([details("d", title: "T", [para("a", "one")], expanded: false), para("after", "z")])
        let start = editor.engine.beginningOfDocument
        let end = editor.engine.endOfDocument
        editor.engine.replace(editor.engine.textRange(from: start, to: end)!, withText: "")
        XCTAssertFalse(editor.document.blocks.contains { if case .details = $0 { return true }; return false },
                       "no details survives, hidden body included")
    }

    /// The settle exemption has to be about the SPAN being asked about, not about the folded details
    /// itself. Exempting only a folded details' own title left the question asked of its PARENT
    /// unanswered: an outer details (or a quote) whose only child is a folded details has a span
    /// holding nothing but that folded title, so the outer container was collected as an orphan and
    /// destroyed on the next keystroke.
    func test_typingBesideADetailsHoldingAFoldedOneKeepsBoth() {
        load([details("outer", title: "O",
                      [details("inner", title: "I", [para("a", "one")], expanded: false)]),
              para("after", "")])
        XCTAssertEqual(roles(), ["detailsTitle@1", "detailsTitle@2", "p@0"])
        caret(4)                                   // the trailing paragraph
        editor.engine.insertText("x")
        XCTAssertEqual(roles(), ["detailsTitle@1", "detailsTitle@2", "p@0"], "both survive")
        guard case let .details(outer) = editor.document.blocks[0],
              case let .details(inner) = outer.children[0] else { return XCTFail("shape lost") }
        XCTAssertEqual(inner.children.count, 1, "and the hidden body is still there")
    }

    /// K3 #3. A fold REMOVES the body from the engine's axis, so every offset after it moves by that
    /// much. Restoring the caret's absolute offset leaves it on different text — after folding a
    /// details holding "one", a caret in the paragraph below landed three characters earlier.
    func test_foldingShiftsACaretAfterTheBlockByTheBodyItRemoved() {
        load([details("d", title: "T", [para("a", "one")]), para("after", "abcdef")])
        caret(9)                                   // T[0,1] one[2,5] abcdef[6,12] → "abc|def"
        editor.toggleDetailsExpanded(id: BlockID("d"))
        XCTAssertEqual(strings(), ["T", "abcdef"])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 5, length: 0), "still at abc|def")
    }

    func test_unfoldingShiftsACaretAfterTheBlockByTheBodyItRestored() {
        load([details("d", title: "T", [para("a", "one")], expanded: false), para("after", "abcdef")])
        caret(5)                                   // "abc|def"
        editor.toggleDetailsExpanded(id: BlockID("d"))
        XCTAssertEqual(strings(), ["T", "one", "abcdef"])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 9, length: 0), "still at abc|def")
    }
}
