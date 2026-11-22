import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
import RichTextInputDecUpstream
@testable import RichTextEngineEditor

/// **A run of typed characters undoes as ONE step, like every other text view on the platform.**
///
/// UIKit already implements this: `-[UITextInputController insertText:]` registers its undo as
/// operation type 2 (typing), which routes through
/// `-[UITextInputController coalesceInTextView:actionName:affectedRanges:replacementRange:replacementText:]`
/// and folds the keystroke into the previous typing operation instead of pushing a new one. The
/// engine drives that same controller, so the coalescing is inherited rather than built — but it is
/// CONDITIONAL, and one of its conditions is that nothing else has been registered into the undo
/// manager since the previous keystroke.
///
/// That is what the engine was breaking. `IDInlineTextBaseFontAttributeName` was absent from the
/// engine's `allowedTypingAttributeNames`, so a typed character carried `.font` but not the base
/// face that font derives from; `normalisePresentation` then found the block differing from what the
/// bridge renders and stamped the marker back, and that restyle registers an undo entry. So every
/// keystroke pushed one entry of our own between two typing operations, and UIKit — correctly —
/// refused to coalesce across it. Measured before the fix: `"hello world"` took eleven undos.
///
/// The suite asserts the user-visible property, the mechanism underneath it, and parity with a stock
/// `UITextView` driven identically — the last so that a future UIKit change moves both or neither.
@available(iOS 18.4, *)
final class EngineTypingUndoCoalescingTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
    }

    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func turn() { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
    private func texts() -> [String] { editor.engine.attributedBlocks.map { $0.string } }

    private func loadEmptyParagraph() {
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p0"), runs: []))])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        turn()
    }

    /// Each keystroke is its own run-loop turn, which is what a real keyboard produces — and what
    /// makes this a fair test: `UndoManager.groupsByEvent` closes a group per turn, so if grouping
    /// were the mechanism nothing here could ever coalesce. It is not; the coalescing is the
    /// operation's own, and it spans turns.
    private func type(_ text: String, into insert: (String) -> Void) {
        for character in text { insert(String(character)); turn() }
    }

    // MARK: - The property

    func test_aRunOfTypedCharactersUndoesAsOneStep() {
        loadEmptyParagraph()
        type("hello world") { editor.engine.insertText($0) }
        XCTAssertEqual(texts(), ["hello world"])

        editor.undo()
        turn()
        XCTAssertEqual(texts(), [""], "the typed run came back one character at a time")
        XCTAssertFalse(editor.currentState().canUndo, "the run was more than one undo step")
    }

    func test_theRunIsRedoneAsOneStepToo() {
        loadEmptyParagraph()
        type("hello world") { editor.engine.insertText($0) }
        editor.undo()
        turn()
        XCTAssertEqual(texts(), [""])

        editor.redo()
        turn()
        XCTAssertEqual(texts(), ["hello world"])
        XCTAssertFalse(editor.currentState().canRedo)
    }

    /// The parity that makes the claim "like a native text view" checkable rather than asserted:
    /// the same string, the same per-turn drive, the same number of undos to clear it.
    func test_theEngineMatchesAStockTextViewOnTypingUndoGranularity() {
        let stock = UITextView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        window.addSubview(stock)
        XCTAssertTrue(stock.becomeFirstResponder())
        stock.text = ""
        turn()
        type("hello world") { stock.insertText($0) }
        XCTAssertEqual(stock.text, "hello world", "the oracle did not receive the text")

        var stockUndos = 0
        while stock.undoManager?.canUndo == true, stockUndos < 20 {
            stock.undoManager?.undo(); turn(); stockUndos += 1
            if stock.text.isEmpty { break }
        }
        XCTAssertEqual(stock.text, "", "the oracle never emptied, so its count means nothing")
        stock.resignFirstResponder()
        stock.removeFromSuperview()

        loadEmptyParagraph()
        type("hello world") { editor.engine.insertText($0) }
        var engineUndos = 0
        while editor.currentState().canUndo, engineUndos < 20 {
            editor.undo(); turn(); engineUndos += 1
            if texts() == [""] { break }
        }
        XCTAssertEqual(texts(), [""])
        XCTAssertEqual(engineUndos, stockUndos,
                       "the engine took \(engineUndos) undos to clear what stock cleared in \(stockUndos)")
    }

    // MARK: - The mechanism

    /// The reason the property holds, asserted where it can fail independently of the undo stack:
    /// the marker is in the engine's TYPING ATTRIBUTES, so a typed character arrives carrying it and
    /// settle finds nothing to correct.
    ///
    /// **It must be asserted on the typing attributes and NOT on the resulting text**, which is what
    /// the first version of this test did and why it was wrong: `normalisePresentation` stamps the
    /// marker back at settle, so the finished block carries it either way and the assertion passed
    /// with the fix reverted — a green test over a live defect, and the exact shape this package's
    /// verification notes warn about. The end state is the same; what differs is whether a restyle
    /// had to produce it.
    ///
    /// Reaches `id_behaviorInput` through KVC deliberately. It is in no public header, the allowed
    /// set it owns is the thing under test, and a test is the one place private state is worth
    /// reading — the alternative is asserting a consequence that cannot fail.
    func test_theBaseFontMarkerIsCarriedInTheEnginesTypingAttributes() {
        loadEmptyParagraph()
        type("abc") { editor.engine.insertText($0) }

        let input = (editor.engine as AnyObject).value(forKey: "id_behaviorInput") as? NSObject
        XCTAssertNotNil(input, "the engine's input capability is no longer reachable — re-aim this test")
        let typing = input?.value(forKey: "typingAttributes") as? [NSAttributedString.Key: Any]
        XCTAssertNotNil(typing, "no typing attributes to read")
        XCTAssertNotNil(typing?[NSAttributedString.Key.IDInlineTextBaseFontAttributeName],
                        "typed text carries `.font` but not the base face it derives from, so every "
                        + "keystroke drifts from what the bridge renders and settle restyles it back")
    }
}
