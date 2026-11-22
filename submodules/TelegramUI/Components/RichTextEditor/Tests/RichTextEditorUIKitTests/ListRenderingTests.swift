#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class ListRenderingTests: XCTestCase {
    private func paragraphStyle(_ block: ParagraphBlock) -> NSParagraphStyle? {
        AttributedStringMapper().attributedString(for: block)
            .attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
    }

    func test_listParagraph_isIndented_plainIsNot() {
        let listed = ParagraphBlock(id: BlockID("a"), list: ListMembership(marker: .bullet),
                                    runs: [TextRun(text: "Item")])
        let plain = ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Item")])
        XCTAssertGreaterThan(paragraphStyle(listed)?.firstLineHeadIndent ?? 0, 0)
        XCTAssertEqual(paragraphStyle(plain)?.firstLineHeadIndent ?? -1, 0)
    }

    func test_deeperLevel_indentsMore() {
        let l0 = ParagraphBlock(id: BlockID("a"), list: ListMembership(marker: .bullet, level: 0),
                                runs: [TextRun(text: "A")])
        let l1 = ParagraphBlock(id: BlockID("b"), list: ListMembership(marker: .bullet, level: 1),
                                runs: [TextRun(text: "B")])
        XCTAssertGreaterThan(paragraphStyle(l1)?.headIndent ?? 0, paragraphStyle(l0)?.headIndent ?? 0)
    }

    func test_markerToTextSpacing_isHalfTheIndentStep() {
        // The marker hangs at the level's indent; the text starts only half a step past it (the
        // bullet→text gap), not a full step as before.
        let listed = ParagraphBlock(id: BlockID("a"), list: ListMembership(marker: .bullet, level: 0),
                                    runs: [TextRun(text: "Item")])
        XCTAssertEqual(paragraphStyle(listed)?.firstLineHeadIndent ?? -1, StyleSheet.listIndentStep / 2, accuracy: 0.5)
        XCTAssertEqual(paragraphStyle(listed)?.headIndent ?? -1, StyleSheet.listIndentStep / 2, accuracy: 0.5)
    }

    func test_perLevelNestingIndent_isUnchanged() {
        // Halving the marker→text gap must NOT change how far each nesting level indents.
        let l0 = ParagraphBlock(id: BlockID("a"), list: ListMembership(marker: .bullet, level: 0), runs: [TextRun(text: "A")])
        let l1 = ParagraphBlock(id: BlockID("b"), list: ListMembership(marker: .bullet, level: 1), runs: [TextRun(text: "B")])
        let step = (paragraphStyle(l1)?.headIndent ?? 0) - (paragraphStyle(l0)?.headIndent ?? 0)
        XCTAssertEqual(step, StyleSheet.listIndentStep, accuracy: 0.5)
    }

    func test_orderedList_textInset_is4ptMoreThanBullet() {
        // A number marker is wider than a bullet, so an ordered item's text gets `orderedListTextInset`
        // more inset than a bullet item's. The marker column is unchanged (only the text shifts right).
        let ordered = ParagraphBlock(id: BlockID("a"), list: ListMembership(marker: .ordered), runs: [TextRun(text: "x")])
        let bullet  = ParagraphBlock(id: BlockID("b"), list: ListMembership(marker: .bullet),  runs: [TextRun(text: "x")])
        let oi = paragraphStyle(ordered)?.firstLineHeadIndent ?? 0
        let bi = paragraphStyle(bullet)?.firstLineHeadIndent ?? 0
        XCTAssertEqual(StyleSheet.orderedListTextInset, 4, accuracy: 0.001)
        XCTAssertEqual(oi - bi, StyleSheet.orderedListTextInset, accuracy: 0.5)
    }

    func test_orderedList_extraInset_appliesToHeadIndent_andIsFlatAcrossLevels() {
        // The +4 is a flat per-item offset (numbers need room regardless of depth); it must also apply to
        // headIndent (wrapped lines) and must NOT change the per-level nesting step.
        let o1 = ParagraphBlock(id: BlockID("a"), list: ListMembership(marker: .ordered, level: 1), runs: [TextRun(text: "x")])
        let b1 = ParagraphBlock(id: BlockID("b"), list: ListMembership(marker: .bullet,  level: 1), runs: [TextRun(text: "x")])
        XCTAssertEqual((paragraphStyle(o1)?.headIndent ?? 0) - (paragraphStyle(b1)?.headIndent ?? 0),
                       StyleSheet.orderedListTextInset, accuracy: 0.5)
    }

    private func canvas(_ blocks: [ParagraphBlock]) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setParagraphs(blocks, width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        return v
    }

    func test_listMarkerLabels_matchCoreNumbering() {
        let v = canvas([
            ParagraphBlock(id: BlockID("a"), list: ListMembership(marker: .ordered), runs: [TextRun(text: "One")]),
            ParagraphBlock(id: BlockID("b"), list: ListMembership(marker: .ordered), runs: [TextRun(text: "Two")]),
            ParagraphBlock(id: BlockID("c"), runs: [TextRun(text: "Plain")]),
            ParagraphBlock(id: BlockID("d"), list: ListMembership(marker: .bullet), runs: [TextRun(text: "Dot")]),
        ])
        let labels = v.listMarkerLabels()
        XCTAssertEqual(labels[BlockID("a")], "1.")
        XCTAssertEqual(labels[BlockID("b")], "2.")
        XCTAssertNil(labels[BlockID("c")])
        XCTAssertEqual(labels[BlockID("d")], "•")
        XCTAssertEqual(labels, ListNumbering.labels(for: v.currentParagraphs()))
    }

    func test_listMarker_isDrawnByBoxDraw_atTheSameOrigin() {
        let v = canvas([
            ParagraphBlock(id: BlockID("a"), list: ListMembership(marker: .ordered), runs: [TextRun(text: "One")]),
        ])
        let box = v.boxes[0] as! BlockBox
        XCTAssertEqual(box.resolvedListMarker, "1.")
        let boxDraw = box.listMarkerDraw()!
        let seamDraw = v.listMarkerDraws().first { $0.id == box.id }!
        XCTAssertEqual(boxDraw.label, seamDraw.label)
        XCTAssertEqual(boxDraw.origin.x, seamDraw.origin.x, accuracy: 0.01)
        XCTAssertEqual(boxDraw.origin.y, seamDraw.origin.y, accuracy: 0.01)
    }

    func test_listMarker_baselineAlignsWithTextFirstLine() {
        // The marker is drawn outside the text storage; its baseline must match the paragraph's first
        // text-line baseline (which lineHeightMultiple shifts down from the natural top).
        let v = canvas([ParagraphBlock(id: BlockID("a"), style: .body,
                                       list: ListMembership(marker: .ordered), runs: [TextRun(text: "Item")])])
        let box = v.boxes[0] as! BlockBox
        let draw = v.listMarkerDraws().first { $0.id == box.id }!
        // str.draw(at:) puts the baseline at origin.y + ascender.
        let markerBaseline = draw.origin.y + draw.font.ascender
        let textBaseline = box.textOrigin.y + (box.layout.firstLineBaselineFromTop ?? 0)
        XCTAssertEqual(markerBaseline, textBaseline, accuracy: 0.5)
    }

    func test_listMarker_sitsOnTheParagraphsFirstBaseline() {
        // Regression guard for the original misalignment (the marker drawn at textOrigin.y, leaving the
        // number floating above the text line). Stated as the invariant that actually matters and
        // survives a metrics change: the marker's baseline IS the paragraph's first text baseline.
        // (It was previously phrased as "below textOrigin due to lineHeightMultiple 1.10" — that
        // mechanism is gone; under the pinned-box model the first baseline is the font's ascender.)
        let v = canvas([ParagraphBlock(id: BlockID("a"), style: .body,
                                       list: ListMembership(marker: .ordered), runs: [TextRun(text: "Item")])])
        let box = v.boxes[0] as! BlockBox
        let draw = v.listMarkerDraws().first { $0.id == box.id }!
        let markerBaseline = draw.origin.y + draw.font.ascender
        let textBaseline = box.textOrigin.y + (box.layout.firstLineBaselineFromTop ?? -1)
        XCTAssertEqual(markerBaseline, textBaseline, accuracy: 0.5,
                       "the marker must share the paragraph's first text baseline")
    }

    func test_listMarkerDraws_oneEntryPerListBox_withLabelAndIndentColumn() {
        let v = canvas([
            ParagraphBlock(id: BlockID("a"), list: ListMembership(marker: .ordered), runs: [TextRun(text: "One")]),
            ParagraphBlock(id: BlockID("c"), runs: [TextRun(text: "Plain")]),
            ParagraphBlock(id: BlockID("d"), list: ListMembership(marker: .bullet, level: 1), runs: [TextRun(text: "Dot")]),
        ])
        let draws = v.listMarkerDraws()
        XCTAssertEqual(draws.count, 2)   // the plain block contributes no marker
        let a = draws.first { $0.id == BlockID("a") }!
        XCTAssertEqual(a.label, "1.")
        XCTAssertEqual(a.origin.x, (v.boxes[0] as! BlockBox).textOrigin.x, accuracy: 0.5)   // level 0 → no indent
        let d = draws.first { $0.id == BlockID("d") }!
        XCTAssertEqual(d.label, "◦")
        XCTAssertEqual(d.origin.x, (v.boxes[2] as! BlockBox).textOrigin.x + StyleSheet.listIndentStep, accuracy: 0.5)  // level 1
    }

    func test_emptyNumberedListItem_markerBaseline_matchesNonEmptyItem() {
        // TextKit's lineHeightMultiple centering (glyphs raised by `centeringDelta`) is reflected in a
        // non-empty item's `firstLineBaselineFromTop`; the EMPTY-item fallback must mirror it too, else the
        // empty item's number sits ~1pt LOWER than a non-empty item's.
        let v = canvas([
            ParagraphBlock(id: BlockID("e"), style: .body, list: ListMembership(marker: .ordered), runs: []),
            ParagraphBlock(id: BlockID("n"), style: .body, list: ListMembership(marker: .ordered), runs: [TextRun(text: "Item")]),
        ])
        let empty = v.boxes[0] as! BlockBox
        let nonEmpty = v.boxes[1] as! BlockBox
        let ed = v.listMarkerDraws().first { $0.id == empty.id }!
        let nd = v.listMarkerDraws().first { $0.id == nonEmpty.id }!
        // Each marker's baseline offset from its OWN text origin (the two boxes sit at different y).
        XCTAssertEqual(ed.origin.y - empty.textOrigin.y, nd.origin.y - nonEmpty.textOrigin.y, accuracy: 0.5,
                       "empty and non-empty numbered markers share the same baseline offset from textOrigin")
    }

    func test_emptyListItem_placeholderBaseline_alignsWithMarker() {
        // On an empty list item the hint placeholder and the marker share one visual line — both must sit
        // at the centered baseline (guards against centering the marker but not the placeholder).
        let v = canvas([ParagraphBlock(id: BlockID("e"), style: .body,
                                       list: ListMembership(marker: .ordered), runs: [])])
        let box = v.boxes[0] as! BlockBox
        let marker = v.listMarkerDraws().first { $0.id == box.id }!
        guard let ph = box.placeholderDraw() else { return XCTFail("expected a list hint placeholder") }
        // Both draw as text (baseline = origin.y + ascender); their baselines must coincide.
        XCTAssertEqual(marker.origin.y + marker.font.ascender, ph.origin.y + ph.font.ascender, accuracy: 0.5,
                       "the empty-item marker and its hint share a baseline")
    }

    func test_emptyListItem_caretRect_isInsetByHeadIndent() {
        // An EMPTY list item lays out no glyphs, so TextKit never applies its firstLineHeadIndent — the
        // caret must still sit at the list's text column (where typed text will appear), not at the page
        // margin to the left of the marker.
        let v = canvas([ParagraphBlock(id: BlockID("a"), style: .body,
                                       list: ListMembership(marker: .bullet), runs: [])])
        let box = v.boxes[0] as! BlockBox
        let caret = v.caretRect(for: DocumentTextPosition(box.textStart))
        XCTAssertEqual(caret.minX, box.textOrigin.x + StyleSheet.listMarkerSpacing, accuracy: 0.5)
    }

    func test_emptyPlainParagraph_caretRect_notInset() {
        // Guard: a plain body paragraph has no head indent, so its empty caret stays at textOrigin.
        let v = canvas([ParagraphBlock(id: BlockID("b"), style: .body, runs: [])])
        let box = v.boxes[0] as! BlockBox
        let caret = v.caretRect(for: DocumentTextPosition(box.textStart))
        XCTAssertEqual(caret.minX, box.textOrigin.x, accuracy: 0.5)
    }

    func test_nonEmptyListItem_caretAtStart_notDoubleIndented() {
        // Once text exists, TextKit lays the glyphs out at the head indent and the caret follows; the
        // empty-line fallback must NOT add the indent a second time.
        let v = canvas([ParagraphBlock(id: BlockID("a"), style: .body,
                                       list: ListMembership(marker: .bullet), runs: [TextRun(text: "Item")])])
        let box = v.boxes[0] as! BlockBox
        let caret = v.caretRect(for: DocumentTextPosition(box.textStart))
        XCTAssertEqual(caret.minX, box.textOrigin.x + StyleSheet.listMarkerSpacing, accuracy: 1.0)
    }

    func test_setList_appliesBulletToTouchedBlocks() {
        let v = canvas([
            ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Alpha")]),
            ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Beta")]),
        ])
        v.setSelectionForTesting(anchor: v.boxes[0].textStart, head: v.boxes[1].textStart + 1)
        v.setList(.bullet)
        XCTAssertEqual((v.boxes[0] as! BlockBox).listMembership?.marker, .bullet)
        XCTAssertEqual((v.boxes[1] as! BlockBox).listMembership?.marker, .bullet)
    }

    func test_setListNil_clearsMembership_andUndoRestoresIt() {
        let v = canvas([ParagraphBlock(id: BlockID("a"), list: ListMembership(marker: .bullet),
                                       runs: [TextRun(text: "Item")])])
        let um = UndoManager(); um.groupsByEvent = false
        v.undoManagerOverride = um
        v.setSelectionForTesting(anchor: v.boxes[0].textStart + 1, head: v.boxes[0].textStart + 1)
        um.beginUndoGrouping(); v.setList(nil); um.endUndoGrouping()
        XCTAssertNil((v.boxes[0] as! BlockBox).listMembership)
        um.undo()
        XCTAssertEqual((v.boxes[0] as! BlockBox).listMembership?.marker, .bullet)
    }
}
#endif
