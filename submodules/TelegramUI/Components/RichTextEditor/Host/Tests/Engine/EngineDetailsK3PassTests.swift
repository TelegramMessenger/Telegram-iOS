import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// The second K3 pass (2026-09-08), finding by finding.
///
/// Six were reported; THREE reproduced here and are pinned below (#1 the caret at a folded title's
/// end, #2 the double Return at the body's start, #4 the double Return in a details holding only a
/// table). The other three did not reproduce under any instrument tried — roles, strings, derived
/// PRESENTATION, a layout pass between keystrokes, and the table's hosted chrome rather than its text
/// frames — and their cases are kept as the recorded boundary of what was checked, so the next
/// attempt starts from evidence rather than from the same six guesses.
@available(iOS 18.4, *)
final class EngineDetailsK3PassTests: XCTestCase {
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
    private func table(_ id: String) -> Block {
        .table(TableBlock(id: BlockID(id), columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
                          rows: [Row(id: BlockID("\(id)r"),
                                     cells: [Cell(id: BlockID("\(id)c0"), blocks: [para("\(id)p0", "")]),
                                             Cell(id: BlockID("\(id)c1"), blocks: [para("\(id)p1", "")])])]))
    }
    private func roles() -> [String] {
        editor.currentRoles.map { role in
            let kind = role.secondaryKind.map { "\($0)" } ?? (role.owningTable != nil ? "cell" : "p")
            return "\(kind)@\(role.containerDepth)"
        }
    }
    private func strings() -> [String] { editor.engine.attributedBlocks.map(\.string) }
    private func load(_ blocks: [Block]) {
        editor.document = Document(blocks: blocks)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
    }
    private func caret(_ at: Int) { editor.engineSelectedRange = NSRange(location: at, length: 0) }

    /// K3b #1 — caret at the END of a COLLAPSED title, then expand: it must stay in the title.
    func test_expandingWithTheCaretAtAFoldedTitlesEndLeavesItThere() {
        load([details("d", title: "T", [para("a", "one")], expanded: false), para("after", "z")])
        caret(1)
        editor.toggleDetailsExpanded(id: BlockID("d"))
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 1, length: 0),
                       "K3b #1: caret should stay at the title's end, got \(editor.engineSelectedRange)")
    }

    /// K3b #2 — double Return at the START of the body should leave a paragraph ABOVE the block.
    func test_doubleReturnAtTheStartOfTheBodyLeavesAParagraphAboveTheBlock() {
        load([details("d", title: "T", [para("a", "one")])])
        caret(2)
        editor.engine.insertText("\n")
        editor.engine.insertText("\n")
        XCTAssertEqual(roles(), ["p@0", "detailsTitle@1", "p@1"],
                       "K3b #2: got \(roles()) strings \(strings())")
    }

    /// K3b #3 — Backspace at the start of the body drops the block; undo must restore it whole.
    func test_notReproduced_undoAfterBackspaceAtTheStartOfTheBody() {
        load([details("d", title: "T", [para("a", "one")]), para("after", "z")])
        let before = roles()
        let beforeStrings = strings()
        caret(2)
        editor.engine.deleteBackward()
        editor.engine.undoManager?.undo()
        XCTAssertEqual(roles(), before, "K3b #3 roles: got \(roles())")
        XCTAssertEqual(strings(), beforeStrings, "K3b #3 strings: got \(strings())")
    }

    /// K3b #4 — a block whose only child is an empty table: double Return at its end must not drop
    /// the block.
    func test_doubleReturnAtTheEndOfADetailsHoldingOnlyATableKeepsTheBlock() {
        load([details("d", title: "T", [table("t")])])
        caret(editor.flatOffset(ofRoleAt: editor.currentRoles.count - 1))
        editor.engine.insertText("\n")
        editor.engine.insertText("\n")
        XCTAssertTrue(editor.document.blocks.contains { if case .details = $0 { return true }; return false },
                      "K3b #4: the details survives — got \(roles()) / \(editor.document.blocks.count) blocks")
    }

    /// K3b #5 — typing in the first cell of a table inside a details: every character must land there.
    func test_notReproduced_typingInTheFirstCellOfATableInsideADetails() {
        load([details("d", title: "T", [table("t")])])
        caret(editor.flatOffset(ofRoleAt: 1))       // the first cell
        editor.engine.insertText("a")
        editor.engine.insertText("b")
        editor.engine.insertText("c")
        XCTAssertEqual(strings(), ["T", "abc", ""], "K3b #5: got \(strings())")
    }

    /// K3b #6 — a table inserted AFTER a details must sit below its body, not over it.
    func test_notReproduced_tableAfterADetailsDoesNotOverlapItsBody() {
        load([details("d", title: "T", [para("a", "one")]), para("p", "")])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        caret(editor.flatOffset(ofRoleAt: 2))       // the trailing paragraph
        editor.insertTable(rows: 1, cols: 2)
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        let body = editor.engine.id_frameForBlock(at: 1)
        let cells = editor.currentRoles.enumerated().filter { $0.element.owningTable != nil }
        guard let firstCell = cells.first else { return XCTFail("K3b #6: no cells — roles \(roles())") }
        let cellFrame = editor.tableFrame(forTableAt: firstCell.offset)
            ?? editor.engine.id_frameForBlock(at: UInt(firstCell.offset))
        XCTAssertGreaterThanOrEqual(cellFrame.minY, body.maxY,
                                    "K3b #6: table at \(cellFrame) overlaps body \(body)")
    }

    // MARK: sharper instruments for the three that did not reproduce

    /// #3 again, against PRESENTATION rather than roles and strings. The report is visual — "inset as
    /// if it was a block's title, but with no chrome, no body, and no chevron" — which is exactly a
    /// role that is a plain paragraph wearing a title's rendering.
    func test_notReproduced_presentationIsDerivedAfterUndo() {
        load([details("d", title: "T", [para("a", "one")]), para("after", "z")])
        caret(2)
        editor.engine.deleteBackward()
        editor.engine.undoManager?.undo()
        editor.verifyPresentationIsDerived("probe")
        for (index, role) in editor.currentRoles.enumerated() where index < editor.engine.attributedBlocks.count {
            let rendered = editor.bridge.render(role: role, from: editor.engine.attributedBlocks[index])
            XCTAssertEqual(editor.engine.attributedBlocks[index].string, rendered.string,
                           "K3b #3 text at \(index)")
            let live = editor.engine.attributedBlocks[index]
            guard live.length > 0 else { continue }
            let liveStyle = live.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
            let wantStyle = rendered.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
            XCTAssertEqual(liveStyle?.headIndent ?? -1, wantStyle?.headIndent ?? -1, accuracy: 0.01,
                           "K3b #3 indent at \(index): role \(role.secondaryKind.map { "\($0)" } ?? "primary")")
        }
    }

    /// #5 again, with a LAYOUT PASS between keystrokes, which is what a device does between them and
    /// a bare harness edit does not.
    func test_notReproduced_typingInACellWithLayoutBetweenKeystrokes() {
        load([details("d", title: "T", [table("t")])])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        caret(editor.flatOffset(ofRoleAt: 1))
        for character in ["a", "b", "c"] {
            editor.engine.insertText(character)
            editor.setNeedsLayout(); editor.layoutIfNeeded()
        }
        XCTAssertEqual(strings(), ["T", "abc", ""], "K3b #5: got \(strings())")
        XCTAssertEqual(editor.roleIndex(atFlatOffset: editor.engineSelectedRange.location), 1,
                       "K3b #5: caret left the first cell")
    }

    /// #6 again, against the table's hosted CHROME, which is the surface a user sees overlapping —
    /// the cell text frames were already below the body.
    func test_notReproduced_tableChromeAfterADetailsDoesNotOverlapItsBody() {
        load([details("d", title: "T", [para("a", "one")]), para("p", "")])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        caret(editor.flatOffset(ofRoleAt: 2))
        editor.insertTable(rows: 1, cols: 2)
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        let body = editor.engine.id_frameForBlock(at: 1)
        guard let chrome = editor.tableChromeViews.values.first else {
            return XCTFail("K3b #6: no chrome — roles \(roles())")
        }
        let inEngine = chrome.superview.map { $0.convert(chrome.frame, to: editor.engine) } ?? chrome.frame
        XCTAssertGreaterThanOrEqual(inEngine.minY, body.maxY,
                                    "K3b #6: chrome \(inEngine) overlaps body \(body); roles \(roles())")
    }

    /// The QoL ask: Tab steps OUT of the block from its body, and claims the key to do it.
    func test_tabInTheBodyLeavesTheBlock() {
        load([details("d", title: "T", [para("a", "one")]), para("after", "z")])
        caret(3)
        XCTAssertTrue(editor.keyCommands?.contains { $0.input == "\t" && $0.modifierFlags.isEmpty } ?? false,
                      "a details body claims Tab")
        editor.moveCaretOutOfDetails()
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 6, length: 0), "on the block after it")
        XCTAssertEqual(roles(), ["detailsTitle@1", "p@1", "p@0"], "and nothing moved")
    }

    /// …and mints one when the details is the last block.
    func test_tabInTheBodyOfATrailingDetailsMintsAParagraphAfterIt() {
        load([details("d", title: "T", [para("a", "one")])])
        caret(3)
        editor.moveCaretOutOfDetails()
        XCTAssertEqual(roles(), ["detailsTitle@1", "p@1", "p@0"])
        XCTAssertEqual(strings(), ["T", "one", ""])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 6, length: 0))
    }

    /// A cell inside a details keeps the TABLE's meaning of Tab, not this one.
    func test_tabInACellInsideADetailsStillTravelsBetweenCells() {
        load([details("d", title: "T", [table("t")])])
        caret(editor.flatOffset(ofRoleAt: 1))
        editor.moveCaretToNextTableCell()
        XCTAssertEqual(editor.roleIndex(atFlatOffset: editor.engineSelectedRange.location), 2,
                       "the second cell, not the block after the details")
    }

    // MARK: #6, second attempt — where does the table actually LAND?

    /// Decision 3, stated for a details: insertion follows the CARET. A table asked for with the
    /// caret in a details' body becomes a child of that details, exactly as one asked for inside a
    /// quote becomes a child of the quote. The K3 report reads as "it went in the wrong place", but
    /// the placement is right and what is wrong is geometry — which is #6, still open.
    func test_insertingATableWithTheCaretInTheBodyMakesItAChild() {
        load([details("d", title: "T", [para("a", "one")])])
        caret(5)
        editor.insertTable(rows: 1, cols: 2)
        XCTAssertTrue(editor.currentRoles.contains {
            $0.owningTable != nil && $0.innermostAncestor?.details?.id == BlockID("d")
        }, "the table is a child of the block — roles \(roles())")
    }

    /// The real shape: a table that is a details' child, BELOW a body paragraph. Placement is correct
    /// (decision 3 — insertion follows the caret), so what the user sees overlapping is geometry.
    func test_probe6e_aTableInsideADetailsSitsBelowTheBodyAboveIt() {
        load([.details(DetailsBlock(id: BlockID("d"), title: [TextRun(text: "T")],
                                    children: [para("a", "one"), table("t")], expanded: true))])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        let body = editor.engine.id_frameForBlock(at: 1)
        guard let cell = editor.currentRoles.firstIndex(where: { $0.owningTable != nil }) else {
            return XCTFail("K3b #6: no cells — roles \(roles())")
        }
        let grid = editor.tableFrame(forTableAt: cell) ?? editor.engine.id_frameForBlock(at: UInt(cell))
        XCTAssertGreaterThanOrEqual(grid.minY, body.maxY,
                                    "K3b #6: table \(grid) overlaps the body above it \(body)")
        if let chrome = editor.tableChromeViews.values.first {
            let inEngine = chrome.superview.map { $0.convert(chrome.frame, to: editor.engine) } ?? chrome.frame
            XCTAssertGreaterThanOrEqual(inEngine.minY, body.maxY,
                                        "K3b #6 chrome: \(inEngine) overlaps body \(body)")
        }
    }

    /// The user's actual sequence: caret in the body, insert the table, let it lay out.
    func test_probe6f_insertingATableInTheBodyThenLayingOut() {
        load([details("d", title: "T", [para("a", "one")])])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        caret(5)
        editor.insertTable(rows: 1, cols: 2)
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        let body = editor.engine.id_frameForBlock(at: 1)
        guard let cell = editor.currentRoles.firstIndex(where: { $0.owningTable != nil }) else {
            return XCTFail("K3b #6: no cells — roles \(roles())")
        }
        let grid = editor.tableFrame(forTableAt: cell) ?? editor.engine.id_frameForBlock(at: UInt(cell))
        XCTAssertGreaterThanOrEqual(grid.minY, body.maxY,
                                    "K3b #6: after insert, table \(grid) overlaps body \(body)")
        if let chrome = editor.tableChromeViews.values.first {
            let inEngine = chrome.superview.map { $0.convert(chrome.frame, to: editor.engine) } ?? chrome.frame
            XCTAssertGreaterThanOrEqual(inEngine.minY, body.maxY,
                                        "K3b #6 chrome after insert: \(inEngine) overlaps body \(body)")
        }
    }

    /// And without the pre-insert layout pass, which is the difference between a fresh document and
    /// one the user has been editing.
    func test_probe6g_insertingATableInTheBodyOfAFreshDocument() {
        load([details("d", title: "T", [para("a", "one")])])
        caret(5)
        editor.insertTable(rows: 1, cols: 2)
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        let body = editor.engine.id_frameForBlock(at: 1)
        guard let cell = editor.currentRoles.firstIndex(where: { $0.owningTable != nil }) else {
            return XCTFail("K3b #6: no cells")
        }
        let grid = editor.tableFrame(forTableAt: cell) ?? editor.engine.id_frameForBlock(at: UInt(cell))
        XCTAssertGreaterThanOrEqual(grid.minY, body.maxY,
                                    "K3b #6 fresh: table \(grid) overlaps body \(body)")
    }

    /// K3b #3. An undo replays TEXT and never reaches settle, so nothing re-derived the restored
    /// blocks' presentation from their roles and each kept whatever it was wearing — which the report
    /// saw as a plain paragraph in a details title's indent, with no chrome and no chevron.
    ///
    /// The fixture is a CELL merge rather than a details, because that is the shape that actually
    /// trips it and a details-shaped version of this test passed with the fix reverted — it could not
    /// fail, which is the whole reason it is written this way. The assertion is the full presentation
    /// key set, not one attribute: the drift here is a FACE, and an indent-only check misses it.
    ///
    /// Deferred by a turn on purpose: the repair has to wait for the undo group to close.
    func test_undoLeavesEveryBlocksPresentationDerivedFromItsRole() {
        let cell = Cell(id: BlockID("c0"), blocks: [para("cp", "aa")])
        let grid = TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 100)],
                              rows: [Row(id: BlockID("r"), cells: [cell])])
        load([.table(grid), para("after", "after")])
        editor.engineSelectedRange = NSRange(location: 3, length: 0)
        editor.engine.deleteBackward()
        editor.engine.undoManager?.undo()
        let turn = expectation(description: "run loop")
        DispatchQueue.main.async { turn.fulfill() }
        wait(for: [turn], timeout: 1.0)

        for (index, role) in editor.currentRoles.enumerated()
        where index < editor.engine.attributedBlocks.count {
            let live = editor.engine.attributedBlocks[index]
            guard live.length > 0 else { continue }
            let want = editor.bridge.render(role: role, from: live)
            guard want.string == live.string else { continue }
            for key in RichTextEngineEditorView.presentationKeys {
                let have = live.attribute(key, at: 0, effectiveRange: nil) as AnyObject?
                let wanted = want.attribute(key, at: 0, effectiveRange: nil) as AnyObject?
                XCTAssertEqual(have?.isEqual(wanted) ?? (wanted == nil), true,
                               "block \(index) key \(key.rawValue): has \(String(describing: have)), role wants \(String(describing: wanted))")
            }
        }
    }

    /// K3b #6, from the device log. Two tables with NOTHING between them are one contiguous run of
    /// PLACED roles, and the engine anchors a placed run at its first block — so the second table is
    /// laid out from the first one's origin and draws on top of it.
    ///
    /// It reached the user through a details whose body ends in a table: inserting another table
    /// after the block puts the two runs side by side in the role list. Nothing about it is specific
    /// to details, which is why seven details-shaped probes came back clean.
    func test_twoAdjacentTablesDoNotShareAnAnchor() {
        load([table("t1"), table("t2")])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        editor.setNeedsLayout(); editor.layoutIfNeeded()   // the second pass is where it flipped
        guard let a = editor.currentRoles.firstIndex(where: { $0.containerID == BlockID("t1") }),
              let b = editor.currentRoles.firstIndex(where: { $0.containerID == BlockID("t2") })
        else { return XCTFail("roles \(roles())") }
        let aFrame = editor.engine.id_frameForBlock(at: UInt(a))
        let bFrame = editor.engine.id_frameForBlock(at: UInt(b))
        // maxY, not minY: ordered-but-overlapping is the shape this shipped in — two top-level
        // tables were 5pt apart with the first 34pt tall, and a minY assertion called that a pass.
        XCTAssertGreaterThanOrEqual(bFrame.minY, aFrame.maxY,
                                    "the second table overlaps the first: \(bFrame) vs \(aFrame)")
    }

    /// The shape the user actually hit: a details whose body ends in a table, then a table after it.
    func test_aTableAfterADetailsEndingInATableDoesNotOverlapIt() {
        load([details("d", title: "T", [table("inner")]), table("outer")])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        guard let inner = editor.currentRoles.firstIndex(where: { $0.containerID == BlockID("inner") }),
              let outer = editor.currentRoles.firstIndex(where: { $0.containerID == BlockID("outer") })
        else { return XCTFail("roles \(roles())") }
        let innerFrame = editor.engine.id_frameForBlock(at: UInt(inner))
        let outerFrame = editor.engine.id_frameForBlock(at: UInt(outer))
        XCTAssertGreaterThanOrEqual(outerFrame.minY, innerFrame.maxY,
                                    "the table after the block sits on it: \(outerFrame) vs \(innerFrame)")
    }



    // MARK: - K3c (2026-09-08): Return in the last cell of a details' trailing table

    /// Return in the LAST cell of a table that is a details' last body item must add a paragraph
    /// INSIDE the details — exactly what it already does when the details is the document's last
    /// block. The role after that cell is the top-level paragraph FOLLOWING the details, which is not
    /// a sibling of the table at all, so "is there a next role" is the wrong question.
    func test_returnInTheLastCellOfADetailsTrailingTableAddsAParagraphInsideTheDetails() {
        load([details("d", title: "T", [para("a", "one"), table("t")]), para("after", "z")])
        guard let lastCell = editor.currentRoles.lastIndex(where: { $0.owningTable != nil }) else {
            return XCTFail("no cells — roles \(roles())")
        }
        caret(editor.flatOffset(ofRoleAt: lastCell))
        editor.engine.insertText("\n")
        XCTAssertEqual(roles(), ["detailsTitle@1", "p@1", "cell@1", "cell@1", "p@1", "p@0"],
                       "a fresh paragraph INSIDE the details, got \(roles()) strings \(strings())")
        XCTAssertEqual(editor.engineSelectedRange,
                       NSRange(location: editor.flatOffset(ofRoleAt: 4), length: 0),
                       "and the caret is in it, not in the block after the details")
    }

    /// TAB is the same rule's other door — `moveCaretToNextTableCell` calls the same function — so it
    /// had the same defect and takes the same fix. Pinned because the doors have drifted before.
    func test_tabPastTheLastCellOfADetailsTrailingTableAddsAParagraphInsideTheDetails() {
        load([details("d", title: "T", [para("a", "one"), table("t")]), para("after", "z")])
        guard let lastCell = editor.currentRoles.lastIndex(where: { $0.owningTable != nil }) else {
            return XCTFail("no cells — roles \(roles())")
        }
        caret(editor.flatOffset(ofRoleAt: lastCell))
        editor.moveCaretToNextTableCell()
        XCTAssertEqual(roles(), ["detailsTitle@1", "p@1", "cell@1", "cell@1", "p@1", "p@0"],
                       "Tab agrees with Return, got \(roles())")
    }

    /// …and the follow-on a user reaches for next: the paragraph Return just made is the details'
    /// empty last child, so a SECOND Return leaves the block, which is the documented exit.
    func test_aSecondReturnThenLeavesTheDetails() {
        load([details("d", title: "T", [para("a", "one"), table("t")]), para("after", "z")])
        guard let lastCell = editor.currentRoles.lastIndex(where: { $0.owningTable != nil }) else {
            return XCTFail("no cells — roles \(roles())")
        }
        caret(editor.flatOffset(ofRoleAt: lastCell))
        editor.engine.insertText("\n")
        editor.engine.insertText("\n")
        XCTAssertEqual(roles(), ["detailsTitle@1", "p@1", "cell@1", "cell@1", "p@0", "p@0"],
                       "the second Return leaves the details, got \(roles()) strings \(strings())")
    }

    /// The contrast the user reported it against: with nothing after the details this already worked,
    /// which is what localises the defect to the "next role exists" test rather than to the exit.
    func test_returnInTheLastCellOfADetailsTrailingTableWithNothingAfterItStillWorks() {
        load([details("d", title: "T", [para("a", "one"), table("t")])])
        guard let lastCell = editor.currentRoles.lastIndex(where: { $0.owningTable != nil }) else {
            return XCTFail("no cells — roles \(roles())")
        }
        caret(editor.flatOffset(ofRoleAt: lastCell))
        editor.engine.insertText("\n")
        XCTAssertEqual(roles(), ["detailsTitle@1", "p@1", "cell@1", "cell@1", "p@1"],
                       "got \(roles()) strings \(strings())")
    }

    /// The CHROME, not the cells. The device shape: a details whose body is a table, then a table
    /// after the block — the cells were placed correctly by the run offset while the grid was still
    /// drawn from `tableGapAbove` alone, so the second table's box sat on the first's.
    ///
    /// Compared in the ENGINE's coordinates, which is where "drawn over" is a fact about what the
    /// user sees. This case used to assert the two chromes shared one content view and compare their
    /// frames directly; since 2026-09-11 each table is its OWN run (`placedRunStarts`, so that two
    /// tables no longer share one scroll view and one clip), each chrome sits in its own content
    /// view and a raw frame comparison is between two different spaces.
    func test_theChromeOfASecondAdjacentTableIsPlacedWithItsCells() {
        load([details("d", title: "T", [table("inner")]), table("outer")])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        guard let innerChrome = editor.tableChromeViews[BlockID("inner")],
              let outerChrome = editor.tableChromeViews[BlockID("outer")] else {
            return XCTFail("no chrome — roles \(roles())")
        }
        XCTAssertNotEqual(innerChrome.superview, outerChrome.superview, "one run each")
        func inEngine(_ chrome: UIView) -> CGRect {
            chrome.superview.map { $0.convert(chrome.frame, to: editor.engine) } ?? chrome.frame
        }
        let inner = inEngine(innerChrome), outer = inEngine(outerChrome)
        XCTAssertGreaterThanOrEqual(outer.minY, inner.maxY,
                                    "the second grid is drawn over the first: \(outer) vs \(inner)")
    }

    /// …and the chrome agrees with its own cells, which is the invariant the two passes exist to keep.
    func test_eachTablesChromeAgreesWithItsOwnCells() {
        load([details("d", title: "T", [table("inner")]), table("outer")])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        for id in ["inner", "outer"] {
            guard let cell = editor.currentRoles.firstIndex(where: { $0.containerID == BlockID(id) }),
                  let chrome = editor.tableChromeViews[BlockID(id)],
                  let frame = editor.tableFrame(forTableAt: cell) else { return XCTFail("\(id): missing") }
            let content = chrome.superview
            let chromeInEngine = content.map { $0.convert(chrome.frame, to: editor.engine) } ?? chrome.frame
            XCTAssertEqual(chromeInEngine.minY, frame.minY, accuracy: 0.5,
                           "\(id): grid at \(chromeInEngine.minY), cells say \(frame.minY)")
        }
    }

    /// A block CLOSES before what follows it starts. The details' hairline is drawn at the bottom of
    /// its span, and a table after the block was placed at that same y — the closing line drawn
    /// through the grid, which is the "zero spacing" of the K3 report (separator 121.5, table 121.0).
    ///
    /// The missing term is the bottom insets deposited on the previous table's last row. A placed
    /// block's `bottom` EXTENDS THE RUN — that is how a container's closing interior is reserved
    /// around a table — so a run offset counting only the grid places the next table inside space the
    /// previous one's container had already claimed.
    func test_aTableAfterADetailsStartsBelowTheBlocksClosingHairline() {
        load([details("d", title: "T", [table("inner")]), table("outer")])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        guard let separator = editor.containerDecorationViews[BlockID("d")]?.frame,
              let chrome = editor.tableChromeViews[BlockID("outer")],
              let content = chrome.superview else { return XCTFail("missing chrome or separator") }
        let outer = content.convert(chrome.frame, to: editor.engine)
        XCTAssertGreaterThanOrEqual(outer.minY, separator.maxY,
                                    "the block's closing hairline (\(separator)) is drawn on the table (\(outer))")
    }



    /// Legacy's tap-below affordance, which the engine editor stored in
    /// `tapBelowAddsTrailingParagraph` and never read — with a default of `false` where legacy's is
    /// `true`, so the article editor, which never sets it, lost it twice over.
    ///
    /// A tap in the empty space under a trailing details — BELOW the hairline that marks where the
    /// block ends — was placing the caret in the block's body, because that was the nearest position.
    /// Everything typed or inserted next went into the block, which on device read as "add-table did
    /// nothing": the table landed inside rather than after it.
    func test_aTouchBelowATrailingDetailsStartsAParagraphOutsideIt() {
        load([details("d", title: "T", [para("a", "one")])])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        let last = editor.engine.id_frameForBlock(at: UInt(editor.currentRoles.count - 1))
        _ = editor.textInteractionMayBegin(at: CGPoint(x: 20, y: last.maxY + 40))
        XCTAssertEqual(roles(), ["detailsTitle@1", "p@1", "p@0"], "a paragraph OUTSIDE the block")
        XCTAssertEqual(editor.currentRoles.count - 1,
                       editor.roleIndex(atFlatOffset: editor.engineSelectedRange.location),
                       "and the caret is in it")
    }

    /// Idempotent, by legacy's own exception: nothing is appended when the last top-level block is
    /// already an empty paragraph. That is what makes it safe at a predicate UIKit may call for
    /// interactions other than a tap.
    func test_touchingBelowTwiceAppendsOneParagraph() {
        load([details("d", title: "T", [para("a", "one")])])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        for _ in 0..<3 {
            let last = editor.engine.id_frameForBlock(at: UInt(editor.currentRoles.count - 1))
            _ = editor.textInteractionMayBegin(at: CGPoint(x: 20, y: last.maxY + 40))
            editor.setNeedsLayout(); editor.layoutIfNeeded()
        }
        XCTAssertEqual(roles(), ["detailsTitle@1", "p@1", "p@0"])
    }

    /// The chat composer turns it off, and then a touch below just places a caret.
    func test_theAffordanceIsOffWhenTheHostTurnsItOff() {
        load([details("d", title: "T", [para("a", "one")])])
        editor.tapBelowAddsTrailingParagraph = false
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        let last = editor.engine.id_frameForBlock(at: UInt(editor.currentRoles.count - 1))
        _ = editor.textInteractionMayBegin(at: CGPoint(x: 20, y: last.maxY + 40))
        XCTAssertEqual(roles(), ["detailsTitle@1", "p@1"], "nothing appended")
    }

    /// The K3 sequence, exactly as reported.
    func test_theReportedSequence_insertTableAfterEscapingABlock() {
        load([para("start", "")])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        caret(0)

        // 2. a detail block, a title, TAB into the body, a table
        editor.insertDetailsBlock()
        for ch in ["w", "q", "f"] { editor.engine.insertText(ch) }
        editor.moveCaretOutOfDetails()                       // TAB
        editor.insertTable(rows: 2, cols: 2)
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        NSLog("K3SEQ after table: roles=%@ caret=%@", roles().joined(separator: ","), NSStringFromRange(editor.engineSelectedRange))

        // 3. fill each cell, TAB between them
        for cell in 0..<4 {
            editor.engine.insertText("a")
            if cell < 3 { editor.moveCaretToNextTableCell() }
        }
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        // double return out of the last cell
        editor.engine.insertText("\n")
        editor.engine.insertText("\n")
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        let afterEscape = roles()
        let caretAfterEscape = editor.engineSelectedRange
        NSLog("K3SEQ after escape: roles=%@ caret=%@", afterEscape.joined(separator: ","), NSStringFromRange(caretAfterEscape))

        // 4. insert a table ONCE
        let blocksBefore = editor.document.blocks.count
        editor.insertTable(rows: 2, cols: 2)
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        NSLog("K3SEQ after insert: roles=%@ blocks %ld->%ld", roles().joined(separator: ","), blocksBefore, editor.document.blocks.count)

        // Both tables exist, both are drawn, and the second does not overlap the first. This passes
        // in the harness and did NOT reproduce the device report, which is recorded here so the next
        // attempt does not re-run it: the shape is not what makes the table invisible on device.
        let tables = Set(editor.currentRoles.compactMap { $0.owningTable?.id })
        XCTAssertEqual(tables.count, 2, "a second table exists — roles \(roles())")
        XCTAssertEqual(editor.tableChromeViews.count, 2, "and both are drawn")
        let frames = editor.tableChromeViews.values.map { chrome -> CGRect in
            chrome.superview.map { $0.convert(chrome.frame, to: editor.engine) } ?? chrome.frame
        }.sorted { $0.minY < $1.minY }
        XCTAssertGreaterThanOrEqual(frames[1].minY, frames[0].maxY, "and they do not overlap")
    }


    /// K3 report: insert table, Backspace, insert table again. Does NOT reproduce here.
    func test_insertTableBackspaceInsertTableProducesATable() {
        load([details("d", title: "T", [para("a", "one")]), para("p", "")])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        caret(editor.flatOffset(ofRoleAt: 2))
        editor.insertTable(rows: 2, cols: 2)
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        NSLog("K3T after insert1: roles=%@ caret=%@ blocks=%ld", roles().joined(separator: ","),
              NSStringFromRange(editor.engineSelectedRange), editor.document.blocks.count)
        editor.engine.deleteBackward()
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        NSLog("K3T after backspace: roles=%@ caret=%@ blocks=%ld sel.len=%ld", roles().joined(separator: ","),
              NSStringFromRange(editor.engineSelectedRange), editor.document.blocks.count,
              editor.engineSelectedRange.length)
        editor.insertTable(rows: 2, cols: 2)
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        NSLog("K3T after insert2: roles=%@ blocks=%ld", roles().joined(separator: ","), editor.document.blocks.count)
        // ONE table is correct: the Backspace dissolves the freshly inserted empty table back into a
        // paragraph, and the second insert makes a table of it again. Asserting two was my error, not
        // the code's. Recorded because this sequence is the K3 report and it does NOT reproduce here.
        XCTAssertTrue(editor.currentRoles.contains { $0.owningTable != nil },
                      "the second insert produced no table — roles \(roles())")
        // The assertion that was missing: a table in the ROLES is not a table on SCREEN.
        let ids = Set(editor.currentRoles.compactMap { $0.owningTable?.id })
        XCTAssertEqual(Set(editor.tableChromeViews.keys), ids,
                       "grids=\(Set(editor.tableGrids.keys)) chrome=\(Set(editor.tableChromeViews.keys)) roles=\(ids)")
        XCTAssertEqual(editor.engine.tgid_blockIdentifiers.count, editor.currentRoles.count,
                       "engine blocks and roles disagree, so syncTableFrames bails and the grids go stale")
    }

    /// K3 report: Backspace then Return after a detail block, then insert. Does NOT reproduce here.
    func test_backspaceThenReturnAfterABlockThenInsertTable() {
        load([details("d", title: "T", [para("a", "one")]), para("p", "x")])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        caret(editor.flatOffset(ofRoleAt: 2) + 1)
        editor.engine.deleteBackward()
        editor.engine.insertText("\n")
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        NSLog("K3T bs+ret: roles=%@ caret=%@ blocks=%ld", roles().joined(separator: ","),
              NSStringFromRange(editor.engineSelectedRange), editor.document.blocks.count)
        editor.insertTable(rows: 2, cols: 2)
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        NSLog("K3T after insert: roles=%@ blocks=%ld", roles().joined(separator: ","), editor.document.blocks.count)
        XCTAssertTrue(editor.currentRoles.contains { $0.owningTable != nil }, "no table — roles \(roles())")
    }
}
