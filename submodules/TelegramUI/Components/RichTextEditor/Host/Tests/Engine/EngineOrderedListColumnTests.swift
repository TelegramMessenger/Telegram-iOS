import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// **An ordered list is ONE column of markers and ONE column of text**, however wide its widest
/// number is — which is what the V2 renderer draws and what the editor must therefore draw.
///
/// V2 measures every marker in a list, takes `maxIndexWidth`, RIGHT-aligns each marker to that
/// shared column and starts every item's text at `horizontalInset + maxIndexWidth + indexSpacing`
/// (`InstantPageV2Layout.swift:3390,3428,3463,3489`). So a list that crosses ten has its periods in
/// one column and its text in another, and nothing moves as it is renumbered past nine.
///
/// The editor did neither. The marker was LEFT-aligned in the gutter and the extra width of a wide
/// ordinal was pushed onto that item's TEXT alone, so a 1…12 list measured (K3, 2026-09-17):
///
/// | item | text x | marker right edge |
/// | --- | --- | --- |
/// | 1 | 5.0 | 16.65 |
/// | 2 | 5.0 | 19.19 |
/// | 7 | 5.0 | 17.04 |
/// | 10 | **15.28** | 26.68 |
/// | 12 | **15.28** | 26.65 |
///
/// — the text column stepping right by 10.28 between items 9 and 10, and no two periods aligned
/// anywhere. The per-item inset was the 2026-09-11 fix for a worse defect (`10.` drawn straight
/// through its own text, which read as `10F`); it removed the overlap and left the raggedness.
///
/// **Taking the run's MAXIMUM rather than each item's own** is the whole change: the reservation is
/// still counted in characters rather than measured off the rendered glyphs — so `1.` and `7.`
/// cannot indent differently and a renumber cannot shift the text — but it is now counted once for
/// the list instead of once per item.
@available(iOS 18.4, *)
final class EngineOrderedListColumnTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 900))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    @discardableResult
    private func showOrderedList(count: Int, level: Int = 0) -> [Int] {
        var blocks: [Block] = []
        for n in 1...count {
            var paragraph = ParagraphBlock(id: BlockID("p\(n)"), runs: [TextRun(text: "Item")])
            paragraph.list = ListMembership(marker: .ordered, level: level)
            blocks.append(.paragraph(paragraph))
        }
        editor.document = Document(blocks: blocks)
        window.layoutIfNeeded()
        return Array(0..<count)
    }

    private func textColumns(_ indices: [Int]) -> [CGFloat] {
        indices.map { editor.engine.id_frameForBlock(at: UInt($0)).minX }
    }

    private func markerFrames(_ indices: [Int]) -> [CGRect] {
        indices.compactMap { index in
            guard let paragraph = editor.currentRoles[index].shape.paragraph,
                  let view = editor.listMarkerViews[paragraph.id] else { return nil }
            return view.frame
        }
    }

    /// One text column, across the nine-to-ten boundary.
    func test_everyItemInAnOrderedListSharesOneTextColumn() {
        let indices = showOrderedList(count: 12)
        let columns = textColumns(indices)
        XCTAssertEqual(columns.count, 12)
        for (n, x) in columns.enumerated() {
            XCTAssertEqual(x, columns[0], accuracy: 0.001,
                           "item \(n + 1) starts its text at \(x), item 1 at \(columns[0])")
        }
    }

    /// One marker column, right-aligned — so the periods line up, as they do in the bubble.
    func test_everyOrdinalMarkerIsRightAlignedToOneColumnEdge() {
        let indices = showOrderedList(count: 12)
        let frames = markerFrames(indices)
        XCTAssertEqual(frames.count, 12, "a marker view per item")
        for (n, frame) in frames.enumerated() {
            XCTAssertEqual(frame.maxX, frames[0].maxX, accuracy: 0.001,
                           "item \(n + 1)'s marker ends at \(frame.maxX), item 1's at \(frames[0].maxX)")
        }
    }

    /// **No marker may reach its own text.** The column is only useful if it still clears the text
    /// it labels — asserted against the block's own leading edge, which is where the engine starts
    /// laying the item out once the reservation has moved it.
    func test_noMarkerReachesTheTextItLabels() {
        let indices = showOrderedList(count: 12)
        for (n, frame) in markerFrames(indices).enumerated() {
            // The TEXT's origin, not the block's leading edge: the gutter is `firstLineHeadIndent`
            // INSIDE the frame, so the block starts where the marker does and comparing against it
            // asserts nothing. Read off the string the engine laid out.
            let block = editor.engine.id_frameForBlock(at: UInt(indices[n]))
            let stored = editor.engine.attributedBlocks[indices[n]]
            let style = stored.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
            let textOrigin = block.minX + (style?.firstLineHeadIndent ?? 0)
            XCTAssertLessThanOrEqual(frame.maxX, textOrigin + 0.001,
                                     "item \(n + 1)'s marker runs to \(frame.maxX), past its text "
                                     + "origin \(textOrigin)")
        }
    }

    /// **A list that never reaches ten must not move at all** — the reservation is zero there, which
    /// is what keeps every existing document exactly where it is.
    func test_aListThatNeverReachesTenReservesNothingExtra() {
        showOrderedList(count: 9)
        XCTAssertTrue(editor.orderedListMarkerInsets().isEmpty,
                      "a single-digit list reserved \(editor.orderedListMarkerInsets())")
    }

    /// The run ends at a non-item, so a second list below a paragraph gets its own column rather
    /// than inheriting the first one's width.
    func test_aSeparateListBelowAParagraphGetsItsOwnColumn() {
        var blocks: [Block] = []
        for n in 1...12 {
            var paragraph = ParagraphBlock(id: BlockID("a\(n)"), runs: [TextRun(text: "Item")])
            paragraph.list = ListMembership(marker: .ordered, level: 0)
            blocks.append(.paragraph(paragraph))
        }
        blocks.append(.paragraph(ParagraphBlock(id: BlockID("gap"), runs: [TextRun(text: "Between")])))
        for n in 1...3 {
            var paragraph = ParagraphBlock(id: BlockID("b\(n)"), runs: [TextRun(text: "Item")])
            paragraph.list = ListMembership(marker: .ordered, level: 0)
            blocks.append(.paragraph(paragraph))
        }
        editor.document = Document(blocks: blocks)
        window.layoutIfNeeded()

        let wide = editor.engine.id_frameForBlock(at: UInt(0)).minX
        let narrow = editor.engine.id_frameForBlock(at: UInt(13)).minX
        XCTAssertLessThan(narrow, wide - 1,
                          "the second list (1…3) sits at \(narrow), the first (1…12) at \(wide) — it "
                          + "inherited a column it has no numbers for")
    }
}
