#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

@available(iOS 16.0, *)
final class FacadeCallbackTraceCharacterizationTests: XCTestCase {
    private var recorder: RichTextInputEventRecorder!

    private func makeEditor() -> RichTextEditorView {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Alpha Beta")])),
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "Gamma")])),
        ])
        editor.layoutIfNeeded()
        recorder = RichTextInputEventRecorder()
        recorder.attach(canvas: editor.canvas)
        recorder.attach(facade: editor)
        recorder.reset()
        return editor
    }

    /// A content-size change relays to the facade SYNCHRONOUSLY (RichTextEditorView.swift:258).
    func test_contentSizeChange_relaysToOnChangeSynchronously() {
        let editor = makeEditor()
        editor.canvas.setCaret(global: editor.canvas.boxes[0].textStart)
        recorder.reset()
        editor.canvas.insertText("x")
        let sizeIndex = recorder.kinds.firstIndex(of: .canvasContentSizeChanged)
        let changeIndex = recorder.kinds.firstIndex(of: .facadeOnChange)
        XCTAssertNotNil(sizeIndex); XCTAssertNotNil(changeIndex)
        XCTAssertLessThan(sizeIndex!, changeIndex!)
        XCTAssertFalse(recorder.events[changeIndex!].deliveredAsynchronously)
    }

    /// A selection-only change relays ASYNC-COALESCED (RichTextEditorView.swift:725-733).
    func test_selectionOnlyChange_doesNotRelaySynchronously() {
        let editor = makeEditor()
        editor.canvas.setCaret(global: editor.canvas.boxes[1].textStart)
        XCTAssertTrue(recorder.kinds.contains(.canvasSelectionChanged))
        XCTAssertFalse(recorder.kinds.contains(.facadeOnChange))
        recorder.drainMainQueue(self)
        XCTAssertTrue(recorder.kinds.contains(.facadeOnChange))
    }

    func test_manySelectionMovesInOneRunloopTurn_produceExactlyOneOnChange() {
        let editor = makeEditor()
        for i in 0..<8 { editor.canvas.setCaret(global: editor.canvas.boxes[0].textStart + i) }
        recorder.drainMainQueue(self)
        XCTAssertEqual(recorder.kinds.filter { $0 == .facadeOnChange }.count, 1)
    }

    /// Inside `editing { }` the canvas fires onSelectionChange AFTER textDidChange (+Editing.swift:58).
    func test_editingFiresCanvasSelectionChangeAfterTextDidChange() {
        let editor = makeEditor()
        editor.canvas.setCaret(global: editor.canvas.boxes[0].textStart)
        recorder.reset()
        editor.canvas.insertText("x")
        let textDid = recorder.kinds.firstIndex(of: .textDidChange)
        let selChanged = recorder.kinds.firstIndex(of: .canvasSelectionChanged)
        XCTAssertNotNil(textDid); XCTAssertNotNil(selChanged)
        XCTAssertLessThan(textDid!, selChanged!)
    }
}
#endif
