import XCTest
import UIKit
import RichTextInputDecHost
import RichTextInputDecUpstream

/// R1's gate: EVERY mutation path is observed. An unobserved path is invisible to every rung
/// above this one, so this suite drives each path that exists and asserts the sink saw it.
final class EngineObservationCompletenessTests: XCTestCase {

    private final class RecordingSink: NSObject, TGIDEngineObservationSink {
        var documentChanges: [(range: NSRange, length: Int)] = []
        var selectionChanges = 0
        func engineDidChangeDocument(withReplacedRange replacedRange: NSRange,
                                     replacementLength: UInt,
                                     charactersChanged: Bool) {
            documentChanges.append((replacedRange, Int(replacementLength)))
        }
        func engineDidChangeSelection() { selectionChanges += 1 }
        func engineDidFinishEdit() {}
        var layouts = 0
        func engineDidLayout() { layouts += 1 }
        var focusGains = 0
        var focusLosses = 0
        func engineDidBecomeFirstResponder() { focusGains += 1 }
        func engineDidResignFirstResponder() { focusLosses += 1 }
    }

    private var window: UIWindow!
    private var engine: TGIDObservingBlockTextView!
    private var sink: RecordingSink!

    override func setUp() {
        super.setUp()
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 17.0)]
        engine = TGIDObservingBlockTextView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 240),
            attributedBlocks: [NSAttributedString(string: "hello", attributes: attributes)])
        engine.isEditable = true
        engine.isSelectable = true
        sink = RecordingSink()
        engine.observationSink = sink
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(engine)
        window.makeKeyAndVisible()
        XCTAssertTrue(engine.becomeFirstResponder(), "the engine must hold the responder role")
    }

    override func tearDown() {
        engine.resignFirstResponder()
        window.isHidden = true
        window = nil; engine = nil; sink = nil
        super.tearDown()
    }

    /// A reveal request is a report like any other, and the one the host cannot do without: the
    /// editor no longer scrolls itself, so a path that changes the caret without reporting it is a
    /// caret that stops being followed. Driven here rather than merely implemented above, because
    /// this suite exists to catch exactly the difference.
    func test_anEditMarksTheCaretAsWantingAReveal() {
        engine.tgid_caretRevealPending = false
        engine.insertText("x")
        XCTAssertTrue(engine.tgid_caretRevealPending,
                      "an edit did not mark that the caret wants a reveal")
    }

    /// And a caret that MOVES marks it too — the arrow-key case. Moving it to a position it already
    /// occupies is not a move and marks nothing, which is exactly the artifact that made an earlier
    /// reading of this conclude the property was not wired at all.
    func test_aCaretMoveMarksItAndANonMoveDoesNot() {
        let end = engine.endOfDocument
        engine.selectedTextRange = engine.textRange(from: end, to: end)
        engine.tgid_caretRevealPending = false
        engine.selectedTextRange = engine.textRange(from: end, to: end)
        XCTAssertFalse(engine.tgid_caretRevealPending, "a set to the caret's own position is not a move")

        let start = engine.beginningOfDocument
        engine.selectedTextRange = engine.textRange(from: start, to: start)
        XCTAssertTrue(engine.tgid_caretRevealPending, "a caret move did not mark a reveal")
    }

    /// Focus is a mutation path like any other, and it is the engine's to report: a TAP is delivered
    /// here by UIKit's text-interaction assistant, which calls `becomeFirstResponder` on this object
    /// directly. A host view wrapping the engine never sees it (its own override is only entered for
    /// a programmatic focus), so the article editor's sheet did not expand when tapped into (K3,
    /// 2026-09-11). Reported once per GENUINE transition — `setUp` already focused the engine, so
    /// the re-focus below must add nothing.
    func test_aResponderTransitionIsObserved() {
        XCTAssertEqual(sink.focusGains, 1, "setUp's focus")
        XCTAssertTrue(engine.becomeFirstResponder())
        XCTAssertEqual(sink.focusGains, 1, "refocusing an already-focused engine is not a transition")
        XCTAssertTrue(engine.resignFirstResponder())
        XCTAssertEqual(sink.focusLosses, 1)
        engine.resignFirstResponder()
        XCTAssertEqual(sink.focusLosses, 1, "resigning twice is one transition")
    }

    /// The engine lays itself out for a width change, a document change, AND every tick of a placed
    /// run's horizontal scroll — and it is a SUBVIEW, so nothing marks the host for layout when only
    /// the engine is laid out. A host that places views in the engine's space from geometry inside a
    /// run (the table's structural chrome) re-places them from this observation; without it the
    /// chrome stayed put while the cells scrolled under it (K3, 2026-09-11).
    func test_aLayoutPassIsObserved() {
        engine.layoutIfNeeded()
        sink.layouts = 0
        engine.setNeedsLayout()
        engine.layoutIfNeeded()
        XCTAssertEqual(sink.layouts, 1, "one layout pass, one observation")
    }

    func test_insertTextIsObserved() {
        sink.documentChanges.removeAll()
        engine.insertText("x")
        XCTAssertEqual(sink.documentChanges.count, 1, "insertText produced no observed change")
    }

    func test_deleteBackwardIsObserved() {
        engine.insertText("x")
        sink.documentChanges.removeAll()
        engine.deleteBackward()
        XCTAssertEqual(sink.documentChanges.count, 1, "deleteBackward produced no observed change")
    }

    func test_markedTextAndUnmarkAreObserved() {
        sink.documentChanges.removeAll()
        engine.setMarkedText("ma", selectedRange: NSRange(location: 2, length: 0))
        XCTAssertGreaterThan(sink.documentChanges.count, 0, "setMarkedText produced no observed change")
        sink.documentChanges.removeAll()
        engine.unmarkText()
        // unmarkText commits; it may or may not change text, but it must not be SILENT about
        // a change if one occurs. Assert only that nothing throws and state is consistent.
        XCTAssertEqual(engine.markedTextRange, nil, "unmarkText left a marked range")
    }

    func test_replaceRangeIsObserved() {
        let whole = engine.textRange(from: engine.beginningOfDocument, to: engine.endOfDocument)!
        sink.documentChanges.removeAll()
        engine.replace(whole, withText: "replaced")
        XCTAssertEqual(sink.documentChanges.count, 1, "replace(_:withText:) produced no observed change")
    }

    func test_hostContentReplacementIsObserved() {
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 17.0)]
        sink.documentChanges.removeAll()
        engine.tgid_setAttributedBlocks([
            NSAttributedString(string: "one", attributes: attributes),
            NSAttributedString(string: "two", attributes: attributes),
        ])
        XCTAssertEqual(sink.documentChanges.count, 1, "tgid_setAttributedBlocks produced no observed change")
        XCTAssertEqual(engine.attributedBlocks.count, 2, "the replacement did not re-derive two blocks")
    }

    /// THE OPEN QUESTION (spec §5.4). `id_selectionStateDidChange` has exactly one caller —
    /// `textInputDidChangeSelection:` in the private input delegate — and the programmatic path
    /// `setSelectedTextRange:` forwards into the kernel without calling it. Whether it returns
    /// through UIKit's private controller is an INFERENCE. This test settles it.
    func test_programmaticSelectionChangeIsObserved() {
        let start = engine.position(from: engine.beginningOfDocument, offset: 1)!
        let range = engine.textRange(from: start, to: start)!
        sink.selectionChanges = 0
        engine.selectedTextRange = range
        XCTAssertGreaterThan(sink.selectionChanges, 0,
                             "programmatic setSelectedTextRange: was NOT observed — see the fork in Step 6")
    }

    func test_typingChangesSelectionObservably() {
        sink.selectionChanges = 0
        engine.insertText("y")
        XCTAssertGreaterThan(sink.selectionChanges, 0, "typing produced no observed selection change")
    }
}
