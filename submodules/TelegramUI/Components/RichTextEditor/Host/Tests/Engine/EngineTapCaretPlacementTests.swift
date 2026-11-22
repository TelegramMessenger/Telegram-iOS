import XCTest
import UIKit
import RichTextEditorCore
@testable import RichTextEngineEditor

/// **A tap must place the caret where the finger is.**
///
/// Reported from the device: "in the chat composer often when I tap on the field to focus, it opens
/// context menu like I tapped twice." The menu is real and it is UIKit's, not ours — traced live on
/// K3 with breakpoints on the private text-interaction path:
///
///     _handleMultiTapGesture:            state=Began taps=1      <- ONE physical tap
///       _checkForRepeatedTap:
///         tappedToPositionCursorWithGesture:
///           _UIKeyboardTextSelectionController selectPositionAtPoint:
///             didUpdateSelectionWithGesture:
///               _showSelectionCommandsIfApplicableAfterDelay:     <- the menu
///
/// `didUpdateSelectionWithGesture:` shows the edit menu when the view was ALREADY first responder
/// before the gesture and the caret rect after the tap equals the rect before it — UIKit's "you
/// tapped the caret" affordance. Two facts made a first tap qualify:
///
/// 1. UIKit snapped the tapped position to the word's END. `-[UIResponder
///    _findPleasingWordBoundaryFromPosition:]` returns the enclosing word's start when the tap is
///    within one character of it and its END otherwise, so every tap two or more characters into a
///    word resolves to the same offset. Measured: `closestPositionToPoint pt=(24,17)` ->
///    `_findBoundary in=2` -> `ctrl.setSelectedTextRange start=29`. The engine mapped the point
///    correctly; the snap discarded it.
/// 2. The composer is frequently first responder while it LOOKS unfocused — with the emoji keyboard
///    up the field keeps first responder and swaps its `inputView`. Measured in that state:
///    `wasOriginallyFR=1`, caret unchanged, menu.
///
/// So the caret never moved and UIKit read the tap as a tap on the caret. The decision (2026-09-18)
/// is to place the caret at the tapped character instead: every tap away from the caret then moves
/// it, and the menu is left to the one gesture that is supposed to raise it.
///
/// That is also what the LEGACY canvas has always done — `DocumentCanvasView` handles taps with its
/// own recogniser and places the caret at `closestGlobalPosition(to:)`, so UIKit's selection
/// controller is not in its path and this snap never reached it. The engine inherited the snap
/// because hosting UIKit's private text-interaction machinery is the whole point of it, so this is a
/// parity fix rather than a divergence.
///
/// The snap has exactly ONE caller in UIKitCore — `-[_UIKeyboardTextSelectionController
/// selectPositionAtPoint:granularity:completionHandler:]` — so overriding it changes tap placement
/// and nothing else.
@available(iOS 18.4, *)
final class EngineTapCaretPlacementTests: XCTestCase {
    /// One long token, so a point anywhere inside it belongs to the same word and UIKit's snap has
    /// somewhere far to snap TO. A sentence of short words hides the defect: neighbouring taps land
    /// in different words and the caret moves either way, which is why the composer only misbehaves
    /// on some drafts.
    private let word = "Qwefqwjfiwqjfijqwfjqwpifjiqwe"
    private var window: UIWindow!

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.makeKeyAndVisible()
    }

    override func tearDown() { window.isHidden = true; window = nil; super.tearDown() }

    private func makeEditor() -> RichTextEngineEditorView {
        let editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 120))
        window.addSubview(editor)
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: word)])),
        ])
        editor.setNeedsLayout()
        editor.layoutIfNeeded()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        return editor
    }

    private func makeStockTextView() -> UITextView {
        let view = UITextView(frame: CGRect(x: 0, y: 0, width: 320, height: 120))
        view.text = word
        window.addSubview(view)
        view.setNeedsLayout()
        view.layoutIfNeeded()
        return view
    }

    private func position(_ input: UITextInput, at offset: Int) -> UITextPosition {
        guard let position = input.position(from: input.beginningOfDocument, offset: offset) else {
            XCTFail("no position at offset \(offset)")
            return input.beginningOfDocument
        }
        return position
    }

    private func offset(_ input: UITextInput, of position: UITextPosition) -> Int {
        input.offset(from: input.beginningOfDocument, to: position)
    }

    /// The defect itself, at the seam UIKit consults. A tap five characters into the word must stay
    /// five characters in.
    func test_aTapInsideAWordKeepsTheTappedCharacter() {
        let engine = makeEditor().engine
        let tapped = position(engine, at: 5)

        let snapped = engine._findBoundaryPositionClosest(to: tapped, with: .word)

        XCTAssertNotNil(snapped, "a nil boundary means the tap is dropped and the caret never moves")
        XCTAssertEqual(offset(engine, of: snapped!), 5,
                       "the tap was snapped away from the tapped character, to offset "
                       + "\(offset(engine, of: snapped!)) of \(word.count)")
    }

    /// Driven the way the tap itself is: point -> position -> snap. This is the whole of what
    /// `selectPositionAtPoint:` does before it assigns the selection, so a pass here is a pass for
    /// the gesture. Asserting the seam alone would not catch a point-mapping regression underneath.
    func test_theSamePointTappedTwiceApartResolvesToTwoDifferentPositions() {
        let engine = makeEditor()
        let input = engine.engine

        func resolve(offsetOfCaret: Int) -> Int {
            let caret = input.caretRect(for: position(input, at: offsetOfCaret))
            let point = CGPoint(x: caret.midX, y: caret.midY)
            guard let mapped = input.closestPosition(to: point) else {
                XCTFail("the engine could not map \(point) back to a position")
                return -1
            }
            let snapped = input._findBoundaryPositionClosest(to: mapped, with: .word)
            return snapped.map { offset(input, of: $0) } ?? -1
        }

        let near = resolve(offsetOfCaret: 3)
        let far = resolve(offsetOfCaret: 20)

        XCTAssertNotEqual(near, far,
                          "two taps 17 characters apart in the same word both resolved to \(near); "
                          + "the caret cannot move, so UIKit raises the edit menu instead")
    }

    /// **The control, and the reason this file has one.** This is UIKit's own rule, measured on a
    /// stock text view built from the same string in the same window: a tap five characters into the
    /// word lands on the word's END. It is here so the assertion above cannot quietly become
    /// vacuous — if Apple ever stops snapping, this fails and says so, rather than leaving a test
    /// that passes because there was nothing left to override.
    func test_uikitsOwnRuleSnapsThatTapToTheWordsEnd_control() {
        let stock = makeStockTextView()
        let tapped = position(stock, at: 5)

        let snapped = stock._findBoundaryPositionClosest(to: tapped, with: .word)

        XCTAssertNotNil(snapped)
        XCTAssertEqual(offset(stock, of: snapped!), word.count,
                       "UIKit no longer snaps a mid-word tap to the word's end, so the engine's "
                       + "override is no longer a deviation and the test above proves nothing")
    }

    /// The override is narrow on purpose: only the granularity the tap path passes. Everything else
    /// — notably the document granularity UIKit substitutes for secure fields — must still be
    /// UIKit's answer, so it is asserted against the same stock view.
    func test_onlyTheWordGranularityIsIntercepted() {
        let engine = makeEditor().engine
        let stock = makeStockTextView()

        for granularity: UITextGranularity in [.character, .sentence, .paragraph, .line, .document] {
            let fromEngine = engine._findBoundaryPositionClosest(
                to: position(engine, at: 5), with: granularity)
            let fromStock = stock._findBoundaryPositionClosest(
                to: position(stock, at: 5), with: granularity)

            XCTAssertEqual(fromEngine.map { offset(engine, of: $0) },
                           fromStock.map { offset(stock, of: $0) },
                           "granularity \(granularity.rawValue) diverges from UIKit's own answer")
        }
    }
}
