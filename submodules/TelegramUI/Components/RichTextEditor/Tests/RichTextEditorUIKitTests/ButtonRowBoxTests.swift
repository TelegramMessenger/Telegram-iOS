#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorCore
@testable import RichTextEditorUIKit

/// The button row is the editor's ONLY text-free `CanvasBlock`. Nothing in the canvas had exercised a
/// block with no editable text before, so these cover the structural contract: the position model, the
/// caret being able to reach and LEAVE the row, and the model round-trip through the canvas.
@available(iOS 13.0, *)
final class ButtonRowBoxTests: XCTestCase {
    private func makeRow(_ labels: [String], alignment: ButtonRowAlignment = .justify) -> ButtonRowBlock {
        ButtonRowBlock(id: BlockID.generate(),
                       buttons: labels.map { ButtonRef(label: [TextRun(text: $0)], action: .url("https://telegram.org")) },
                       alignment: alignment)
    }

    private func paragraph(_ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID.generate(), style: .body, runs: [TextRun(text: text)]))
    }

    /// Re-runs layout so `stampListMarkers` re-reads the host capability flags. Production gets this for
    /// free on its next layout pass; a test that assigns a hook after seeding must ask for it.
    private func restamp(_ view: RichTextEditorView) {
        _ = view.update(size: CGSize(width: 320, height: 480), insets: .zero)
    }

    private func makeView(with blocks: [Block]) -> RichTextEditorView {
        let view = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        view.document = Document(blocks: blocks)
        _ = view.update(size: CGSize(width: 320, height: 480), insets: .zero)
        return view
    }

    func test_row_roundTripsThroughTheCanvas() {
        let row = makeRow(["A", "B"], alignment: .center)
        let view = makeView(with: [.buttonRow(row)])
        guard case let .buttonRow(restored) = view.document.blocks.first else {
            return XCTFail("expected a buttonRow block back from the canvas, got \(String(describing: view.document.blocks.first))")
        }
        XCTAssertEqual(restored.buttons, row.buttons)
        XCTAssertEqual(restored.alignment, row.alignment)
        XCTAssertEqual(restored.id, row.id)
    }

    func test_row_hasNonZeroHeight() {
        let view = makeView(with: [.buttonRow(makeRow(["A", "B"]))])
        XCTAssertGreaterThan(view.update(size: CGSize(width: 320, height: 480), insets: .zero), 0)
    }

    /// The box's `nodeSize` MUST agree with what `DocumentTree` produces, or every position after the
    /// row is off and the caret lands in the wrong block.
    func test_boxNodeSize_agreesWithTheDocumentTree() {
        for labels in [[], ["A"], ["A", "B", "C"]] {
            let row = makeRow(labels)
            let document = Document(blocks: [.buttonRow(row)])
            let box = ButtonRowBox(row: row, mapper: AttributedStringMapper(), width: 320)
            // documentSize is the row's nodeSize at the top level (the doc root adds nothing).
            XCTAssertEqual(box.nodeSize, DocumentTree.documentSize(document), "for \(labels.count) buttons")
        }
    }

    /// A text-free block owns no leaf regions — that is what keeps the caret off a pill's label.
    func test_row_ownsNoLeafRegions() {
        let box = ButtonRowBox(row: makeRow(["A", "B"]), mapper: AttributedStringMapper(), width: 320)
        XCTAssertTrue(box.leafRegions().isEmpty)
    }

    /// The regression `CanvasTableNavTests` exists for: a framed atom that swallows the inter-block gap
    /// leaves unowned dead space and the caret cannot escape it. Every position in a document
    /// containing a row must resolve.
    func test_everyPositionResolves_withARowBetweenParagraphs() {
        let view = makeView(with: [paragraph("above"), .buttonRow(makeRow(["A", "B"])), paragraph("below")])
        let tree = DocumentTree.build(from: view.document)
        let size = DocumentTree.documentSize(view.document)
        XCTAssertGreaterThan(size, 0)
        for position in 0 ... size {
            XCTAssertNotNil(PositionResolver.resolve(position, in: tree), "position \(position) did not resolve")
        }
    }

    /// A tap anywhere in the row's band lands on a pill rather than falling through to a neighbour.
    func test_closestPosition_snapsToTheNearestPill() {
        let row = makeRow(["A", "B", "C"])
        let box = ButtonRowBox(row: row, mapper: AttributedStringMapper(), width: 320)
        box.frame = CGRect(x: 0, y: 0, width: 320, height: box.height)
        box.nodeStart = 10
        // Far left → first pill; far right → last pill.
        XCTAssertEqual(box.closestPosition(toCanvasPoint: CGPoint(x: 1, y: box.height / 2)), 11)
        XCTAssertEqual(box.closestPosition(toCanvasPoint: CGPoint(x: 319, y: box.height / 2)), 13)
    }

    /// An EMPTY row still needs one caret target, or it can be neither selected nor deleted.
    func test_emptyRow_stillResolvesToOnePosition() {
        let box = ButtonRowBox(row: makeRow([]), mapper: AttributedStringMapper(), width: 320)
        box.nodeStart = 4
        XCTAssertEqual(box.nodeSize, 3)
        XCTAssertEqual(box.closestPosition(toCanvasPoint: CGPoint(x: 10, y: 10)), 5)
    }

    /// Removing the last pill leaves an empty row that is still a valid, addressable block.
    func test_replaceButton_removesAPillAndRepacks() {
        let box = ButtonRowBox(row: makeRow(["A", "B"]), mapper: AttributedStringMapper(), width: 320)
        let before = box.nodeSize
        XCTAssertTrue(box.replaceButton(at: 0, with: nil))
        XCTAssertEqual(box.nodeSize, before - 1)
        XCTAssertEqual(box.currentRow().buttons.map(\.labelText), ["B"])
        XCTAssertFalse(box.replaceButton(at: 5, with: nil))
    }

    func test_setAlignment_repacksAndRoundTrips() {
        let box = ButtonRowBox(row: makeRow(["A", "B", "C"], alignment: .justify), mapper: AttributedStringMapper(), width: 320)
        let justifiedFirst = box.pillFrames.first
        box.setAlignment(.center)
        XCTAssertEqual(box.currentRow().alignment, .center)
        XCTAssertNotEqual(box.pillFrames.first, justifiedFirst)
    }

    /// The row is a framed atom, so it must NOT be given the inter-block gap — the neighbour below
    /// owns it. Its own height is exactly the packed height.
    func test_height_isThePackedHeightWithNoExternalInset() {
        let box = ButtonRowBox(row: makeRow(["A"]), mapper: AttributedStringMapper(), width: 320)
        XCTAssertEqual(box.height, RichTextButtonMetrics.default.blockRowHeight, accuracy: 0.01)
    }

    func test_spacingKind_isButtonRow() {
        let box = ButtonRowBox(row: makeRow(["A"]), mapper: AttributedStringMapper(), width: 320)
        XCTAssertEqual(box.spacingKind, .buttonRow)
    }

    /// Select All + Backspace must REMOVE a row. A text-free block's `textStart + textLength` collapses
    /// to `nodeStart`, so without a `coverableContentEnd` arm every selection reads as fully covering
    /// it — and a partial selection would wrongly delete the whole row.
    func test_selectAllThenBackspace_removesTheRow() {
        let view = makeView(with: [paragraph("above"), .buttonRow(makeRow(["A", "B"])), paragraph("below")])
        view.selectAll()
        view.deleteBackward()
        XCTAssertFalse(view.document.blocks.contains { if case .buttonRow = $0 { return true } else { return false } },
                       "Select All + Backspace left the button row behind")
    }

    /// REGRESSION: a button row rendered NOTHING on screen. Every block in this canvas is view-backed
    /// (`reconcileBlockViews` realizes a `BlockBackingView` only when `rendersAsBlockView` is true) and
    /// `DocumentCanvasView` has no `draw(_:)` override, so a block that opts out is simply never drawn.
    /// The protocol's `false` default is a stale artifact — all six pre-existing block types set it true.
    ///
    /// Asserted through the realization seam rather than by pixel-diffing: it is the actual mechanism
    /// that failed, and the geometry tests above all passed while the row was invisible.
    func test_row_isRealizedAsABlockView() {
        let canvas = DocumentCanvasView()
        let row = makeRow(["A", "B"])
        canvas.setBlocks([paragraph("above"), .buttonRow(row)], width: 300)
        canvas.frame = CGRect(x: 0, y: 0, width: 300, height: canvas.intrinsicContentSize.height)
        canvas.layoutIfNeeded()
        canvas.reconcileBlockViews(visibleRect: CGRect(x: 0, y: 0, width: 300, height: 2000))

        XCTAssertNotNil(canvas.blockViews[row.id],
                        "the button row was never realized as a block view, so it renders nothing")
    }

    /// The same contract, stated directly: opting out of view-backing means opting out of rendering.
    func test_row_rendersAsABlockView() {
        let box = ButtonRowBox(row: makeRow(["A"]), mapper: AttributedStringMapper(), width: 320)
        XCTAssertTrue(box.rendersAsBlockView,
                      "a block that is not view-backed is never drawn — the canvas has no draw(_:) override")
    }

    // MARK: - Rendering (regression: rows were entirely invisible)

    private func realizedCanvas(_ blocks: [Block], width: CGFloat = 300) -> DocumentCanvasView {
        let canvas = DocumentCanvasView()
        canvas.setBlocks(blocks, width: width)
        canvas.frame = CGRect(x: 0, y: 0, width: width, height: canvas.intrinsicContentSize.height)
        canvas.layoutIfNeeded()
        canvas.reconcileBlockViews(visibleRect: CGRect(x: 0, y: 0, width: width, height: 4000))
        return canvas
    }

    /// REGRESSION: button rows rendered NOTHING. Every block here is view-backed —
    /// `reconcileBlockViews` realizes a `BlockBackingView` only when `rendersAsBlockView` is true, and
    /// `DocumentCanvasView` has no `draw(_:)` override — so a block that opts out is never drawn at all.
    /// The protocol's `false` default is a stale artifact; all six pre-existing block types set it true.
    ///
    /// Asserted through the realization seam because that is the mechanism that actually failed: every
    /// geometry test passed while the row was invisible on screen.
    func test_row_isRealizedAsAButtonRowBackingView() {
        let row = makeRow(["A", "B"])
        let canvas = realizedCanvas([paragraph("above"), .buttonRow(row)])
        let view = canvas.blockViews[row.id]
        XCTAssertNotNil(view, "the button row was never realized, so it renders nothing")
        XCTAssertTrue(view is ButtonRowBackingView,
                      "a row must get its pill-hosting backing view, not a plain one")
    }

    /// The pills must be real subviews — a rasterised bitmap can never host a custom emoji.
    func test_row_hostsOnePillViewPerButton() {
        let row = makeRow(["A", "B", "C"])
        let canvas = realizedCanvas([.buttonRow(row)])
        guard let view = canvas.blockViews[row.id] as? ButtonRowBackingView else {
            return XCTFail("expected a ButtonRowBackingView")
        }
        view.layoutIfNeeded()
        XCTAssertEqual(view.subviews.compactMap { $0 as? ButtonPillView }.count, 3)
    }

    /// A recycled row view must never be handed to a paragraph: it draws nothing of its own and would
    /// render that paragraph blank. Same exclusion `TableBackingView` already has.
    func test_rowBackingView_isNotRecycledIntoThePlainPool() {
        // A row-ONLY document, so nothing else can contribute to the pool: any growth is the row's view.
        let row = makeRow(["A"])
        let canvas = realizedCanvas([.buttonRow(row)])
        XCTAssertNotNil(canvas.blockViews[row.id], "precondition: the row was realized")
        XCTAssertEqual(canvas.recycleQueueDepthForTesting, 0, "precondition: the pool starts empty")

        canvas.reconcileBlockViews(visibleRect: CGRect(x: 0, y: 8000, width: 300, height: 300))
        XCTAssertNil(canvas.blockViews[row.id], "precondition: the row was culled")
        XCTAssertEqual(canvas.recycleQueueDepthForTesting, 0,
                       "a ButtonRowBackingView must not enter the plain-view recycle pool — a paragraph "
                       + "later dequeuing it would render blank, since it draws nothing of its own")
    }

    /// An INLINE pill is hosted the same way an inline emoji is — as a view at its attachment's rect —
    /// so that its label can carry a live custom emoji too.
    func test_inlineButton_isHostedAsAPillView() {
        var attributes = CharacterAttributes.plain
        attributes.button = ButtonRef(label: [TextRun(text: "Go")], action: .url("https://telegram.org"))
        let canvas = realizedCanvas([.paragraph(ParagraphBlock(id: BlockID.generate(), style: .body, runs: [
            TextRun(text: "tap "),
            TextRun(text: "\u{FFFC}", attributes: attributes),
        ]))])
        canvas.syncButtonPillViews()
        XCTAssertEqual(canvas.hostedButtonPillCountForTesting, 1,
                       "an inline pill must be hosted as a view, not baked into the attachment image")
    }

    // MARK: - Block pill geometry (regression: rows drawn at inline size)

    /// REGRESSION: a block pill was framed at `attachment.size.height` — the label ink box plus padding
    /// (~20pt), which is an INLINE pill's height — so rows read as inline buttons even though the
    /// packing had allocated the correct 40pt slot. A block pill FILLS its slot, exactly as
    /// `InstantPageV2ButtonRowView.layoutSubviews` does (`pill.frame = entry.frame`).
    func test_blockPill_fillsItsFullSlotHeight() {
        let row = makeRow(["A", "B"])
        let canvas = realizedCanvas([.buttonRow(row)])
        guard let view = canvas.blockViews[row.id] as? ButtonRowBackingView else {
            return XCTFail("expected a ButtonRowBackingView")
        }
        view.layoutIfNeeded()
        let pills = view.subviews.compactMap { $0 as? ButtonPillView }
        XCTAssertEqual(pills.count, 2)
        for pill in pills {
            XCTAssertEqual(pill.bounds.height, RichTextButtonMetrics.default.blockRowHeight, accuracy: 0.01,
                           "a block pill must fill the fixed 40pt touch target, not the inline ink box")
            XCTAssertEqual(pill.layer.cornerRadius, RichTextButtonMetrics.default.blockRowHeight / 2.0, accuracy: 0.01,
                           "the capsule radius follows the pill height")
        }
    }

    /// A block pill's label is a point larger than an inline pill's, and semibold.
    func test_blockPill_usesTheLargerLabelFont() {
        let mapper = AttributedStringMapper()
        let button = ButtonRef(label: [TextRun(text: "Go")], action: .disabled)
        let block = mapper.buttonAttachment(button: button, isBlockPill: true, maxWidth: nil)
        let font = block.labelString.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.pointSize, RichTextButtonMetrics.default.blockFontSize)
        XCTAssertGreaterThan(RichTextButtonMetrics.default.blockFontSize, RichTextButtonMetrics.default.inlineFontSize)
    }

    // MARK: - Backspace (regression: a whole run of rows deleted at once)

    private func rowCount(_ canvas: DocumentCanvasView) -> Int {
        canvas.currentBlocks().filter { if case .buttonRow = $0 { return true } else { return false } }.count
    }

    /// REGRESSION: Backspace removed EVERY row in a run. A row is text-free, so `prevTextPosition` skips
    /// back over all of them and iOS's object-replacement range spans the lot; the generic
    /// selection-replace then dropped them together. Each press must remove exactly one.
    func test_backspace_deletesOneRowAtATime_notTheWholeRun() {
        let canvas = realizedCanvas([
            paragraph("above"),
            .buttonRow(makeRow(["A"])),
            .buttonRow(makeRow(["B"])),
            .buttonRow(makeRow(["C"])),
            paragraph("below"),
        ])
        XCTAssertEqual(rowCount(canvas), 3, "precondition")

        // Simulates exactly what iOS delivers: Backspace at the trailing paragraph's start arrives as an
        // object-replacement RANGE anchored at `prevTextPosition(before:)`, which — because a row carries
        // no text — skips back over EVERY row in the run. Recomputed per press, as the OS would.
        func backspaceAsDeliveredByIOS() {
            guard let below = canvas.boxes.last else { return XCTFail("no trailing paragraph") }
            let to = below.textStart
            canvas.setSelectionForTesting(anchor: canvas.prevTextPosition(before: to), head: to)
            canvas.deleteBackward()
        }

        backspaceAsDeliveredByIOS()
        XCTAssertEqual(rowCount(canvas), 2, "the first Backspace must remove exactly one row")
        backspaceAsDeliveredByIOS()
        XCTAssertEqual(rowCount(canvas), 1, "the second Backspace must remove exactly one more")
        backspaceAsDeliveredByIOS()
        XCTAssertEqual(rowCount(canvas), 0, "the third removes the last")
    }

    /// Within a multi-pill row, Backspace removes one pill and keeps the row.
    func test_backspace_onAPill_removesThatPillAndKeepsTheRow() {
        let row = makeRow(["A", "B", "C"])
        let canvas = realizedCanvas([paragraph("above"), .buttonRow(row)])
        guard let box = canvas.boxes.compactMap({ $0 as? ButtonRowBox }).first else {
            return XCTFail("expected a ButtonRowBox")
        }
        canvas.setSelectionForTesting(anchor: box.nodeStart + 3, head: box.nodeStart + 3)   // the third pill
        canvas.deleteBackward()
        XCTAssertEqual(rowCount(canvas), 1, "the row must survive while it still has pills")
        guard case let .buttonRow(restored) = canvas.currentBlocks().last else {
            return XCTFail("expected the row back")
        }
        XCTAssertEqual(restored.buttons.map { $0.labelText }, ["A", "B"])
    }

    // MARK: - Authoring

    func test_insertButtonRow_replacesAnEmptyParagraph() {
        let view = makeView(with: [paragraph("above"), .paragraph(ParagraphBlock(id: BlockID.generate(), style: .body, runs: []))])
        // Caret in the trailing EMPTY paragraph — the case that must be replaced rather than split.
        let canvas = view.canvasForTesting
        guard let empty = canvas.boxes.last else { return XCTFail("no trailing paragraph") }
        canvas.setSelectionForTesting(anchor: empty.textStart, head: empty.textStart)
        view.insertButtonRow()
        let blocks = view.document.blocks
        XCTAssertEqual(blocks.count, 2, "the empty paragraph is replaced, not left beside the row")
        guard case .buttonRow = blocks[1] else {
            return XCTFail("expected a button row, got \(blocks[1])")
        }
    }

    /// A tap on a pill asks the host to edit it, and the completion applies.
    func test_tappingAPill_requestsAnEditAndAppliesIt() {
        let row = makeRow(["A", "B"])
        let view = makeView(with: [.buttonRow(row)])
        var received: ButtonRef?
        view.onEditButtonRequested = { button, _, completion in
            received = button
            completion(ButtonRef(label: [TextRun(text: "Edited")], action: .url("https://example.com"), color: .success))
        }
        guard let box = view.canvasForTesting.boxes.compactMap({ $0 as? ButtonRowBox }).first,
              let rect = box.pillCanvasRect(0) else {
            return XCTFail("expected a row with a pill rect")
        }
        XCTAssertTrue(view.canvasForTesting.handleButtonTapIfNeeded(at: CGPoint(x: rect.midX, y: rect.midY)))
        XCTAssertEqual(received?.labelText, "A")
        guard case let .buttonRow(restored) = view.document.blocks.first else {
            return XCTFail("expected the row back")
        }
        XCTAssertEqual(restored.buttons.map { $0.labelText }, ["Edited", "B"])
        XCTAssertEqual(restored.buttons[0].color, .success)
    }

    /// The edit request says WHICH pill kind it is, so a host can offer different properties for each —
    /// the article editor drops the link style for a block-row pill (a chrome-less row button is not
    /// authorable) while keeping it for an inline one.
    func test_editRequest_reportsThePillKind() {
        // A block-row pill.
        let rowView = makeView(with: [.buttonRow(makeRow(["A"]))])
        var rowKind: Bool?
        rowView.onEditButtonRequested = { _, isBlockPill, _ in rowKind = isBlockPill }
        guard let box = rowView.canvasForTesting.boxes.compactMap({ $0 as? ButtonRowBox }).first,
              let rect = box.pillCanvasRect(0) else {
            return XCTFail("expected a row with a pill rect")
        }
        XCTAssertTrue(rowView.canvasForTesting.handleButtonTapIfNeeded(at: CGPoint(x: rect.midX, y: rect.midY)))
        XCTAssertEqual(rowKind, true, "a row pill reports isBlockPill")

        // An inline pill.
        var attributes = CharacterAttributes.plain
        attributes.button = ButtonRef(label: [TextRun(text: "Go")], action: .url("https://telegram.org"))
        let inlineView = makeView(with: [.paragraph(ParagraphBlock(id: BlockID.generate(), style: .body,
                                                                  runs: [TextRun(text: "\u{FFFC}", attributes: attributes)]))])
        var inlineKind: Bool?
        inlineView.onEditButtonRequested = { _, isBlockPill, _ in inlineKind = isBlockPill }
        let canvas = inlineView.canvasForTesting
        guard let region = canvas.allLeafRegions().first,
              let attachmentBox = region.layout.attachmentBox(at: 0) else {
            return XCTFail("expected an inline attachment box")
        }
        let point = CGPoint(x: attachmentBox.midX + region.canvasOrigin.x,
                            y: attachmentBox.midY + region.canvasOrigin.y)
        XCTAssertTrue(canvas.handleButtonTapIfNeeded(at: point))
        XCTAssertEqual(inlineKind, false, "an inline pill reports the inline kind")
    }

    /// Passing nil from the sheet deletes the pill; deleting the last one removes the row.
    func test_editCompletionWithNil_deletesThePill() {
        let view = makeView(with: [.buttonRow(makeRow(["Only"]))])
        view.onEditButtonRequested = { _, _, completion in completion(nil) }
        guard let box = view.canvasForTesting.boxes.compactMap({ $0 as? ButtonRowBox }).first,
              let rect = box.pillCanvasRect(0) else {
            return XCTFail("expected a row with a pill rect")
        }
        _ = view.canvasForTesting.handleButtonTapIfNeeded(at: CGPoint(x: rect.midX, y: rect.midY))
        XCTAssertFalse(view.document.blocks.contains { if case .buttonRow = $0 { return true } else { return false } },
                       "deleting the last pill must remove the row")
    }

    /// With no host listening, a pill tap falls through to normal caret placement.
    func test_pillTap_isInertWithoutAHost() {
        let view = makeView(with: [.buttonRow(makeRow(["A"]))])
        guard let box = view.canvasForTesting.boxes.compactMap({ $0 as? ButtonRowBox }).first,
              let rect = box.pillCanvasRect(0) else {
            return XCTFail("expected a row with a pill rect")
        }
        XCTAssertFalse(view.canvasForTesting.handleButtonTapIfNeeded(at: CGPoint(x: rect.midX, y: rect.midY)))
    }

    // MARK: - The row's "…" menu affordance

    /// The "…" is EDITOR-ONLY chrome. It must be laid out AFTER the packing, never inside it — that
    /// transcription is pinned to the V2 renderer, and a sent message has no such control.
    func test_menuAffordance_sitsAfterTheLastPill() {
        let box = ButtonRowBox(row: makeRow(["A", "B"]), mapper: AttributedStringMapper(), width: 320)
        box.showsMenuAffordance = true
        guard let last = box.pillFrames.last else { return XCTFail("expected pills") }
        XCTAssertGreaterThan(box.menuButtonFrame.minX, last.minX)
        XCTAssertEqual(box.menuButtonFrame.height, ButtonRowBox.menuButtonSide, accuracy: 0.01)
    }

    /// The row RESERVES width for the "…", so it always fits on the last line and never grows the row.
    /// Reserving beats wrapping because the default alignment is `justify`, where pills stretch to fill
    /// the width — an unreserved control would never fit and every row would be two lines tall.
    func test_menuAffordance_alwaysFitsWithoutGrowingTheRow() {
        for (labels, alignment) in [(["A"], ButtonRowAlignment.justify),
                                    (["A", "B", "C"], .justify),
                                    (Array(repeating: "A fairly long button label", count: 4), .left)] {
            let box = ButtonRowBox(row: makeRow(labels, alignment: alignment), mapper: AttributedStringMapper(), width: 320)
            box.showsMenuAffordance = true
            XCTAssertLessThanOrEqual(box.menuButtonFrame.maxY, box.height + 0.01,
                                     "the affordance must sit inside the row (\(labels.count), \(alignment))")
            guard let last = box.pillFrames.last else { continue }
            XCTAssertLessThanOrEqual(last.maxX, box.menuButtonFrame.minX + 0.01,
                                     "pills must not run under the affordance (\(labels.count), \(alignment))")
        }
    }

    /// `measuredHeight` is used for layout sizing and MUST agree with the laid-out `height`, or the row
    /// is framed at one size and drawn at another.
    func test_measuredHeight_agreesWithLaidOutHeight() {
        for labels in [["A"], ["A", "B", "C"], Array(repeating: "A fairly long button label", count: 4)] {
            let box = ButtonRowBox(row: makeRow(labels, alignment: .left), mapper: AttributedStringMapper(), width: 320)
            XCTAssertEqual(box.measuredHeight(forWidth: 320), box.height, accuracy: 0.01,
                           "for \(labels.count) buttons")
        }
    }

    /// Tapping the "…" asks the host for the row menu — the ONLY way to reach it, so a regression here
    /// makes alignment and Add Button unreachable (as they were before this affordance existed).
    func test_tappingTheMenuAffordance_requestsTheRowMenu() {
        let view = makeView(with: [.buttonRow(makeRow(["A"]))])
        var request: ButtonRowMenuRequest?
        view.onRequestButtonRowMenu = { request = $0 }
        restamp(view)
        guard let box = view.canvasForTesting.boxes.compactMap({ $0 as? ButtonRowBox }).first else {
            return XCTFail("expected a row")
        }
        let rect = box.menuButtonCanvasRect()
        XCTAssertTrue(view.canvasForTesting.handleButtonTapIfNeeded(at: CGPoint(x: rect.midX, y: rect.midY)))
        XCTAssertNotNil(request)
        XCTAssertEqual(request?.alignment, .justify)

        // The anchor contract: the host builds a transient anchor view at `sourceRect` INSIDE `view`, so
        // both must be supplied and the rect must be the "…" in the CANVAS's coordinate space. Anchoring
        // to the whole editor instead put the menu offscreen.
        XCTAssertTrue(request?.view === view.canvasForTesting)
        XCTAssertEqual(request?.sourceRect, rect)
        XCTAssertFalse(rect.isEmpty)
    }

    /// Add Button appends a pill to the row.
    func test_addButton_appendsAPill() {
        let view = makeView(with: [.buttonRow(makeRow(["A"]))])
        var request: ButtonRowMenuRequest?
        view.onRequestButtonRowMenu = { request = $0 }
        restamp(view)
        view.onEditButtonRequested = { _, _, _ in }   // the sheet opens for the new pill; leave it pending
        guard let box = view.canvasForTesting.boxes.compactMap({ $0 as? ButtonRowBox }).first else {
            return XCTFail("expected a row")
        }
        let rect = box.menuButtonCanvasRect()
        _ = view.canvasForTesting.handleButtonTapIfNeeded(at: CGPoint(x: rect.midX, y: rect.midY))
        request?.addButton()
        guard case let .buttonRow(restored) = view.document.blocks.first else {
            return XCTFail("expected the row back")
        }
        XCTAssertEqual(restored.buttons.count, 2)
    }

    /// Alignment applies through the menu request.
    func test_menuRequest_setsAlignment() {
        let view = makeView(with: [.buttonRow(makeRow(["A"], alignment: .justify))])
        var request: ButtonRowMenuRequest?
        view.onRequestButtonRowMenu = { request = $0 }
        restamp(view)
        guard let box = view.canvasForTesting.boxes.compactMap({ $0 as? ButtonRowBox }).first else {
            return XCTFail("expected a row")
        }
        let rect = box.menuButtonCanvasRect()
        _ = view.canvasForTesting.handleButtonTapIfNeeded(at: CGPoint(x: rect.midX, y: rect.midY))
        request?.setAlignment(.center)
        guard case let .buttonRow(restored) = view.document.blocks.first else {
            return XCTFail("expected the row back")
        }
        XCTAssertEqual(restored.alignment, .center)
    }

    /// The affordance must not steal a tap meant for a pill.
    func test_pillTap_stillReachesThePill_notTheMenu() {
        let view = makeView(with: [.buttonRow(makeRow(["A", "B"]))])
        var menuRequested = false
        var editRequested = false
        view.onRequestButtonRowMenu = { _ in menuRequested = true }
        view.onEditButtonRequested = { _, _, _ in editRequested = true }
        guard let box = view.canvasForTesting.boxes.compactMap({ $0 as? ButtonRowBox }).first,
              let rect = box.pillCanvasRect(0) else {
            return XCTFail("expected a pill rect")
        }
        _ = view.canvasForTesting.handleButtonTapIfNeeded(at: CGPoint(x: rect.midX, y: rect.midY))
        XCTAssertTrue(editRequested)
        XCTAssertFalse(menuRequested)
    }

    /// The chat composer is preservation-only — it wires no authoring hooks — so it must NOT show the
    /// "…" control. The affordance is gated on a host actually listening, so no extra knob is needed.
    func test_composerHost_showsNoMenuAffordance() {
        let view = makeView(with: [.buttonRow(makeRow(["A"]))])   // no onRequestButtonRowMenu
        guard let box = view.canvasForTesting.boxes.compactMap({ $0 as? ButtonRowBox }).first else {
            return XCTFail("expected a row")
        }
        XCTAssertFalse(box.showsMenuAffordance)
        XCTAssertEqual(box.menuButtonFrame, .zero)
        XCTAssertNil(box.nearestPillIndex(toCanvasPoint: CGPoint(x: -100, y: -100)).flatMap { _ in
            box.hitsMenuButton(atCanvasPoint: CGPoint(x: 0, y: 0)) ? 1 : nil
        }, "a hidden affordance must not hit-test")
    }

    /// And with it hidden, the row reserves NO width — so composer pills are exactly as wide as they
    /// will be in the sent message, which is the whole point of the composer being WYSIWYG.
    func test_composerHost_reservesNoWidthForTheAffordance() {
        let hidden = ButtonRowBox(row: makeRow(["A"]), mapper: AttributedStringMapper(), width: 320)
        XCTAssertFalse(hidden.showsMenuAffordance)
        let shown = ButtonRowBox(row: makeRow(["A"]), mapper: AttributedStringMapper(), width: 320)
        shown.showsMenuAffordance = true

        guard let hiddenPill = hidden.pillFrames.first, let shownPill = shown.pillFrames.first else {
            return XCTFail("expected pills")
        }
        // Justify stretches the pill to the available width, so the reserve is directly visible.
        XCTAssertEqual(hiddenPill.width, 320.0, accuracy: 0.01)
        XCTAssertEqual(shownPill.width, 320.0 - ButtonRowBox.menuButtonReserve, accuracy: 0.01)
    }

    // MARK: - Inner padding gives way to the label

    private func packedAttachments(_ buttons: [ButtonRef], alignment: ButtonRowAlignment = .justify,
                                   width: CGFloat = 320.0) -> [ButtonTextAttachment] {
        let mapper = AttributedStringMapper()
        return richTextPackButtonRow(
            buttons: buttons, alignment: alignment, availableWidth: width,
            metrics: .default, isRTL: false,
            hasIcon: { mapper.buttonHasIcon($0.action) },
            measure: { mapper.buttonAttachment(button: $0, isBlockPill: true, maxWidth: $1, horizontalPadding: $2) }
        ).attachments
    }

    /// A pill's inner padding is a preference, not a constraint: a label that would be ellipsised at the
    /// comfortable padding is re-measured at the minimum, and the room it wins goes to the text.
    func test_aLabelThatDoesNotFit_fallsBackToTheMinimumPadding() {
        // Four ~76pt columns. At 19pt padding that leaves ~38pt of ink — far less than these labels.
        let labels = ["Subscribe now", "Open the website", "Read more", "Contact us"]
        // `.disabled` carries no type badge, so the padding is the ONLY constraint and the full
        // fallback is visible in the label.
        let attachments = packedAttachments(labels.map { ButtonRef(label: [TextRun(text: $0)], action: .disabled) })
        XCTAssertEqual(attachments.count, labels.count)
        for attachment in attachments {
            XCTAssertEqual(attachment.horizontalPadding, RichTextButtonMetrics.default.blockMinimumHorizontalPadding)
        }
    }

    /// And the point of all of it: more of the label survives than before.
    func test_theFallbackFitsMoreOfTheLabel() {
        let label = "Subscribe now"
        let button = ButtonRef(label: [TextRun(text: label)], action: .disabled)
        let mapper = AttributedStringMapper()
        let columnWidth = (320.0 - RichTextButtonMetrics.default.blockSpacing * 3.0) / 4.0

        let comfortable = mapper.buttonAttachment(
            button: button, isBlockPill: true, maxWidth: columnWidth,
            horizontalPadding: RichTextButtonMetrics.default.blockHorizontalPadding)
        guard let packed = packedAttachments(Array(repeating: button, count: 4)).first else {
            return XCTFail("expected a pill")
        }
        XCTAssertTrue(comfortable.isTruncated, "precondition: this label does not fit at the comfortable padding")
        XCTAssertGreaterThan(packed.labelString.length, comfortable.labelString.length)
    }

    /// The fallback only arms where it is needed — a short label keeps the comfortable padding, so a
    /// row of short labels looks exactly as it did.
    func test_aLabelThatFits_keepsTheComfortablePadding() {
        guard let attachment = packedAttachments([ButtonRef(label: [TextRun(text: "Go")], action: .disabled)]).first else {
            return XCTFail("expected a pill")
        }
        XCTAssertFalse(attachment.isTruncated)
        XCTAssertEqual(attachment.horizontalPadding, RichTextButtonMetrics.default.blockHorizontalPadding)
    }

    /// Per BUTTON, not per row: one long label must not tighten its neighbours.
    func test_theFallbackAppliesPerButton() {
        let buttons = [
            ButtonRef(label: [TextRun(text: "Go")], action: .disabled),
            ButtonRef(label: [TextRun(text: "Subscribe to the newsletter")], action: .disabled),
        ]
        let attachments = packedAttachments(buttons)
        XCTAssertEqual(attachments.count, 2)
        XCTAssertEqual(attachments.first?.horizontalPadding, RichTextButtonMetrics.default.blockHorizontalPadding)
        XCTAssertEqual(attachments.last?.horizontalPadding, RichTextButtonMetrics.default.blockMinimumHorizontalPadding)
    }

    /// A link button is chrome-less at 0 padding already, so the fallback must never hand it MORE room
    /// than it started with.
    func test_theFallbackNeverWidensALinkButtonsPadding() {
        let button = ButtonRef(label: [TextRun(text: String(repeating: "long ", count: 40))],
                               action: .disabled, isLink: true)
        guard let attachment = packedAttachments([button]).first else {
            return XCTFail("expected a pill")
        }
        XCTAssertTrue(attachment.isTruncated, "precondition: far too long to fit")
        XCTAssertEqual(attachment.horizontalPadding, 0.0)
    }

    /// The justified path used to clear `padding + reserve` per side where only the LARGER of the two is
    /// occupied, costing a badge-bearing label ~36pt of ink for nothing. The clearance is now the max.
    func test_theBadgeReserveDoesNotStackOnTopOfThePadding() {
        let button = ButtonRef(label: [TextRun(text: "Open")], action: .url("https://telegram.org"))
        let metrics = RichTextButtonMetrics.default
        // A column sized so the label fits with the badge cleared, but NOT if the two stacked.
        let columnWidth = metrics.blockIconReserve * 2.0 + metrics.blockHorizontalPadding * 2.0 + 30.0
        guard let attachment = packedAttachments([button], width: columnWidth).first else {
            return XCTFail("expected a pill")
        }
        XCTAssertFalse(attachment.isTruncated)
        XCTAssertEqual(attachment.horizontalPadding, metrics.blockHorizontalPadding)
    }
}
#endif

