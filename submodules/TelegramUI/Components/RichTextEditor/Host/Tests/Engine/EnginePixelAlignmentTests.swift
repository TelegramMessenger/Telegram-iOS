import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// **Every block origin, and so every line boundary, sits on a WHOLE POINT — and consecutive
/// selection rects therefore ABUT.**
///
/// The vertical rhythm is integral by construction — `pitch = L + S` with both terms floored, the
/// `.safe` box is `ceil(fontBox)`, and `lineSpacing = pitch - box` — so block HEIGHTS were already
/// whole numbers. What was not was the block's own ORIGIN: `applyV2BaselineShift` lifts each block's
/// text onto V2's baseline by `v2BaselineDrop`, which is the `ceil(fontBox) - fontBox` rounding
/// remainder and therefore an arbitrary fraction. Measured at 3x before this:
///
/// | | drop | block origin y |
/// | --- | --- | --- |
/// | heading1 | 0.7461 | 14.2539 |
/// | body | 0.7129 | 53.2871 |
///
/// A block's interior line boundaries are `origin + k * pitch`, so every one of them inherited the
/// fraction, and the selection rects drawn from them landed off-pixel — the first and last rect of a
/// selection looked fine only because they are extended to the slot edges, which are integral.
///
/// **Points, not device pixels.** Snapping to the device pixel grid (1/3pt at 3x) was the first
/// attempt and it did not close the report: the selection drawing integralises to whole POINTS, so a
/// wrapped paragraph's first two line rects came back `[12.0, 34.0]` and `[34.3333, 57.3333]` — the
/// first ending on a whole point while the second began a third of a point later. On screen that
/// unfilled row is a white seam between line one and line two, which is what was reported, twice.
/// `test_consecutiveSelectionRectsAbut` is the assertion that was missing: the edges were all ON the
/// grid the whole time, and no test asked whether they MET.
@available(iOS 18.4, *)
final class EnginePixelAlignmentTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 1000))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 1400))
        window.addSubview(editor); window.makeKeyAndVisible()
        editor.engine.becomeFirstResponder()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private var scale: CGFloat { UIScreen.main.scale }
    private func isOnWholePoint(_ value: CGFloat) -> Bool { abs(value - value.rounded()) < 0.0001 }
    private func para(_ id: String, _ text: String, style: ParagraphStyleName = .body) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), style: style, runs: [TextRun(text: text)]))
    }
    /// Every paragraph style a top-level block can hold, plus the container kinds, so a fraction
    /// hiding in one style's metrics cannot pass.
    private func richDocument() -> Document {
        Document(blocks: [
            para("h1", "Heading one", style: .heading1),
            para("h2", "Heading two", style: .heading2),
            para("h3", "Heading three", style: .heading3),
            para("h4", "Heading four", style: .heading4),
            para("h5", "Heading five", style: .heading5),
            para("h6", "Heading six", style: .heading6),
            para("p0", "A body paragraph long enough to wrap onto a second line inside this narrow field"),
            .blockQuote(BlockQuote(id: BlockID("q"), children: [para("qp", "Quoted body text")])),
            .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x = 1")])),
            // Placed and atom roles too: a table's cells are laid out through `placedReservations`
            // rather than through the insets, and a medium is an attachment line whose box TextKit
            // inflates — neither would be covered by a text-only fixture.
            .table(TableBlock.empty(rows: 2, columns: 2)),
            .media(MediaBlock(id: BlockID("m"), items: [MediaItem(mediaID: "m1", kind: .image,
                                                                  naturalSize: Size2D(width: 1000, height: 500))],
                              caption: [TextRun(text: "A caption")])),
            para("p1", "Trailing body paragraph"),
        ])
    }

    /// `richDocument` minus the table and the medium — everything whose rects are one per LINE.
    private func textDocument() -> Document {
        Document(blocks: richDocument().blocks.filter { block in
            switch block {
            case .table, .media: return false
            default: return true
            }
        })
    }

    func test_everyBlockOriginIsOnAWholePoint() {
        editor.document = richDocument()
        window.layoutIfNeeded()

        var offGrid: [String] = []
        for index in editor.currentRoles.indices {
            let frame = editor.engine.id_frameForBlock(at: UInt(index))
            if !isOnWholePoint(frame.origin.y) {
                offGrid.append(String(format: "role %d y=%.4f", index, frame.origin.y))
            }
        }
        XCTAssertEqual(offGrid, [], "a block origin off a whole point puts every line inside it off it too")
    }

    func test_everyBlockHeightIsOnAWholePoint() {
        editor.document = richDocument()
        window.layoutIfNeeded()

        var offGrid: [String] = []
        for index in editor.currentRoles.indices {
            let frame = editor.engine.id_frameForBlock(at: UInt(index))
            if !isOnWholePoint(frame.size.height) {
                offGrid.append(String(format: "role %d h=%.4f", index, frame.size.height))
            }
        }
        XCTAssertEqual(offGrid, [], "heights were already integral; this guards them staying so")
    }

    /// The user-visible half: the selection wash.
    func test_everySelectionRectEdgeIsOnAWholePoint() {
        editor.document = richDocument()
        window.layoutIfNeeded()
        let total = editor.currentRoles.indices.reduce(0) { $0 + editor.flatLength(ofRoleAt: $1) + 1 } - 1
        editor.engineSelectedRange = NSRange(location: 0, length: max(0, total))
        guard let range = editor.engine.selectedTextRange else { return XCTFail("no selection") }

        var offGrid: [String] = []
        for (i, r) in editor.engine.selectionRects(for: range).enumerated() {
            if !isOnWholePoint(r.rect.origin.y) || !isOnWholePoint(r.rect.maxY) {
                offGrid.append(String(format: "rect %d y=%.4f maxY=%.4f", i, r.rect.origin.y, r.rect.maxY))
            }
        }
        XCTAssertEqual(offGrid, [], "a line selection rect must not straddle a point")
    }

    /// **THE ASSERTION THAT WAS MISSING.** Every edge can be on the grid while consecutive rects
    /// still fail to meet — that is exactly what shipped: `[12.0, 34.0]` then `[34.3333, 57.3333]`,
    /// a 1/3pt unfilled row reading as a white seam, and a matching 1/3pt overlap further down.
    /// A TEXT fixture, deliberately without a table: a table's cells sit side by side, so its rects
    /// run left-to-right and step BACKWARD in y between rows (measured -63 and -46 here), and the
    /// ~1pt bands between adjacent washed cells are the grid's borders to draw — both documented, and
    /// neither is a seam in a line of text.
    func test_consecutiveSelectionRectsAbut() {
        editor.document = textDocument()
        window.layoutIfNeeded()
        let total = editor.currentRoles.indices.reduce(0) { $0 + editor.flatLength(ofRoleAt: $1) + 1 } - 1
        editor.engineSelectedRange = NSRange(location: 0, length: max(0, total))
        guard let range = editor.engine.selectedTextRange else { return XCTFail("no selection") }

        var seams: [String] = []
        var previous: CGRect?
        for (i, r) in editor.engine.selectionRects(for: range).enumerated() {
            if let previous, abs(r.rect.minY - previous.maxY) > 0.0001 {
                seams.append(String(format: "between %d and %d: %.4f", i - 1, i, r.rect.minY - previous.maxY))
            }
            previous = r.rect
        }
        XCTAssertEqual(seams, [], "a gap leaves a white row in the wash; an overlap double-draws it")
    }

    /// A wrapped paragraph whose second line opens with a custom emoji — the shape the report came
    /// from, and the one where the atom's deliberate line overhang could reintroduce a seam.
    func test_consecutiveRectsAbutAcrossAWrappedParagraphWithAnEmoji() {
        var emoji = CharacterAttributes()
        emoji.emoji = EmojiRef(id: "s1", instanceID: "i1")
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p0"), runs: [
            TextRun(text: "Fqwfqwefqwfqwefqwehfqwehfpuiqwehpfuihqwe"),
            TextRun(text: "\u{FFFC}", attributes: emoji),
            TextRun(text: "pfhqwpeifhpqwehf weed ewqfqwe fwfqw"),
        ]))])
        window.layoutIfNeeded()
        editor.engineSelectedRange = NSRange(location: 0, length: editor.flatLength(ofRoleAt: 0))
        guard let range = editor.engine.selectedTextRange else { return XCTFail("no selection") }

        var seams: [String] = []
        var previous: CGRect?
        for (i, r) in editor.engine.selectionRects(for: range).enumerated() {
            if let previous, abs(r.rect.minY - previous.maxY) > 0.0001 {
                seams.append(String(format: "between %d and %d: %.4f", i - 1, i, r.rect.minY - previous.maxY))
            }
            previous = r.rect
        }
        XCTAssertEqual(seams, [], "the reported shape: a white row between line one and line two")
    }

    /// **The COMPOSER's own margins, which are half points.** The chat panel's vertical pair is
    /// `textInputViewInternalInsets` (5.0 / 4.0) plus `calculateTextFieldRealInsets` (4.5 / 5.5) —
    /// deliberately lopsided so the TOTAL is even, and the engine is handed the 4.5 / 5.5 half of it
    /// as `contentMargins`. That went straight through to `textContainerInset`, so every block origin
    /// in the composer sat on a half point and the seam came back there after the article editor was
    /// clean. The article editor passes 12.0 and never showed it.
    func test_halfPointContentMarginsStillLeaveEveryOriginOnAWholePoint() {
        editor.document = textDocument()
        _ = editor.update(size: CGSize(width: 320, height: 1000),
                          insets: .zero,
                          contentMargins: UIEdgeInsets(top: 4.5, left: 0, bottom: 5.5, right: 0),
                          scrollIndicatorInsets: nil)
        window.layoutIfNeeded()

        var offGrid: [String] = []
        for index in editor.currentRoles.indices {
            let frame = editor.engine.id_frameForBlock(at: UInt(index))
            if !isOnWholePoint(frame.origin.y) {
                offGrid.append(String(format: "role %d y=%.4f", index, frame.origin.y))
            }
        }
        XCTAssertEqual(offGrid, [], "a half-point container inset must not push every line off a point")
    }

    /// And the seam itself, under those margins.
    func test_consecutiveRectsAbutUnderTheComposersHalfPointMargins() {
        editor.document = textDocument()
        _ = editor.update(size: CGSize(width: 320, height: 1000),
                          insets: .zero,
                          contentMargins: UIEdgeInsets(top: 4.5, left: 0, bottom: 5.5, right: 0),
                          scrollIndicatorInsets: nil)
        window.layoutIfNeeded()
        let total = editor.currentRoles.indices.reduce(0) { $0 + editor.flatLength(ofRoleAt: $1) + 1 } - 1
        editor.engineSelectedRange = NSRange(location: 0, length: max(0, total))
        guard let range = editor.engine.selectedTextRange else { return XCTFail("no selection") }

        var seams: [String] = []
        var previous: CGRect?
        for (i, r) in editor.engine.selectionRects(for: range).enumerated() {
            if let previous, abs(r.rect.minY - previous.maxY) > 0.0001 {
                seams.append(String(format: "between %d and %d: %.4f", i - 1, i, r.rect.minY - previous.maxY))
            }
            previous = r.rect
        }
        XCTAssertEqual(seams, [], "the composer's gaps")
    }

    /// **The snap must not become a disable.** Zeroing the drop would satisfy every assertion above
    /// while putting the text back where the R8 baseline work found it, so the drop is also required
    /// to stay within half a point of the exact `ceil(fontBox) - fontBox` it approximates.
    func test_theSnappedDropStaysWithinHalfAPointOfTheExactBaseline() {
        editor.document = richDocument()
        window.layoutIfNeeded()

        var checked = 0
        for index in editor.currentRoles.indices {
            let attributes = editor.engine.attributedBlocks[index].length > 0
                ? editor.engine.attributedBlocks[index].attributes(at: 0, effectiveRange: nil)
                : [:]
            guard let font = EngineBlockSpacing.pinnedBoxFont(of: attributes),
                  let paragraph = attributes[.paragraphStyle] as? NSParagraphStyle,
                  paragraph.maximumLineHeight > 0, attributes[.attachment] == nil else { continue }
            let exact = max(0, paragraph.maximumLineHeight - (font.ascender - font.descender))
            guard exact > 0 else { continue }
            let applied = EngineBlockSpacing.v2BaselineDrop(of: attributes)
            checked += 1
            XCTAssertTrue(isOnWholePoint(applied), "role \(index) drop \(applied) is not a whole point")
            XCTAssertLessThanOrEqual(abs(applied - exact), 0.5 + 0.0001,
                                     "role \(index): snapped \(applied) is further than half a point from \(exact)")
        }
        XCTAssertGreaterThan(checked, 0, "the fixture must actually exercise a non-zero drop")
    }
}
