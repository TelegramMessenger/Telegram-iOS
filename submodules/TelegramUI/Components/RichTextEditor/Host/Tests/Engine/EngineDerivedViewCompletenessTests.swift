import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// Spec §2.2 — what the ROLES say must be drawn, derived from them alone.
///
/// That independence is the whole point (§2.4): each sync pass computes its own `live` set and culls
/// against it, so comparing a pool to that set agrees with the producer by construction, including
/// when the producer is wrong.
@available(iOS 18.4, *)
final class EngineDerivedViewExpectationTests: XCTestCase {
    private func paragraph(_ id: String, within ancestry: [EngineAncestor] = [],
                           list: ListMembership? = nil) -> EngineBlockRole {
        .standalone(.paragraph(ParagraphShape(id: BlockID(id), list: list)), within: ancestry)
    }
    private func detailsShape(_ id: String, expanded: Bool = true,
                              folded: [Block] = []) -> DetailsShape {
        DetailsShape(id: BlockID(id), expanded: expanded, foldedChildren: folded)
    }
    private func titleRole(_ shape: DetailsShape, within ancestry: [EngineAncestor]? = nil) -> EngineBlockRole {
        .secondary(owner: .details(shape), line: shape.titleLineID, kind: .detailsTitle,
                   within: ancestry ?? [.details(shape)])
    }
    private func cellRole(_ table: TableShape, _ cell: String,
                          within ancestry: [EngineAncestor] = []) -> EngineBlockRole {
        .tableCell(table: table, row: 0, column: 0, cell: BlockID(cell), within: ancestry)
    }
    private func emptyTable(_ id: String) -> TableShape {
        TableShape(TableBlock(id: BlockID(id), columns: [ColumnSpec(width: 100)],
                              rows: [Row(id: BlockID("\(id)r"),
                                         cells: [Cell(id: BlockID("\(id)c"),
                                                      blocks: [.paragraph(ParagraphBlock(id: BlockID("\(id)p")))])])]))
    }

    func test_aCellExpectsAGridAndChromeKeyedByItsTable() {
        let table = emptyTable("t")
        let expectation = EngineDerivedViewExpectation(roles: [cellRole(table, "tc")])
        XCTAssertEqual(expectation.tables, [BlockID("t")])
        XCTAssertTrue(expectation.decorations.isEmpty, "a table is drawn by its chrome, not a band")
    }

    func test_aDetailsTitleExpectsAChevronAndASeparator() {
        let shape = detailsShape("d")
        let expectation = EngineDerivedViewExpectation(roles: [titleRole(shape)])
        XCTAssertEqual(expectation.detailsChevrons, [BlockID("d")])
        XCTAssertEqual(expectation.decorations, [BlockID("d")])
    }

    /// §2.3: a FOLDED details expects what its one role implies and nothing for a body that is not on
    /// the engine's axis.
    func test_aFoldedDetailsExpectsNothingForItsHiddenBody() {
        let shape = detailsShape("d", expanded: false,
                                 folded: [.paragraph(ParagraphBlock(id: BlockID("hidden")))])
        let expectation = EngineDerivedViewExpectation(roles: [titleRole(shape)])
        XCTAssertEqual(expectation.detailsChevrons, [BlockID("d")])
        XCTAssertTrue(expectation.listMarkers.isEmpty)
    }

    /// §2.2's first conditional: a list item inside a CELL is deliberately unmarked, matching
    /// legacy's `stampListMarkers`.
    func test_aListItemInACellExpectsNoMarker() {
        let table = emptyTable("t")
        let expectation = EngineDerivedViewExpectation(roles: [cellRole(table, "tc")])
        XCTAssertTrue(expectation.listMarkers.isEmpty)
    }

    func test_aTopLevelListItemExpectsAMarker() {
        let listed = paragraph("p", list: ListMembership(marker: .bullet, level: 0))
        XCTAssertEqual(EngineDerivedViewExpectation(roles: [listed]).listMarkers, [BlockID("p")])
    }

    func test_everyAncestorExpectsADecoration() {
        let quote = QuoteShape(BlockQuote(id: BlockID("q"), children: []))
        let shape = detailsShape("d")
        let role = paragraph("a", within: [.blockQuote(quote), .details(shape)])
        XCTAssertEqual(EngineDerivedViewExpectation(roles: [role]).decorations,
                       [BlockID("q"), BlockID("d")])
    }

    /// Media is deliberately outside this invariant — see the type's doc comment. Pinned so the
    /// exclusion is a decision someone can read, not an omission someone repeats.
    func test_aMediaAtomIsNotExpectedToOwnAnything() {
        let media = MediaShape(MediaBlock(id: BlockID("m"), mediaID: "x", kind: .image,
                                          naturalSize: Size2D(width: 10, height: 10), caption: []))
        let role = EngineBlockRole.standalone(.media(media), within: [])
        let expectation = EngineDerivedViewExpectation(roles: [role])
        XCTAssertTrue(expectation.decorations.isEmpty)
        XCTAssertTrue(expectation.tables.isEmpty)
        XCTAssertTrue(expectation.listMarkers.isEmpty)
    }
}

/// Spec §2.5–2.7 — the invariant itself, and the defect that motivated it.
@available(iOS 18.4, *)
final class EngineDerivedViewCompletenessTests: XCTestCase {
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
    private func table(_ id: String) -> Block {
        .table(TableBlock(id: BlockID(id), columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
                          rows: [Row(id: BlockID("\(id)r"),
                                     cells: [Cell(id: BlockID("\(id)c0"), blocks: [para("\(id)p0", "")]),
                                             Cell(id: BlockID("\(id)c1"), blocks: [para("\(id)p1", "")])])]))
    }
    private func details(_ id: String, title: String, _ children: [Block]) -> Block {
        .details(DetailsBlock(id: BlockID(id), title: [TextRun(text: title)], children: children, expanded: true))
    }
    private func load(_ blocks: [Block]) {
        editor.document = Document(blocks: blocks)
        editor.setNeedsLayout(); editor.layoutIfNeeded()
    }

    /// §2.7 case 1, the defect this whole instrument exists for. `syncTableFrames` returns early when
    /// the engine's block count disagrees with the roles', leaving `tableGrids` STALE, and
    /// `syncTableChrome` then skips every table missing from it — a table in the document, in the
    /// roles, and drawn nowhere, with nothing reporting it.
    func test_aTableWithNoGridIsReported() {
        load([table("t")])
        XCTAssertEqual(editor.derivedViewShortfall(), [], "precondition: complete after a layout")
        editor.tableGrids.removeAll()
        let shortfall = editor.derivedViewShortfall()
        XCTAssertTrue(shortfall.contains { $0.contains("grid") },
                      "a table with no grid must be reported — got \(shortfall)")
    }

    func test_aCompleteDocumentHasNoShortfall() {
        load([details("d", title: "T", [para("a", "one"), table("t")]),
              .blockQuote(BlockQuote(id: BlockID("q"), children: [para("b", "two")]))])
        XCTAssertEqual(editor.derivedViewShortfall(), [], "a laid-out document is complete")
    }

    /// §2.3: the check is on POOL KEYS, never on visibility — a culled host is hidden, not removed,
    /// and a hidden view is not a missing one.
    func test_aHiddenViewIsNotAMissingOne() {
        load([details("d", title: "T", [para("a", "one")])])
        XCTAssertFalse(editor.detailsChevronViews.isEmpty, "precondition: a chevron exists")
        for view in editor.detailsChevronViews.values { view.isHidden = true }
        XCTAssertEqual(editor.derivedViewShortfall(), [], "hidden is not missing")
    }

    /// The WIRING, not the rule. A check nothing calls is the defect this instrument exists to catch,
    /// and it is the mistake the details chevron made: a hit-test rule, a passing test for it, and no
    /// caller anywhere in the app.
    func test_theCheckRunsOnEveryLayout() {
        load([para("p", "x")])
        let before = editor.derivedViewVerificationCount
        XCTAssertGreaterThan(before, 0, "the initial layout ran it")
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        XCTAssertGreaterThan(editor.derivedViewVerificationCount, before, "and so does the next one")
    }

    /// A media atom draws nothing here and that is not a shortfall: its view is host-supplied and
    /// can legitimately be absent for three reasons the roles cannot see.
    func test_aMediaAtomWithNoHostProviderIsNotAShortfall() {
        load([.media(MediaBlock(id: BlockID("m"), mediaID: "x", kind: .image,
                                naturalSize: Size2D(width: 40, height: 40), caption: []))])
        XCTAssertEqual(editor.derivedViewShortfall(), [], "media is outside this invariant")
    }

    /// K3: insert a table, delete it with Backspace, and the action bar stops taking touches AND the
    /// editor stops scrolling. Both dying together cannot be a z-order problem — the bar is a sibling
    /// of the editor — so the suspect is an interactive view that OUTLIVED its role.
    ///
    /// This is the reverse of the completeness invariant, which the spec named as out of scope.
    /// It PASSES: the host's own pools reap correctly, so whatever survives is engine-owned (the
    /// placed run's scroll view, which the engine creates and this cannot see) or is not a view at
    /// all but a wedged gesture recogniser — which would explain both symptoms at once where a
    /// covering view cannot, since the action bar is a SIBLING of the editor and nothing inside it
    /// can cover the bar. Kept as a permanent narrowing of the parked investigation.
    func test_deletingATableLeavesNoOrphanedViews() {
        load([para("p", "")])
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        editor.insertTable(rows: 2, cols: 2)
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        XCTAssertFalse(editor.tableChromeViews.isEmpty, "precondition: a table is drawn")
        let engineSubviewsWithTable = editor.engine.subviews.count

        // Backspace in the first cell of a wholly empty table dissolves it into a paragraph.
        editor.engine.deleteBackward()
        editor.setNeedsLayout(); editor.layoutIfNeeded()

        XCTAssertFalse(editor.currentRoles.contains { $0.owningTable != nil },
                       "precondition: the table is gone from the roles — \(roles())")
        XCTAssertEqual(editor.tableChromeViews, [:], "chrome outlived its table")
        XCTAssertEqual(editor.tableGrids, [:], "a grid outlived its table")
        XCTAssertLessThanOrEqual(editor.engine.subviews.count, engineSubviewsWithTable,
                                 "the engine gained subviews by DELETING a table")
        let interactive = editor.engine.subviews.filter {
            $0.isUserInteractionEnabled && !$0.isHidden && $0.frame.width > 100 && $0.frame.height > 100
        }
        XCTAssertEqual(interactive.map { "\(type(of: $0))\(NSCoder.string(for: $0.frame))" }, [],
                       "a large interactive view survived the table it belonged to")
    }

    private func roles() -> [String] {
        editor.currentRoles.map { $0.owningTable != nil ? "cell" : "p" }
    }
}
