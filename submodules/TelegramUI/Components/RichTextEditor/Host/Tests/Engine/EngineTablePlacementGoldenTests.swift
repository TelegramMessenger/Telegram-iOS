import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// GOLDEN GEOMETRY. Every cell frame, chrome frame, placement offset and non-zero block inset the
/// editor produces for six table-bearing documents, recorded from the code as it stood before the
/// placement refactor and asserted unchanged after it.
///
/// The refactor moves where the space above a placed table is DECIDED. That is only safe if it
/// changes no number, and "changes no number" is a claim that needs an instrument which could show
/// otherwise — the existing geometry suites assert relationships (a is left of b, c is below a),
/// which several wrong absolute layouts also satisfy.
///
/// **Fixture 6 was recorded WRONG on purpose, and then it earned its keep.** A details whose body
/// begins with a table used to place that table at `dy = 16.000` — exactly what fixture 1's bare
/// TOP-LEVEL table gets, because `tableGapAbove` charged a top-level RHYTHM gap between the details'
/// title and its first body child. That is not the quantity that belongs between a container's own
/// line and its first child; `DetailsShape.titleBodyGap` (14) is, and a paragraph in the same
/// position already got it.
///
/// The placement refactor could not reproduce the 16 without re-inventing that bug inside the new
/// code, so it landed the measured-correct **14** and this fixture's golden moved with it. The other
/// five are byte-identical. That asymmetry — five unchanged, one changed for a reason written down —
/// is the whole value of having recorded the corpus before touching anything.
///
/// **Every fixture with TWO tables moved its second table's two RUN-RELATIVE lines on 2026-09-11**,
/// and not one absolute cell frame — which is the whole point. Each table is now its own run
/// (`placedRunStarts`), so a second table's `dy` and its grid chrome are measured from its own
/// anchor rather than from the shared run's, and the engine's extent supplies the difference. Two
/// tables sharing one run meant one scroll view and one clip for both; the cells being
/// byte-identical either way is what says the split moved nothing on screen.
///
/// **The NESTED fixtures moved twice on 2026-09-11, and the top-level two moved neither time** —
/// the same asymmetry the paragraph above describes, and the same evidence.
///
/// First, a quoted table reserved a `gripGutter` (15) on each side so its grips had room: at the
/// top level the text inset is the gutter the row grips live in and the document's own rhythm is the
/// band the column grip hangs in, and a container's interior has neither, so a quoted table had its
/// grips clipped away and its column grip drawn over the quote's author line (K3). That read as a
/// table pushed in from everything around it (user report, same day) and was reverted: the room was
/// already there — the grips hang into the quote's OWN indent, and what opens is the chrome's
/// window (`tableClipX`), which no golden here records. Only the last row's extra `gripHeight` (17)
/// of bottom inset survives from that round.
///
/// Then a quote gained the TRAILING inset it had never applied (legacy's `BlockQuoteBox`:
/// `inner = width - leadingInset - trailingInset`), so a nested table is narrowed by
/// `quoteTrailingInset` (22) as well — 11 per column here — and stops where the quote's own
/// paragraphs stop instead of running out to the column edge. Its `indent` and every `dy` are
/// untouched, which is what says the change is a width and not a placement.
/// **All six were re-read on 2026-09-15 after the trailing line-box overhang was taken out of the
/// rhythm** (package CLAUDE.md, "A block's FRAME is a line box"). Every stacked block had been
/// standing `pitch - ceil(ascender + |descender|)` too tall, so everything below a paragraph moved
/// UP by that much: two points under a 17pt body line, and — golden 4 — ONE point under a quote's
/// 15pt child, which is the per-role read proving itself. Widths, cell heights and insets that sit
/// above a block are untouched; what moved is cell Y, each table's run-relative `dy`, and the
/// trailing `bottom` insets that now stop at the text rather than at the box.
///
/// **Four fixtures had moved earlier the same day, by one point per BODY LINE above the table, and
/// nothing else moved then either.** Body line spacing was raised a point (`lineSpacingFactor` 0.9 → 0.95 in the
/// shared chat-message table, pitch 22 → 23), so every absolute cell frame below a top-level
/// paragraph slides down by one point per line: golden 1 and 3 by 1, golden 5 by 2 (two body lines),
/// golden 6 by 1. Goldens 2 and 4 did not move — 2 opens with a table, and 4's only paragraph above
/// the table is INSIDE a quote, where the text is 15pt and the pitch is 19 at either factor. Every
/// width, every cell height, every run-relative `chrome` and `placement`, and every inset is
/// byte-identical across all six, which is what says a line-spacing change is what happened and not
/// a placement change wearing its clothes.
///
@available(iOS 18.4, *)
final class EngineTablePlacementGoldenTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor)
        window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    // MARK: - Fixtures

    private func cell(_ id: String, _ text: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID("\(id)p"), runs: [TextRun(text: text)]))])
    }
    private func table(_ id: String) -> TableBlock {
        TableBlock(id: BlockID(id), columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
                   rows: [Row(id: BlockID("\(id)r0"), cells: [cell("\(id)a", "a"), cell("\(id)b", "b")]),
                          Row(id: BlockID("\(id)r1"), cells: [cell("\(id)c", "c"), cell("\(id)d", "d")])])
    }
    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    private func quote(_ id: String, _ children: [Block]) -> Block {
        .blockQuote(BlockQuote(id: BlockID(id), children: children, author: []))
    }
    private func details(_ id: String, title: String, _ children: [Block]) -> Block {
        .details(DetailsBlock(id: BlockID(id), title: [TextRun(text: title)], children: children, expanded: true))
    }

    // MARK: - The snapshot

    /// Everything the placement path decides, as one comparable value. Frames are formatted to three
    /// decimals: the geometry is deterministic for a fixed input, so exact string equality is right
    /// and an `accuracy:` tolerance would hide exactly the small drifts this exists to catch.
    private func snapshot() -> String {
        editor.layoutIfNeeded()
        var lines: [String] = []
        for index in editor.currentRoles.indices where editor.currentRoles[index].owningTable != nil {
            lines.append(String(format: "cell[%d] %@", index, fmt(editor.engine.id_frameForBlock(at: UInt(index)))))
        }
        for (id, view) in editor.tableChromeViews.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            lines.append("chrome[\(id.rawValue)] \(fmt(view.frame))")
        }
        for (id, placement) in editor.tablePlacements.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            lines.append(String(format: "placement[%@] dy=%.3f indent=%.3f", id.rawValue, placement.dy, placement.indent))
        }
        let insets = EngineBlockSpacing.blockLayout(for: editor.currentRoles,
                                                    styleSheet: editor.bridge.styleSheet,
                                                    quoteStyle: editor.deferredConfiguration.quoteStyle,
                                                    pullQuoteStyle: editor.deferredConfiguration.pullQuoteStyle,
                                                    grids: editor.tableGrids,
                                                    lineAttributes: editor.spacingLineAttributes()).insets
        for (index, inset) in insets.enumerated() where inset != .zero {
            lines.append(String(format: "inset[%d] t=%.3f l=%.3f b=%.3f r=%.3f",
                                index, inset.top, inset.left, inset.bottom, inset.right))
        }
        return lines.joined(separator: "\n")
    }

    private func fmt(_ rect: CGRect) -> String {
        String(format: "{%.3f, %.3f, %.3f, %.3f}", rect.origin.x, rect.origin.y, rect.width, rect.height)
    }

    private func assertGolden(_ blocks: [Block], _ expected: String,
                              file: StaticString = #filePath, line: UInt = #line) {
        editor.document = Document(blocks: blocks)
        XCTAssertEqual(snapshot(), expected, file: file, line: line)
    }

    // **2026-09-17, pixel alignment.** Five of the six moved, and the diff is what says the change
    // was confined: in every one, exactly TWO `inset[...]` lines moved and their top+bottom sums are
    // unchanged to the third decimal, while every `cell[...]`, `chrome[...]` and `placement[...]`
    // value is byte-identical. That is the baseline drop snapping to the device pixel grid
    // (0.713 -> 0.667 at body), applied as the net-zero pair it has always been. Golden 2 — two
    // adjacent tables with no stacked text between them — did not move at all, which is the control:
    // nothing text-derived, nothing to snap.

    // MARK: - The corpus

    func test_golden1_aBareTopLevelTable() {
        assertGolden([para("p0", "before"), .table(table("t")), para("p1", "after")], """
        cell[1] {12.000, 66.000, 140.500, 32.000}
        cell[2] {166.500, 66.000, 140.500, 32.000}
        cell[3] {12.000, 113.000, 140.500, 32.000}
        cell[4] {166.500, 113.000, 140.500, 32.000}
        chrome[t] {0.000, 16.000, 310.000, 95.000}
        placement[t] dy=16.000 indent=0.000
        inset[0] t=5.000 l=0.000 b=1.000 r=0.000
        inset[1] t=14.000 l=6.000 b=0.000 r=7.000
        inset[2] t=14.000 l=6.000 b=0.000 r=8.000
        inset[3] t=14.000 l=6.000 b=1.000 r=7.000
        inset[4] t=14.000 l=6.000 b=1.000 r=8.000
        inset[5] t=15.000 l=0.000 b=7.000 r=0.000
        """)
    }

    func test_golden2_twoAdjacentTopLevelTables() {
        assertGolden([.table(table("t")), .table(table("u"))], """
        cell[0] {12.000, 34.000, 140.500, 32.000}
        cell[1] {166.500, 34.000, 140.500, 32.000}
        cell[2] {12.000, 81.000, 140.500, 32.000}
        cell[3] {166.500, 81.000, 140.500, 32.000}
        cell[4] {12.000, 145.000, 140.500, 32.000}
        cell[5] {166.500, 145.000, 140.500, 32.000}
        cell[6] {12.000, 192.000, 140.500, 32.000}
        cell[7] {166.500, 192.000, 140.500, 32.000}
        chrome[t] {0.000, 11.000, 310.000, 95.000}
        chrome[u] {0.000, 16.000, 310.000, 95.000}
        placement[t] dy=11.000 indent=0.000
        placement[u] dy=16.000 indent=0.000
        inset[0] t=14.000 l=6.000 b=0.000 r=7.000
        inset[1] t=14.000 l=6.000 b=0.000 r=8.000
        inset[2] t=14.000 l=6.000 b=1.000 r=7.000
        inset[3] t=14.000 l=6.000 b=1.000 r=8.000
        inset[4] t=14.000 l=6.000 b=0.000 r=7.000
        inset[5] t=14.000 l=6.000 b=0.000 r=8.000
        inset[6] t=14.000 l=6.000 b=9.000 r=7.000
        inset[7] t=14.000 l=6.000 b=9.000 r=8.000
        """)
    }

    func test_golden3_aTableThatOpensAQuote() {
        assertGolden([para("p0", "before"), quote("q", [.table(table("t"))])], """
        cell[1] {28.000, 74.000, 121.500, 32.000}
        cell[2] {163.500, 74.000, 121.500, 32.000}
        cell[3] {28.000, 121.000, 121.500, 32.000}
        cell[4] {163.500, 121.000, 121.500, 32.000}
        chrome[t] {16.000, 24.000, 272.000, 95.000}
        placement[t] dy=24.000 indent=16.000
        inset[0] t=5.000 l=0.000 b=1.000 r=0.000
        inset[1] t=14.000 l=6.000 b=0.000 r=7.000
        inset[2] t=14.000 l=6.000 b=0.000 r=8.000
        inset[3] t=14.000 l=6.000 b=18.000 r=7.000
        inset[4] t=14.000 l=6.000 b=18.000 r=8.000
        inset[5] t=1.000 l=0.000 b=12.000 r=0.000
        """)
    }

    func test_golden4_aQuotedTableWithASiblingAbove() {
        assertGolden([quote("q", [para("a", "one"), .table(table("t"))])], """
        cell[1] {28.000, 69.000, 121.500, 32.000}
        cell[2] {163.500, 69.000, 121.500, 32.000}
        cell[3] {28.000, 116.000, 121.500, 32.000}
        cell[4] {163.500, 116.000, 121.500, 32.000}
        chrome[t] {16.000, 16.000, 272.000, 95.000}
        placement[t] dy=16.000 indent=16.000
        inset[0] t=12.000 l=0.000 b=0.000 r=0.000
        inset[1] t=14.000 l=6.000 b=0.000 r=7.000
        inset[2] t=14.000 l=6.000 b=0.000 r=8.000
        inset[3] t=14.000 l=6.000 b=18.000 r=7.000
        inset[4] t=14.000 l=6.000 b=18.000 r=8.000
        inset[5] t=1.000 l=0.000 b=12.000 r=0.000
        """)
    }

    func test_golden5_aDetailsWhoseBodyEndsWithATableThenAnotherTable() {
        assertGolden([details("d", title: "Notes", [para("a", "one"), .table(table("t"))]),
                      .table(table("u"))], """
        cell[2] {12.000, 105.000, 140.500, 32.000}
        cell[3] {166.500, 105.000, 140.500, 32.000}
        cell[4] {12.000, 152.000, 140.500, 32.000}
        cell[5] {166.500, 152.000, 140.500, 32.000}
        cell[6] {12.000, 249.000, 140.500, 32.000}
        cell[7] {166.500, 249.000, 140.500, 32.000}
        cell[8] {12.000, 296.000, 140.500, 32.000}
        cell[9] {166.500, 296.000, 140.500, 32.000}
        chrome[t] {0.000, 16.000, 310.000, 95.000}
        chrome[u] {0.000, 16.000, 310.000, 95.000}
        placement[t] dy=16.000 indent=0.000
        placement[u] dy=16.000 indent=0.000
        inset[0] t=9.000 l=0.000 b=1.000 r=0.000
        inset[1] t=13.000 l=0.000 b=1.000 r=0.000
        inset[2] t=14.000 l=6.000 b=0.000 r=7.000
        inset[3] t=14.000 l=6.000 b=0.000 r=8.000
        inset[4] t=14.000 l=6.000 b=34.000 r=7.000
        inset[5] t=14.000 l=6.000 b=34.000 r=8.000
        inset[6] t=14.000 l=6.000 b=0.000 r=7.000
        inset[7] t=14.000 l=6.000 b=0.000 r=8.000
        inset[8] t=14.000 l=6.000 b=9.000 r=7.000
        inset[9] t=14.000 l=6.000 b=9.000 r=8.000
        """)
    }

    /// The shape that was buggy — see this file's header. Its golden now records the FIX: 14, the
    /// same `titleBodyGap` a paragraph in this position gets, where it used to record a spurious 16.
    func test_golden6_aDetailsWhoseBodyBeginsWithATable() {
        assertGolden([details("d", title: "Notes", [.table(table("t")), para("a", "one")])], """
        cell[1] {12.000, 68.000, 140.500, 32.000}
        cell[2] {166.500, 68.000, 140.500, 32.000}
        cell[3] {12.000, 115.000, 140.500, 32.000}
        cell[4] {166.500, 115.000, 140.500, 32.000}
        chrome[t] {0.000, 14.000, 310.000, 95.000}
        placement[t] dy=14.000 indent=0.000
        inset[0] t=9.000 l=0.000 b=1.000 r=0.000
        inset[1] t=14.000 l=6.000 b=0.000 r=7.000
        inset[2] t=14.000 l=6.000 b=0.000 r=8.000
        inset[3] t=14.000 l=6.000 b=18.000 r=7.000
        inset[4] t=14.000 l=6.000 b=18.000 r=8.000
        inset[5] t=15.000 l=0.000 b=21.000 r=0.000
        """)
    }

    // MARK: - The cells and the chrome are placed from ONE value

    /// Two derivations of one number is what drew a grid on top of the table above it once adjacent
    /// tables gained a run offset.
    func test_theChromeAndTheCellsArePlacedFromTheSameValue() {
        editor.document = Document(blocks: [.table(table("t")), .table(table("u"))])
        editor.layoutIfNeeded()
        for id in [BlockID("t"), BlockID("u")] {
            guard let placement = editor.tablePlacements[id],
                  let chrome = editor.tableChromeViews[id] else { return XCTFail("no placement for \(id.rawValue)") }
            XCTAssertEqual(chrome.frame.minY, placement.dy, accuracy: 0.001, "\(id.rawValue) chrome sits at its placement")
            XCTAssertEqual(chrome.frame.minX, placement.indent, accuracy: 0.001)
        }
        // The two tables must not overlap — and since each is now its own RUN, `dy` is relative to
        // its own anchor and cannot answer that. The engine's own frames can: they are absolute, and
        // they are what the user sees.
        //
        // `>=` against the first table's BOTTOM, not `>` against its top: an overlap satisfies a bare
        // ordering check, which is how two adjacent tables overlapped by 29pt while tests watched.
        guard let firstFrame = editor.tableFrame(forTableAt: 0),
              let secondIndex = editor.currentRoles.firstIndex(where: { $0.owningTable?.id == BlockID("u") }),
              let secondFrame = editor.tableFrame(forTableAt: secondIndex) else {
            return XCTFail("missing table frames")
        }
        XCTAssertGreaterThanOrEqual(secondFrame.minY, firstFrame.maxY,
                                    "the second table starts at or below the first's bottom, never overlapping it")
    }
}
