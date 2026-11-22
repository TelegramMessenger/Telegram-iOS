import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// List markers in the gutter: the bullet, the ordinal, the checkbox.
///
/// The engine draws each block from its own attributed text and has no canvas of its own, so a
/// marker is a host-positioned view — the same family as the container bands. Before this existed
/// the mapper reserved the gutter (`StyleSheet.paragraphStyle(list:)` indents a list item) and
/// nothing was drawn in it: a correctly indented list with no bullet, number or checkbox, which is
/// what the device pass reported.
@available(iOS 18.4, *)
final class EngineListMarkerTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func item(_ id: String, _ text: String, _ marker: ListMarker, level: Int = 0, checked: Bool? = nil) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id),
                                  list: ListMembership(marker: marker, level: level, checked: checked),
                                  runs: [TextRun(text: text)]))
    }
    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: [TextRun(text: text)]))
    }
    private func load(_ blocks: [Block]) {
        editor.document = Document(blocks: blocks)
        editor.setNeedsLayout(); editor.layoutIfNeeded()
    }
    /// The drawn marker labels, in document order — nil for an item whose marker is a hosted view.
    private func drawnLabels() -> [String] {
        editor.currentRoles.compactMap { role in
            (editor.listMarkerViews[role.blockID] as? ListMarkerLabelView)?.label
        }
    }
    private func markerFrame(_ id: String) -> CGRect? { editor.listMarkerViews[BlockID(id)]?.frame }

    // MARK: - Vertical alignment, against RENDERED INK (K3, 2026-09-11)

    /// The ink boxes of the marker gutter and of the text column, for the block at `index`.
    ///
    /// Rendered rather than computed: where a glyph LANDS is the whole question here, and every
    /// earlier version of this geometry was wrong while every frame-level assertion about it passed.
    /// Both columns are measured with the SAME glyphs ("1." marker against "1." text), so the two ink
    /// boxes relate to their baselines identically and their difference IS the baseline difference —
    /// an 'H' against a '1.' would fold each glyph's own ink extents into the answer.
    private func inkBaselines(markerLeftEdge: CGFloat, markerRightEdge: CGFloat,
                              textLeftEdge: CGFloat, rows: ClosedRange<CGFloat>) -> (marker: CGFloat, text: CGFloat)? {
        let image = UIGraphicsImageRenderer(bounds: editor.bounds).image { ctx in
            editor.layer.render(in: ctx.cgContext)
        }
        guard let cg = image.cgImage else { return nil }
        let w = cg.width, h = cg.height
        var pixels = [UInt8](repeating: 0, count: w * h)
        guard let bmp = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: w, space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        bmp.setFillColor(UIColor.white.cgColor)
        bmp.fill(CGRect(x: 0, y: 0, width: w, height: h))
        bmp.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        let scale = CGFloat(w) / editor.bounds.width
        // Windowed to the block's own line box: a quote's AUTHOR LINE placeholder sits in the same
        // x column a few lines below, and an unwindowed scan reports its ink as the marker's.
        func bottom(_ xFrom: CGFloat, _ xTo: CGFloat) -> CGFloat? {
            var last: Int?
            for y in max(0, Int(rows.lowerBound * scale))..<min(h, Int(rows.upperBound * scale)) {
                for x in max(0, Int(xFrom * scale))..<min(w, Int(xTo * scale)) where pixels[y * w + x] < 140 {
                    last = y; break
                }
            }
            return last.map { CGFloat($0) / scale }
        }
        guard let m = bottom(markerLeftEdge, markerRightEdge),
              let t = bottom(textLeftEdge, textLeftEdge + 14) else { return nil }
        return (m, t)
    }

    /// A marker sits on ITS TEXT'S baseline — the engine's, which is not V2's.
    ///
    /// The engine pins each line box to V2's pitch and TextKit bottom-aligns the line inside it, so a
    /// marker placed at the font's ascender from the box top floats `pitch - lineHeight` above the
    /// text: 1.7pt at body, 4.0pt at a heading. Reported from the device as "list bullet/item
    /// alignment" (K3, 2026-09-11).
    func test_aMarkerSitsOnItsTextsBaseline() {
        for style in [ParagraphStyleName.body, .heading1, .heading2, .heading3, .caption] {
            editor.document = Document(blocks: [.paragraph(ParagraphBlock(
                id: BlockID("n0"), style: style,
                list: ListMembership(marker: .ordered, level: 0), runs: [TextRun(text: "1.")]))])
            editor.setNeedsLayout(); editor.layoutIfNeeded()
            let frame = editor.engine.id_frameForBlock(at: 0)
            let textLeft = frame.minX + StyleSheet.listMarkerSpacing + StyleSheet.orderedListTextInset
            guard let ink = inkBaselines(markerLeftEdge: frame.minX, markerRightEdge: textLeft - 1, textLeftEdge: textLeft,
                                        rows: frame.minY...frame.maxY) else {
                return XCTFail("nothing rendered for \(style)")
            }
            XCTAssertEqual(ink.marker, ink.text, accuracy: 0.4,
                           "\(style): the marker's baseline is \(ink.text - ink.marker)pt off its text's")
        }
    }

    /// The same, for a list inside a QUOTE — which renders its text at 15pt whatever the depth. A
    /// marker resolving its font from the plain mapper is a 17pt ordinal beside 15pt text, and lands
    /// on a different baseline because a different pitch is pinned.
    func test_aQuotedMarkerMatchesTheQuotesOwnTextSize() {
        editor.document = Document(blocks: [.blockQuote(BlockQuote(id: BlockID("q0"), children: [
            .paragraph(ParagraphBlock(id: BlockID("n0"),
                                      list: ListMembership(marker: .ordered, level: 0),
                                      runs: [TextRun(text: "1.")])),
        ]))])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        guard let index = editor.currentRoles.firstIndex(where: { $0.blockID == BlockID("n0") }) else {
            return XCTFail("no quoted item")
        }
        let rendered = editor.engine.attributedBlocks[index].attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        let marker = editor.listMarkerViews[BlockID("n0")] as? ListMarkerLabelView
        XCTAssertEqual(marker?.markerFont.pointSize, rendered?.pointSize,
                       "the marker is drawn at \(marker?.markerFont.pointSize ?? -1)pt beside "
                       + "\(rendered?.pointSize ?? -1)pt text")
        let frame = editor.engine.id_frameForBlock(at: UInt(index))
        // The quote indents its content, so the marker column starts there — not at the block frame's
        // edge, which is where the quote's own BAR is drawn.
        let markerLeft = frame.minX + editor.currentRoles[index].contentIndent(
            styleSheet: editor.bridge.renderMapper(for: editor.currentRoles[index]).styleSheet)
        let textLeft = markerLeft + StyleSheet.listMarkerSpacing + StyleSheet.orderedListTextInset
        guard let ink = inkBaselines(markerLeftEdge: markerLeft, markerRightEdge: textLeft - 1,
                                     textLeftEdge: textLeft, rows: frame.minY...frame.maxY) else {
            return XCTFail("nothing rendered")
        }
        XCTAssertEqual(ink.marker, ink.text, accuracy: 0.4,
                       "the quoted marker's baseline is \(ink.text - ink.marker)pt off its text's")
    }

    /// An EMPTY item's marker sits where it will sit once a glyph is typed — so it does not jump on
    /// the first keystroke. This is the shape the device reported: pressing Return makes an empty
    /// item, and its marker is the one the user looks at.
    func test_anEmptyItemsMarkerDoesNotJumpWhenTheFirstGlyphIsTyped() {
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(
            id: BlockID("n0"), list: ListMembership(marker: .ordered, level: 0), runs: []))])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        let empty = markerFrame("n0")
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(
            id: BlockID("n0"), list: ListMembership(marker: .ordered, level: 0),
            runs: [TextRun(text: "x")]))])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        XCTAssertEqual(empty?.minY, markerFrame("n0")?.minY,
                       "the marker moved when the item stopped being empty")
    }

    // MARK: - The labels

    func test_aBulletListDrawsABulletPerItem() {
        load([item("a", "one", .bullet), item("b", "two", .bullet)])
        XCTAssertEqual(drawnLabels(), ["•", "•"])
    }

    func test_anOrderedListNumbersItsItems() {
        load([item("a", "one", .ordered), item("b", "two", .ordered), item("c", "three", .ordered)])
        XCTAssertEqual(drawnLabels(), ["1.", "2.", "3."])
    }

    /// A non-list paragraph between two runs resets the numbering — Core's rule, reused rather than
    /// re-derived here.
    func test_aPlainParagraphBetweenTwoRunsRestartsTheNumbering() {
        load([item("a", "one", .ordered), para("p", "prose"), item("b", "two", .ordered)])
        XCTAssertEqual(drawnLabels(), ["1.", "1."])
    }

    /// A container ends a numbered run for the same reason: it reports no list membership.
    func test_aCodeBlockBetweenTwoRunsRestartsTheNumbering() {
        load([item("a", "one", .ordered),
              .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "x")])),
              item("b", "two", .ordered)])
        XCTAssertEqual(drawnLabels(), ["1.", "1."])
    }

    func test_nestingChangesTheMarkerAlphabet() {
        load([item("a", "one", .ordered), item("b", "nested", .ordered, level: 1),
              item("c", "bullet", .bullet, level: 1)])
        XCTAssertEqual(drawnLabels(), ["1.", "a.", "◦"])
    }

    /// With no host checkbox provider the checklist still draws — Core hands back its own glyphs,
    /// so a checklist is never invisible just because a host supplied nothing.
    func test_aChecklistWithoutAProviderDrawsItsOwnGlyphs() {
        load([item("a", "done", .checklist, checked: true), item("b", "todo", .checklist, checked: false)])
        XCTAssertEqual(drawnLabels(), ["☑", "☐"])
    }

    // MARK: - Geometry

    /// The marker hangs at the level's indent from the block's leading edge, and its line box sits
    /// where the ENGINE's line puts the baseline — `pitch - lineHeight` below the block's top, since
    /// TextKit bottom-aligns a line inside the pinned box. It used to assert the marker's box started
    /// at the block's top, which is legacy's geometry read through legacy's baseline correction; the
    /// engine has no such correction and the marker floated above its text (K3, 2026-09-11).
    func test_aMarkerHangsAtItsLevelIndentAndOnTheEnginesBaseline() {
        load([item("a", "one", .bullet), item("b", "nested", .bullet, level: 1)])
        guard let top = markerFrame("a"), let nested = markerFrame("b") else { return XCTFail("no markers") }
        let blockTop = editor.engine.id_frameForBlock(at: 0)
        let blockNested = editor.engine.id_frameForBlock(at: 1)
        XCTAssertEqual(top.minX, blockTop.minX, accuracy: 0.5, "a level-0 marker sits on the leading edge")
        XCTAssertEqual(nested.minX, blockNested.minX + StyleSheet.listIndentStep, accuracy: 0.5)
        let font = editor.bridge.styleSheet.font(for: .body, attributes: .plain)
        // OFF THE RENDERED STRING, not the stylesheet. `engineReadable` re-expresses the pinned box,
        // so the stylesheet still reports the PITCH while the glyphs sit in the smaller box — reading
        // it here reproduced, inside the test, exactly the defect this case exists to catch.
        let pinned = (editor.bridge.lineAttributes(for: editor.currentRoles[0])[.paragraphStyle]
            as? NSParagraphStyle)?.maximumLineHeight ?? 0
        XCTAssertEqual(top.minY, blockTop.minY + pinned - font.lineHeight, accuracy: 0.5,
                       "the marker's baseline is the engine's, one descender above the line box's bottom")
        XCTAssertLessThan(top.maxX, blockTop.minX + StyleSheet.listIndentStep + StyleSheet.listMarkerSpacing,
                          "and it stays inside the gutter the mapper reserved")
    }

    // MARK: - Pooling

    func test_aMarkerGoesWhenTheItemStopsBeingOne() {
        load([item("a", "one", .bullet), item("b", "two", .bullet)])
        XCTAssertEqual(editor.listMarkerViews.count, 2)
        editor.composerSelectedRange = NSRange(location: 0, length: 0)
        editor.setList(nil)
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        XCTAssertNil(markerFrame("a"), "the un-listed paragraph's marker is culled")
        XCTAssertEqual(editor.listMarkerViews.count, 1)
    }

    func test_aMarkerIsReusedAcrossLayoutPassesRatherThanRebuilt() {
        load([item("a", "one", .bullet)])
        let first = editor.listMarkerViews[BlockID("a")]
        XCTAssertNotNil(first, "a marker exists to be reused — without this the identity check is nil === nil")
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        XCTAssertTrue(editor.listMarkerViews[BlockID("a")] === first, "pooled by block id")
    }

    /// Markers ride the engine's scroll content, like the container bands — a marker parented to the
    /// editor would slide out from under its own text on the first scroll.
    func test_aMarkerIsParentedIntoTheScrollingContent() {
        load([item("a", "one", .bullet)])
        XCTAssertTrue(editor.listMarkerViews[BlockID("a")]?.superview === editor.engine)
    }

    // MARK: - The hosted checkbox

    private final class StubCheckbox: UIView, RichTextChecklistMarkerView {
        var checked: Bool
        init(checked: Bool) { self.checked = checked; super.init(frame: .zero) }
        required init?(coder: NSCoder) { fatalError() }
        func setChecked(_ checked: Bool, animated: Bool) { self.checked = checked }
    }

    private func hostedCheckbox(_ id: String) -> StubCheckbox? {
        (editor.listMarkerViews[BlockID(id)] as? ListCheckboxHostView)?.hostedCheckbox as? StubCheckbox
    }

    private func withCheckboxProvider() {
        editor.registerChecklistMarkerViewProvider { checked, _ in StubCheckbox(checked: checked) }
    }

    func test_aProvidedCheckboxReplacesTheGlyphAndCarriesTheState() {
        withCheckboxProvider()
        load([item("a", "done", .checklist, checked: true), item("b", "todo", .checklist, checked: false)])
        XCTAssertEqual(drawnLabels(), [], "no glyph is drawn when the host supplies a checkbox")
        XCTAssertEqual(hostedCheckbox("a")?.checked, true)
        XCTAssertEqual(hostedCheckbox("b")?.checked, false)
    }

    func test_tappingACheckboxTogglesItAndUndoPutsItBack() {
        withCheckboxProvider()
        load([item("a", "todo", .checklist, checked: false)])
        XCTAssertTrue(editor.engine.becomeFirstResponder())

        editor.toggleChecklistItem(BlockID("a"))
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        XCTAssertEqual(editor.document.blocks[0].listMembership?.checked, true)
        XCTAssertEqual(hostedCheckbox("a")?.checked, true, "the hosted view follows the model")

        editor.engine.undoManager?.undo()
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        XCTAssertEqual(editor.document.blocks[0].listMembership?.checked, false, "undo unticks it")
    }

    /// Ticking a checkbox must not throw away the user's typing history — a document set would
    /// (host structural repairs clear it), which is why the toggle goes through `adoptRolePlan`.
    func test_tickingACheckboxKeepsTheTypingUndoBeforeIt() {
        withCheckboxProvider()
        load([item("a", "todo", .checklist, checked: false)])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 4, length: 0)
        editor.insertText("!")
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        XCTAssertEqual(editor.engine.attributedBlocks[0].string, "todo!")

        editor.toggleChecklistItem(BlockID("a"))
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        editor.engine.undoManager?.undo()   // the tick
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        XCTAssertEqual(editor.document.blocks[0].listMembership?.checked, false)
        editor.engine.undoManager?.undo()   // the typing, still there
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        XCTAssertEqual(editor.engine.attributedBlocks[0].string, "todo", "the typing undo survived the tick")
    }

    /// The text is untouched by a tick: only structure changed.
    func test_tickingACheckboxDoesNotChangeTheText() {
        withCheckboxProvider()
        load([item("a", "todo", .checklist, checked: false)])
        let before = editor.engine.attributedBlocks.map(\.string)
        editor.toggleChecklistItem(BlockID("a"))
        XCTAssertEqual(editor.engine.attributedBlocks.map(\.string), before)
    }

    /// Drawn size and touch target are different questions. The checkbox is ~17pt of glyph at body
    /// size; legacy inflates the rect to at least 30pt before hit-testing it, and so does this.
    func test_aCheckboxTakesTapsWellOutsideItsDrawnBox() {
        withCheckboxProvider()
        load([item("a", "todo", .checklist, checked: false)])
        guard let host = editor.listMarkerViews[BlockID("a")] as? ListCheckboxHostView else {
            return XCTFail("no hosted checkbox")
        }
        XCTAssertLessThan(host.bounds.width, EngineListMarkerGeometry.minimumTouchTarget,
                          "the drawn box really is smaller than the target — else this proves nothing")
        let target = EngineListMarkerGeometry.touchTarget(for: host.bounds)
        XCTAssertTrue(host.point(inside: CGPoint(x: host.bounds.midX, y: target.maxY - 1.0), with: nil),
                      "a near miss still ticks it")
        XCTAssertFalse(host.point(inside: CGPoint(x: host.bounds.midX, y: target.maxY + 1.0), with: nil),
                       "but not an unrelated tap")
    }

    /// A checklist with no host provider draws a glyph — and must still be tickable, or whether you
    /// can tick a box depends on the host's configuration.
    func test_aGlyphChecklistIsTappableToo() {
        load([item("a", "todo", .checklist, checked: false)])
        guard let marker = editor.listMarkerViews[BlockID("a")] as? ListMarkerLabelView else {
            return XCTFail("no marker")
        }
        XCTAssertTrue(marker.isUserInteractionEnabled)
        // Probed from the target itself: a glyph box is TALLER than the drawn checkbox, so it needs
        // less vertical inflation to reach the 30pt minimum, and a hard-coded offset that clears one
        // overshoots the other.
        let target = EngineListMarkerGeometry.touchTarget(for: marker.bounds)
        XCTAssertGreaterThan(target.height, marker.bounds.height, "the target really is inflated")
        XCTAssertTrue(marker.point(inside: CGPoint(x: marker.bounds.midX, y: target.maxY - 1.0), with: nil))
        XCTAssertFalse(marker.point(inside: CGPoint(x: marker.bounds.midX, y: target.maxY + 1.0), with: nil))
        XCTAssertEqual(marker.gestureRecognizers?.count, 1)
    }

    /// A bullet is decoration and must NOT eat taps — a tap beside it places the caret.
    func test_aBulletTakesNoTaps() {
        load([item("a", "one", .bullet)])
        guard let marker = editor.listMarkerViews[BlockID("a")] as? ListMarkerLabelView else {
            return XCTFail("no marker")
        }
        XCTAssertFalse(marker.isUserInteractionEnabled)
        XCTAssertNil(marker.gestureRecognizers?.first)
    }

    // MARK: - Cells

    /// Legacy does not stamp markers inside table cells; neither does this.
    ///
    /// The document carries a top-level list item too, and the test asserts THAT one is marked — an
    /// "assert nothing is drawn" test passes just as well when nothing is drawn anywhere, which is
    /// the trap this package's own verification notes describe. The pair proves the mechanism is
    /// live and the cell is specifically excluded from it.
    func test_aListInsideATableCellDrawsNoMarkerThoughOneBesideItDoes() {
        let cell = Cell(id: BlockID("c0"), blocks: [item("ci", "in a cell", .bullet)])
        load([item("outside", "top level", .bullet),
              .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 100)],
                                rows: [Row(id: BlockID("r"), cells: [cell])]))])
        XCTAssertNotNil(markerFrame("outside"), "the top-level item IS marked")
        XCTAssertNil(markerFrame("ci"), "the cell's item is not")
        XCTAssertEqual(editor.listMarkerViews.count, 1)
    }

    // MARK: - A two-digit ordinal needs more room (K3, 2026-09-11)

    /// **The text hangs past the marker, however wide the marker is.** At ten the ordinal grows a
    /// character and the base indent — which reserves one — stopped clearing it: the device showed
    /// `10F` and `11F`, the number drawn straight through the item's text.
    ///
    /// The extra room is `(characters - 1) × one digit`, measured on `0` rather than on the label,
    /// so every ordinal of the same length reserves identically and renumbering a list never shifts
    /// text sideways within a decade.
    ///
    /// **It is reserved for the whole LIST, not for the item that needs it** (2026-09-17). Charging
    /// it per item put items 1–9 in one text column and 10–12 in another, 10.28pt apart — the
    /// raggedness this file's original fix left behind. `EngineOrderedListColumnTests` owns the
    /// resulting geometry, including the marker column; this case owns the SIZE of the reservation.
    func test_aTwoDigitOrdinalReservesOneMoreDigitForTheWholeList() {
        load((1...12).map { item("i\($0)", "F", .ordered) })
        XCTAssertEqual(drawnLabels().prefix(3).map { $0 }, ["1.", "2.", "3."])

        let insets = editor.orderedListMarkerInsets()
        guard let ninth = editor.currentRoles.firstIndex(where: { $0.blockID == BlockID("i9") }),
              let tenth = editor.currentRoles.firstIndex(where: { $0.blockID == BlockID("i10") })
        else { return XCTFail("no items") }

        let font = editor.bridge.renderMapper(for: editor.currentRoles[tenth]).styleSheet
            .font(for: .body, attributes: .plain)
        let digit = ("0" as NSString).size(withAttributes: [.font: font]).width
        for (name, index) in [("nine", ninth), ("ten", tenth)] {
            guard let extra = insets[index] else { return XCTFail("item \(name) reserved nothing") }
            XCTAssertEqual(extra, digit, accuracy: 0.5,
                           "item \(name): one more character in the list, one more digit of room")
        }
    }

    /// …and the text must not hang OFF THE COLUMN.
    ///
    /// The extra room is a block INSET, and upstream used to lay a STACKED block out at the full
    /// canvas width whatever its insets — only the PLACED branch subtracted them — so an inset item's
    /// text wrapped at the column and was then drawn one digit in, running that far past the
    /// trailing edge every other block stops at. Invisible for the vertical-only insets every
    /// container uses, and immediately visible here (measured on K3's own numbers: the canvas
    /// started at 15.3 and was still 308.3 wide on a 310pt column).
    ///
    /// **Measured against a PLAIN PARAGRAPH, not against a sibling item.** Every item in a list now
    /// carries the same reservation, so item nine and item ten have identical frames and comparing
    /// them asserts nothing at all — which is exactly how this case started failing when the
    /// reservation became list-wide.
    func test_anIndentedOrdinalsTextStopsAtTheSameColumnEdge() {
        let filler = String(repeating: "i ", count: 120)
        var blocks: [Block] = (1...12).map { item("w\($0)", filler, .ordered) }
        blocks.append(.paragraph(ParagraphBlock(id: BlockID("plain"),
                                                runs: [TextRun(text: filler)])))
        load(blocks)
        guard let tenth = editor.currentRoles.firstIndex(where: { $0.blockID == BlockID("w10") }),
              let plain = editor.currentRoles.firstIndex(where: { $0.blockID == BlockID("plain") })
        else { return XCTFail("no items") }
        let tenthFrame = editor.engine.id_frameForBlock(at: UInt(tenth))
        let plainFrame = editor.engine.id_frameForBlock(at: UInt(plain))
        XCTAssertGreaterThan(tenthFrame.minX - plainFrame.minX, 1.0,
                             "precondition: the list item's text DOES start further in")
        XCTAssertEqual(tenthFrame.maxX, plainFrame.maxX, accuracy: 0.5,
                       "and stops where every other block stops")
    }

    /// Nothing moves for a list that never reaches ten — the base indent is the whole answer there,
    /// so no existing document shifts.
    func test_aSingleDigitListIsUnchanged() {
        load((1...9).map { item("s\($0)", "F", .ordered) })
        XCTAssertTrue(editor.orderedListMarkerInsets().isEmpty)
    }
}

