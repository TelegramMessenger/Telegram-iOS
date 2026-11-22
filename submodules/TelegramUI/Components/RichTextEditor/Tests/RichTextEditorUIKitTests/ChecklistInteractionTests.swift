#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class ChecklistInteractionTests: XCTestCase {
    private func canvas(_ blocks: [ParagraphBlock]) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setParagraphs(blocks, width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        v.layoutIfNeeded()
        return v
    }

    func test_setList_checklist_seedsUncheckedState() {
        let v = canvas([ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Buy milk")])])
        v.setSelectionForTesting(anchor: v.boxes[0].textStart, head: v.boxes[0].textStart + 1)
        v.setList(.checklist)
        let m = (v.boxes[0] as! BlockBox).listMembership
        XCTAssertEqual(m?.marker, .checklist)
        XCTAssertEqual(m?.checked, false, "a fresh checklist item is unchecked (false, not nil)")
    }

    func test_setList_checklist_preservesCheckedState_onReapply() {
        let v = canvas([ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Buy milk")])])
        v.setSelectionForTesting(anchor: v.boxes[0].textStart, head: v.boxes[0].textStart + 1)
        v.setList(.checklist)
        (v.boxes[0] as! BlockBox).listMembership = ListMembership(marker: .checklist, level: 0, checked: true)
        v.setList(.checklist)   // re-apply must NOT uncheck
        XCTAssertEqual((v.boxes[0] as! BlockBox).listMembership?.checked, true)
    }
}

extension ChecklistInteractionTests {
    func test_returnInCheckedItem_newItemIsUnchecked() {
        let v = canvas([ParagraphBlock(id: BlockID("a"),
                                       list: ListMembership(marker: .checklist, level: 0, checked: true),
                                       runs: [TextRun(text: "Done thing")])])
        _ = v.becomeFirstResponder()
        // Caret at end of the (checked) item, then Return.
        v.setCaret(global: v.boxes[0].textStart + v.boxes[0].textLength)
        v.insertParagraphBreak()
        XCTAssertEqual(v.boxes.count, 2)
        XCTAssertEqual((v.boxes[0] as! BlockBox).listMembership?.checked, true, "original item keeps its checked state")
        let lower = (v.boxes[1] as! BlockBox).listMembership
        XCTAssertEqual(lower?.marker, .checklist)
        XCTAssertEqual(lower?.checked, false, "the continuation item starts unchecked")
    }
}

extension ChecklistInteractionTests {
    func test_checklistMarkerCanvasRect_isPositionedInGutter() {
        let v = canvas([ParagraphBlock(id: BlockID("a"),
                                       list: ListMembership(marker: .checklist, level: 0, checked: false),
                                       runs: [TextRun(text: "Task")])])
        let box = v.boxes[0] as! BlockBox
        guard let rect = box.checklistMarkerCanvasRect() else { return XCTFail("expected a marker rect") }
        let font = StyleSheet().font(for: .body, attributes: .plain)
        let expectedSide = StyleSheet.checklistMarkerSize(for: font) * StyleSheet.checklistMarkerScale
        // Pixel-snapping may reduce the side by up to 1pt, so allow 1pt tolerance.
        XCTAssertEqual(rect.width, expectedSide, accuracy: 1.0, "checkbox is sized to 1.4× font capHeight")
        XCTAssertEqual(rect.height, expectedSide, accuracy: 1.0, "checkbox is square")
        XCTAssertGreaterThanOrEqual(rect.minX, box.frame.minX, "marker sits within the box")
        XCTAssertLessThan(rect.minX, box.frame.minX + 60, "marker is in the left gutter, not mid-text")
        // `canvas(...)` registers NO checkbox provider, so the glyph is NOT suppressed — suppression
        // (and the hosted CheckNode) requires a registered provider. Documents that contract.
        XCTAssertFalse(box.hostsChecklistCheckbox, "no provider registered ⇒ glyph still drawn")
    }

    func test_checklistCheckbox_scaledAndCenterPreserved_leftAnchored() {
        let v = canvas([ParagraphBlock(id: BlockID("a"),
                                       list: ListMembership(marker: .checklist, level: 0, checked: false),
                                       runs: [TextRun(text: "Task")])])
        let box = v.boxes[0] as! BlockBox
        guard let rect = box.checklistMarkerCanvasRect() else { return XCTFail("expected a marker rect") }
        let font = box.mapper.styleSheet.font(for: box.style, attributes: .plain)
        let baseSide = StyleSheet.checklistMarkerSize(for: font)
        // 1.4× size (pixel-snapped, so allow ~1pt tolerance)
        XCTAssertEqual(rect.width, baseSide * StyleSheet.checklistMarkerScale, accuracy: 1.0, "1.4x size")
        XCTAssertEqual(rect.height, rect.width, accuracy: 0.01, "square")
        // left edge anchored at the marker gutter (pixel-snapped, ~1pt)
        XCTAssertEqual(rect.minX, box.textOrigin.x, accuracy: 1.0, "left edge anchored, grows right")
        // vertical center preserved at the base (bottom-on-baseline) box center = baseline - baseSide/2
        let baseline = box.textOrigin.y + box.listMarkerBaselineFromTop(markerFont: font)
        let baseCenter = baseline - baseSide / 2
        XCTAssertEqual(rect.midY, baseCenter, accuracy: 1.0, "vertical center preserved (grows top & bottom)")
        // grows BELOW the baseline (the box now extends below it)
        XCTAssertGreaterThan(rect.maxY, baseline, "extends below the baseline")
    }

    func test_bulletBox_hasNoChecklistMarkerRect() {
        let v = canvas([ParagraphBlock(id: BlockID("a"),
                                       list: ListMembership(marker: .bullet, level: 0),
                                       runs: [TextRun(text: "Item")])])
        XCTAssertNil((v.boxes[0] as! BlockBox).checklistMarkerCanvasRect())
    }
}

extension ChecklistInteractionTests {
    /// checklist text indent must clear the full SCALED checkbox (not just the 12pt listMarkerSpacing).
    func test_checklistItem_textClearsTheCheckbox() {
        let sheet = StyleSheet()
        let bodyFont = sheet.font(for: .body, attributes: .plain)
        let scaledMarkerSize = StyleSheet.checklistMarkerSize(for: bodyFont) * StyleSheet.checklistMarkerScale
        let ps = sheet.paragraphStyle(for: .body, attributes: ParagraphAttributes(),
                                      list: ListMembership(marker: .checklist, level: 0))
        XCTAssertGreaterThanOrEqual(ps.headIndent, scaledMarkerSize,
            "checklist text must start at/after the scaled checkbox's right edge (\(scaledMarkerSize)pt)")
        let bulletPS = sheet.paragraphStyle(for: .body, attributes: ParagraphAttributes(),
                                            list: ListMembership(marker: .bullet, level: 0))
        XCTAssertGreaterThan(ps.headIndent, bulletPS.headIndent,
            "checklist reserves more text inset than a bullet (scaled checkbox is wider than a bullet glyph)")
    }
}

extension ChecklistInteractionTests {
    func test_indentOutdent_preservesCheckedState() {
        let v = canvas([ParagraphBlock(id: BlockID("a"),
                                       list: ListMembership(marker: .checklist, level: 0, checked: true),
                                       runs: [TextRun(text: "Task")])])
        v.setSelectionForTesting(anchor: v.boxes[0].textStart, head: v.boxes[0].textStart)
        v.indent()
        XCTAssertEqual((v.boxes[0] as! BlockBox).listMembership?.level, 1)
        XCTAssertEqual((v.boxes[0] as! BlockBox).listMembership?.checked, true, "indent must preserve checked")
        v.outdent()
        XCTAssertEqual((v.boxes[0] as! BlockBox).listMembership?.level, 0)
        XCTAssertEqual((v.boxes[0] as! BlockBox).listMembership?.checked, true, "outdent must preserve checked")
    }
}

extension ChecklistInteractionTests {
    final class StubCheckbox: UIView, RichTextChecklistMarkerView {
        private(set) var checked: Bool
        private(set) var lastAnimated: Bool?
        init(checked: Bool) { self.checked = checked; super.init(frame: .zero) }
        required init?(coder: NSCoder) { fatalError() }
        func setChecked(_ checked: Bool, animated: Bool) { self.checked = checked; self.lastAnimated = animated }
    }

    func test_checklistMarkerViewProvider_isStoredAndInvoked() {
        let v = DocumentCanvasView()
        var calls = 0
        v.checklistMarkerViewProvider = { checked, _ in calls += 1; return StubCheckbox(checked: checked) }
        let view = v.checklistMarkerViewProvider?(true, CGSize(width: 18, height: 18))
        XCTAssertEqual(calls, 1)
        XCTAssertEqual((view as? StubCheckbox)?.checked, true)
    }
}

extension ChecklistInteractionTests {
    private func canvasWithCheckboxProvider(_ blocks: [ParagraphBlock]) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.checklistMarkerViewProvider = { checked, _ in StubCheckbox(checked: checked) }
        v.setParagraphs(blocks, width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        v.layoutIfNeeded()
        return v
    }

    private func markerTapPoint(_ box: BlockBox) -> CGPoint {
        let r = box.checklistMarkerCanvasRect()!
        return CGPoint(x: r.midX, y: r.midY)
    }

    func test_tapOnMarker_togglesChecked_oneUndoStep_noCaretMove() {
        let v = canvasWithCheckboxProvider([
            ParagraphBlock(id: BlockID("a"),
                           list: ListMembership(marker: .checklist, level: 0, checked: false),
                           runs: [TextRun(text: "Task")])])
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        v.syncChecklistMarkerViews()
        _ = v.becomeFirstResponder()
        v.setCaret(global: v.boxes[0].textStart + 2)
        let caretBefore = v.head
        var changes = 0
        v.onContentSizeChange = { changes += 1 }   // proxy for onChange firing

        let box = v.boxes[0] as! BlockBox
        um.beginUndoGrouping(); v.performSingleTap(at: markerTapPoint(box)); um.endUndoGrouping()

        XCTAssertEqual(box.listMembership?.checked, true, "marker tap checks the item")
        XCTAssertEqual(v.head, caretBefore, "a marker tap does not move the caret")
        XCTAssertEqual((v.checklistMarkerViews[BlockID("a")]?.view as? StubCheckbox)?.checked, true)
        XCTAssertGreaterThan(changes, 0, "onChange fired at least once")

        // Re-install the production relay (a content-size change re-runs layout → syncChecklistMarkerViews),
        // so undo drives a real layout pass the way the parent does at runtime. (Overwrites the counter hook,
        // which has already done its job above.)
        v.simulateParentLayout()
        v.effectiveUndoManager?.undo()
        XCTAssertEqual((v.boxes[0] as! BlockBox).listMembership?.checked, false, "undo restores unchecked")
        XCTAssertEqual((v.checklistMarkerViews[BlockID("a")]?.view as? StubCheckbox)?.checked, false,
                       "undo re-syncs the checkbox view to unchecked")
    }

    func test_tapOnText_doesNotToggle() {
        let v = canvasWithCheckboxProvider([
            ParagraphBlock(id: BlockID("a"),
                           list: ListMembership(marker: .checklist, level: 0, checked: false),
                           runs: [TextRun(text: "Task")])])
        v.syncChecklistMarkerViews()
        _ = v.becomeFirstResponder()
        let box = v.boxes[0] as! BlockBox
        // A point well to the right of the marker, on the text.
        v.performSingleTap(at: CGPoint(x: box.frame.minX + 120, y: box.checklistMarkerCanvasRect()!.midY))
        XCTAssertEqual(box.listMembership?.checked, false, "tapping the text leaves checked unchanged")
    }

    func test_checklistBox_hostsOneCheckboxView_atMarkerRect() {
        let v = canvasWithCheckboxProvider([
            ParagraphBlock(id: BlockID("a"),
                           list: ListMembership(marker: .checklist, level: 0, checked: true),
                           runs: [TextRun(text: "Task")])])
        v.syncChecklistMarkerViews()
        XCTAssertEqual(v.checklistMarkerViews.count, 1)
        let hosted = v.checklistMarkerViews[BlockID("a")]
        XCTAssertEqual((hosted?.view as? StubCheckbox)?.checked, true)
        // Compared component-wise with a tolerance: exact CGRect equality trips on a ~1e-15 difference
        // in the accumulated inset arithmetic, which is float noise rather than a placement change.
        let expected = (v.boxes[0] as! BlockBox).checklistMarkerCanvasRect()
        let actual = hosted?.view.frame
        XCTAssertEqual(actual?.minX ?? .nan, expected?.minX ?? .nan, accuracy: 0.01)
        XCTAssertEqual(actual?.minY ?? .nan, expected?.minY ?? .nan, accuracy: 0.01)
        XCTAssertEqual(actual?.width ?? .nan, expected?.width ?? .nan, accuracy: 0.01)
        XCTAssertEqual(actual?.height ?? .nan, expected?.height ?? .nan, accuracy: 0.01)
    }

    func test_removingChecklist_removesCheckboxView() {
        let v = canvasWithCheckboxProvider([
            ParagraphBlock(id: BlockID("a"),
                           list: ListMembership(marker: .checklist, level: 0, checked: false),
                           runs: [TextRun(text: "Task")])])
        v.syncChecklistMarkerViews()
        XCTAssertEqual(v.checklistMarkerViews.count, 1)
        v.setSelectionForTesting(anchor: v.boxes[0].textStart, head: v.boxes[0].textStart + 1)
        v.setList(nil)
        v.syncChecklistMarkerViews()
        XCTAssertEqual(v.checklistMarkerViews.count, 0)
    }
}
#endif
