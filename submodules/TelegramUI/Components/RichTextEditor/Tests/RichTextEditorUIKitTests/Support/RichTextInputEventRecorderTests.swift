#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

@available(iOS 16.0, *)
final class RichTextInputEventRecorderTests: XCTestCase {
    private func makeCanvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Alpha")])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        return v
    }

    func test_pureRead_producesNoEvents() {
        let v = makeCanvas()
        let r = RichTextInputEventRecorder(); r.attach(canvas: v)
        _ = v.text(in: DocumentTextRange(DocumentTextPosition(v.boxes[0].textStart),
                                         DocumentTextPosition(v.boxes[0].textStart + 3)))
        XCTAssertTrace(r, [])
    }

    func test_editingBlock_recordsTheFullBracketInOrder() {
        let v = makeCanvas()
        let r = RichTextInputEventRecorder(); r.attach(canvas: v)
        v.editing { .unchanged }
        // The full cross-source trace for an empty `editing {}` body: the delegate bracket, then
        // `editing`'s unconditional tail (`suppressHostChangeNotification` defaults to false) —
        // `notifyContentSizeChanged()` → `onContentSizeChange?()`, then `onSelectionChange?()` —
        // in that order (verified against DocumentCanvasView+Editing.swift). This is the suite's
        // one genuine proof that a canvas hook is ordered AFTER the delegate bracket in a real
        // interleaved trace, which XCTAssertTrace(r, []) and prefix-based checks cannot show.
        XCTAssertTrace(r, [.textWillChange, .selectionWillChange, .selectionDidChange, .textDidChange,
                           .canvasContentSizeChanged, .canvasSelectionChanged])
    }

    func test_ordinalIsTotalAcrossDelegateAndCanvasHooks() {
        let v = makeCanvas()
        let r = RichTextInputEventRecorder(); r.attach(canvas: v)
        v.setCaret(global: v.boxes[0].textStart)
        v.insertText("x")
        XCTAssertEqual(r.events.map(\.ordinal), Array(0..<r.events.count))
    }

    func test_recordedRevisionAdvancesAcrossTheBracket() {
        let v = makeCanvas()
        let r = RichTextInputEventRecorder(); r.attach(canvas: v)
        v.editing { .unchanged }
        let will = r.events.first { $0.kind == .textWillChange }!
        let did = r.events.first { $0.kind == .textDidChange }!
        XCTAssertEqual(did.revision, will.revision + 1)
    }

    func test_chainingPreservesAPreinstalledContentSizeHook() {
        let v = makeCanvas()
        var chainedCalls = 0
        v.onContentSizeChange = { chainedCalls += 1 }
        let r = RichTextInputEventRecorder(); r.attach(canvas: v)
        v.setCaret(global: v.boxes[0].textStart)
        v.insertText("x")
        XCTAssertGreaterThan(chainedCalls, 0, "the pre-installed hook must still run")
        XCTAssertTrue(r.kinds.contains(.canvasContentSizeChanged))
    }

    func test_simulateParentLayoutStillWorksUnderTheRecorder() {
        let v = makeCanvas()
        v.simulateParentLayout()
        let r = RichTextInputEventRecorder(); r.attach(canvas: v)
        v.setCaret(global: v.boxes[0].textStart)
        v.insertText("x")
        XCTAssertTrue(r.kinds.contains(.canvasContentSizeChanged))
    }

    func test_facadeOnChangeFromASelectionMoveIsAsyncCoalesced() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Alpha Beta")]))])
        editor.layoutIfNeeded()
        let r = RichTextInputEventRecorder()
        r.attach(canvas: editor.canvas); r.attach(facade: editor)
        r.reset()
        editor.canvas.setCaret(global: editor.canvas.boxes[0].textStart + 2)
        XCTAssertFalse(r.kinds.contains(.facadeOnChange), "selection-driven onChange must not be synchronous")
        r.drainMainQueue(self)
        XCTAssertTrue(r.kinds.contains(.facadeOnChange))
        XCTAssertTrue(r.events.first { $0.kind == .facadeOnChange }!.deliveredAsynchronously)
    }

    func test_resetClearsEventsAndOrdinals() {
        let v = makeCanvas()
        let r = RichTextInputEventRecorder(); r.attach(canvas: v)
        v.editing { .unchanged }
        r.reset()
        XCTAssertTrue(r.events.isEmpty)
        v.editing { .unchanged }
        XCTAssertEqual(r.events.first?.ordinal, 0)
    }
}
#endif
