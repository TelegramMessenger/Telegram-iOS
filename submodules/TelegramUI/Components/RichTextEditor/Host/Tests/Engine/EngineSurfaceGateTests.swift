import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// The gate at the host view's UITextInput surface (surface-gate spec §3.1): consulted before the
/// controller edits, with the canonical range and text; a veto leaves no trace.
@available(iOS 18.4, *)
final class EngineSurfaceGateTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!
    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 320))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { editor.engine.tgid_textInputGate = nil; window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    func texts() -> [String] { editor.engine.attributedBlocks.map { $0.string.replacingOccurrences(of: "\u{2028}", with: "⏎") } }
    func canUndo() -> Bool { editor.engine.undoManager?.canUndo ?? false }
    func load(_ strings: [String]) {
        editor.document = Document(blocks: strings.enumerated().map { .paragraph(ParagraphBlock(id: BlockID("p\($0.offset)"), runs: [TextRun(text: $0.element)])) })
        XCTAssertTrue(editor.engine.becomeFirstResponder())
    }

    func test_theGateSeesTheCanonicalRangeAndTextOfAnInsertAndAReplace() {
        load(["alpha", "beta"])
        var seen: [(NSRange, String)] = []
        editor.engine.tgid_textInputGate = { range, text in seen.append((range, text)); return text }
        editor.engineSelectedRange = NSRange(location: 2, length: 0)
        editor.engine.insertText("x")
        editor.engine.replace(editor.engine.textRange(from: editor.engine.position(from: editor.engine.beginningOfDocument, offset: 7)!,
                                                      to: editor.engine.position(from: editor.engine.beginningOfDocument, offset: 9)!)!, withText: "BE")
        XCTAssertEqual(seen.map { $0.0 }, [NSRange(location: 2, length: 0), NSRange(location: 7, length: 2)])
        XCTAssertEqual(seen.map { $0.1 }, ["x", "BE"])
        XCTAssertEqual(texts(), ["alxpha", "BEta"])
    }

    func test_aVetoLeavesTextCaretAndUndoUntouched() {
        load(["alpha", "beta"])
        editor.engine.tgid_textInputGate = { _, text in text == "\n" ? nil : text }
        editor.engineSelectedRange = NSRange(location: 2, length: 0)
        editor.engine.insertText("\n")
        XCTAssertEqual(texts(), ["alpha", "beta"])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 2, length: 0))
        XCTAssertFalse(canUndo(), "nothing was recorded")
    }

    func test_aTransformForwardsTheReturnedTextAsOneEdit() {
        load(["alpha", "beta"])
        editor.engine.tgid_textInputGate = { _, text in text == "\n" ? "\u{2028}" : text }
        editor.engineSelectedRange = NSRange(location: 2, length: 0)
        editor.engine.insertText("\n")
        XCTAssertEqual(texts(), ["al⏎pha", "beta"], "one block, one line separator, no retry")
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 3, length: 0))
        XCTAssertTrue(canUndo())
        editor.engine.undoManager?.undo()
        XCTAssertEqual(texts(), ["alpha", "beta"])
    }

    func test_ownEditsIssuedFromTheGateShareOneUndoGroupWithNothingForwarded() {
        load(["alpha", "beta"])
        editor.engine.tgid_textInputGate = { [weak self] _, text in
            guard let self, text == "\n" else { return text }
            self.editor.replaceFlat(NSRange(location: 10, length: 0), with: "Z")
            self.editor.replaceFlat(NSRange(location: 11, length: 0), with: "!")
            return nil
        }
        editor.engineSelectedRange = NSRange(location: 2, length: 0)
        editor.engine.insertText("\n")
        XCTAssertEqual(texts(), ["alpha", "betaZ!"])
        editor.engine.undoManager?.undo()
        XCTAssertEqual(texts(), ["alpha", "beta"], "one group for both")
        XCTAssertFalse(canUndo())
    }

    func test_markedTextBypassesTheGate() {
        load(["alpha", "beta"])
        var calls = 0
        editor.engine.tgid_textInputGate = { _, text in calls += 1; return text }
        editor.engineSelectedRange = NSRange(location: 5, length: 0)
        editor.engine.setMarkedText("か", selectedRange: NSRange(location: 1, length: 0))
        editor.engine.setMarkedText("かん", selectedRange: NSRange(location: 2, length: 0))
        editor.engine.unmarkText()
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(texts(), ["alphaかん", "beta"])
    }

    func test_theControllersOwnInsertBypassesTheGate() {
        // The dictation shape: text arrives at the controller, not at the view's surface.
        load(["alpha", "beta"])
        var calls = 0
        editor.engine.tgid_textInputGate = { _, text in calls += 1; return text }
        editor.engineSelectedRange = NSRange(location: 5, length: 0)
        let controller = editor.engine.value(forKey: "id_behaviorInput") as AnyObject
        _ = controller.perform(#selector(UIKeyInput.insertText(_:)), with: "x")
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(texts(), ["alphax", "beta"])
    }
}
