import XCTest
import UIKit
import RichTextInputDecHost
import RichTextInputDecUpstream

/// An accepted autocorrection's blue underline is UIKit's, not the engine's. The keyboard applies
/// the correction as a plain `replaceRange:withText:` and hands the candidate to its text-choice
/// acceleration assistant, which asks the text input for the word's selection rects and places a
/// `_UITextUnderlineView` at each rect's private `baselineOffset`. UIKit's own text input controller
/// stamps that value onto every rect it hands out, from the baseline the layout controller reports
/// through `requestTextGeometryAtPosition:typingAttributes:resultBlock:` — a four-argument block the
/// engine used to invoke with the rect alone, so the stamped baseline was an unset register: infinity
/// on K3, an underline at y = infinity (2026-09-11). Two layers now answer it, and these pin both from
/// the host's side: the stamped value UIKit writes, and the per-line value the engine's rect answers.
@available(iOS 18.4, *)
final class EngineSelectionRectBaselineTests: XCTestCase {
    private var window: UIWindow!
    private var engine: TGIDObservingBlockTextView!
    private let font = UIFont.systemFont(ofSize: 17.0)

    override func setUp() {
        super.setUp()
        engine = TGIDObservingBlockTextView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 240),
            attributedBlocks: [NSAttributedString(string: "hello there world", attributes: [.font: font])])
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(engine)
        window.makeKeyAndVisible()
        engine.layoutIfNeeded()
    }

    override func tearDown() {
        window.isHidden = true
        window = nil
        engine = nil
        super.tearDown()
    }

    private func wordRects() -> [UITextSelectionRect] {
        let start = engine.position(from: engine.beginningOfDocument, offset: 6)!
        let end = engine.position(from: start, offset: 5)!
        return engine.selectionRects(for: engine.textRange(from: start, to: end)!)
    }

    /// The value the assistant reads: the rect's own answer.
    func test_aWordsSelectionRectsAnswerTheLinesBaseline() {
        let rects = wordRects()
        XCTAssertEqual(rects.count, 1)
        for rect in rects {
            let baseline = (rect as NSObject).value(forKey: "baselineOffset") as? CGFloat ?? .nan
            XCTAssertTrue(baseline.isFinite, "baseline \(baseline)")
            XCTAssertGreaterThan(baseline, 0)
            XCTAssertLessThan(baseline, rect.rect.height)
            XCTAssertEqual(baseline, font.ascender, accuracy: 1.0)
        }
    }

    /// The value UIKit's controller stamped into the base class's storage from the engine's
    /// geometry answer — read from the ivar, past the engine's own accessor.
    func test_theControllerStampsAFiniteBaselineIntoTheRectsStorage() {
        guard let ivar = class_getInstanceVariable(UITextSelectionRect.self, "_baselineOffset") else {
            return XCTFail("UITextSelectionRect no longer keeps _baselineOffset")
        }
        let offset = ivar_getOffset(ivar)
        let rects = wordRects()
        XCTAssertEqual(rects.count, 1)
        for rect in rects {
            let stamped = Unmanaged.passUnretained(rect).toOpaque().load(fromByteOffset: offset, as: CGFloat.self)
            let answered = (rect as NSObject).value(forKey: "baselineOffset") as? CGFloat ?? .nan
            XCTAssertTrue(stamped.isFinite, "stamped \(stamped)")
            XCTAssertEqual(stamped, font.ascender, accuracy: 1.0)
            XCTAssertEqual(stamped, answered, accuracy: 1.0)
        }
    }
}
