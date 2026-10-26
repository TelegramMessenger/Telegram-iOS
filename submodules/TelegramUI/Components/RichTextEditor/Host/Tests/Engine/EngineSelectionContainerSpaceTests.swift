import XCTest
import UIKit
import RichTextInputDecHost
import RichTextInputDecUpstream

/// Tapping an autocorrected word opens UIKit's text-choice prompt, and UIKit places it by a route
/// that crosses the engine's coordinate spaces twice. It converts the word's selection rect INTO the
/// selection container (where it hangs its underline view) with
/// `-[_UITextChoiceAccelerationAssistant convertedSelectionRect:]`, then hands those same numbers to
/// the bubble as `presentedFromRect:` beside `referenceTextView:` = `-textInputView` — read back
/// relative to the text input view, with no second conversion. The two spaces have to be one.
///
/// The engine's container was anchored to the editor's `bounds`, so a scrolled composer put them one
/// content offset apart and the prompt came up that far below its word (K3, 2026-09-11: the word at
/// window y 269.3 against a prompt at 337.3, the editor's 68pt top inset). The container now starts
/// where the block stack does.
@available(iOS 18.4, *)
final class EngineSelectionContainerSpaceTests: XCTestCase {
    private var window: UIWindow!
    private var engine: TGIDObservingBlockTextView!
    private let font = UIFont.systemFont(ofSize: 17.0)

    override func setUp() {
        super.setUp()
        engine = TGIDObservingBlockTextView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 240),
            attributedBlocks: [
                NSAttributedString(string: "hello there world", attributes: [.font: font]),
                NSAttributedString(string: "a second line of text", attributes: [.font: font]),
            ])
        engine.contentInsetAdjustmentBehavior = .never
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(engine)
        window.makeKeyAndVisible()
        engine.layoutIfNeeded()
        // What the composer does: reserve room above the text and sit scrolled to the top of it.
        engine.contentInset = UIEdgeInsets(top: 68, left: 0, bottom: 0, right: 0)
        engine.contentOffset = CGPoint(x: 0, y: -68)
        engine.layoutIfNeeded()
    }

    override func tearDown() {
        window.isHidden = true
        window = nil
        engine = nil
        super.tearDown()
    }

    private func view(for selector: String) -> UIView? {
        (engine as NSObject).perform(NSSelectorFromString(selector))?.takeUnretainedValue() as? UIView
    }

    func test_theSelectionContainerAndTheTextInputViewAreOneCoordinateSpace() {
        guard let container = view(for: "selectionContainerView"),
              let textInputView = view(for: "textInputView") else {
            return XCTFail("the engine no longer answers selectionContainerView / textInputView")
        }
        // Without this the assertion below would hold for the wrong reason.
        XCTAssertNotEqual(engine.bounds.origin.y, 0)
        let origin = container.convert(CGPoint.zero, to: textInputView)
        XCTAssertEqual(origin.x, 0, accuracy: 0.001, "\(origin)")
        XCTAssertEqual(origin.y, 0, accuracy: 0.001, "\(origin)")
    }

    /// UIKit's round trip, on a real word's rect: into the container, then read back as if it had
    /// never left the text input view.
    func test_aWordsRectSurvivesUIKitsRoundTripThroughTheContainer() {
        guard let container = view(for: "selectionContainerView"),
              let textInputView = view(for: "textInputView") else {
            return XCTFail("the engine no longer answers selectionContainerView / textInputView")
        }
        let start = engine.position(from: engine.beginningOfDocument, offset: 6)!
        let end = engine.position(from: start, offset: 5)!
        let rects = engine.selectionRects(for: engine.textRange(from: start, to: end)!)
        XCTAssertEqual(rects.count, 1)
        guard let word = rects.first?.rect else { return }
        XCTAssertTrue(word.isFinite())
        let converted = container.convert(word, from: textInputView)
        XCTAssertEqual(converted.origin.x, word.origin.x, accuracy: 0.001, "\(converted)")
        XCTAssertEqual(converted.origin.y, word.origin.y, accuracy: 0.001, "\(converted)")
    }
}

private extension CGRect {
    func isFinite() -> Bool {
        origin.x.isFinite && origin.y.isFinite && width.isFinite && height.isFinite
    }
}
