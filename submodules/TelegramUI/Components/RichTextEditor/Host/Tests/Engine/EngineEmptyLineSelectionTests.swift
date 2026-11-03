import XCTest
import UIKit
import RichTextInputDecHost
import RichTextInputDecUpstream

/// A selection that touches an empty line is still drawn.
///
/// Reported from K3 as "the selection is not visible if at least one of the selected lines is
/// empty". The mechanism is not emptiness: it is that the selection's boundary lands on a
/// PARAGRAPH BREAK. The engine offers every structural separator to both of its sides — the block
/// before it is asked to extend its tail, the block after it to extend its head, under the one
/// condition that the separator's offset is selected — and the head side answered with a
/// zero-width rect, which the geometry layer reported as a failure to measure. One such answer
/// discarded the selection geometry for the WHOLE document, so UIKit drew nothing at all.
///
/// An empty line has exactly one offset, so every selection that touches one is bounded that way
/// and the symptom is total — hence the report. The same defect took out `alpha|beta` selected
/// through its newline, which is why the middle test here has no empty line in it: a fix aimed
/// only at empty lines would leave half the defect standing (engine, 2026-09-15).
@available(iOS 18.4, *)
final class EngineEmptyLineSelectionTests: XCTestCase {
    private var window: UIWindow!
    private let font = UIFont.systemFont(ofSize: 17.0)

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    private func engine(_ strings: [String]) -> TGIDObservingBlockTextView {
        let engine = TGIDObservingBlockTextView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 240),
            attributedBlocks: strings.map { NSAttributedString(string: $0, attributes: [.font: font]) })
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(engine)
        window.makeKeyAndVisible()
        engine.layoutIfNeeded()
        return engine
    }

    /// The rects the engine vends for a flat canonical range, refusing any that cannot be drawn.
    private func drawableRects(_ engine: TGIDObservingBlockTextView,
                               _ range: Range<Int>,
                               file: StaticString = #filePath,
                               line: UInt = #line) -> [CGRect] {
        guard let start = engine.position(from: engine.beginningOfDocument, offset: range.lowerBound),
              let end = engine.position(from: engine.beginningOfDocument, offset: range.upperBound),
              let textRange = engine.textRange(from: start, to: end) else {
            XCTFail("\(range) is not a range of this document", file: file, line: line)
            return []
        }
        return engine.selectionRects(for: textRange).map(\.rect).filter { rect in
            // A rect at infinity is drawn nowhere, which on screen is indistinguishable from no
            // selection — the exact shape of the reported defect, so it must not count as one.
            // `CGRectNull` IS that rect: its origin is infinite, and the engine's degenerate answer
            // arrived in exactly that form.
            let drawable = rect.origin.x.isFinite && rect.origin.y.isFinite
                && rect.width.isFinite && rect.height.isFinite
            XCTAssertTrue(drawable, "\(range) vended \(rect)", file: file, line: line)
            return drawable && !rect.isEmpty
        }
    }

    func test_aSelectionEndingOnAnEmptyLineIsDrawn() {
        let engine = self.engine(["alpha", "", "beta"])
        XCTAssertFalse(drawableRects(engine, 0 ..< 6).isEmpty, "\"alpha\\n\" highlighted nothing")
    }

    func test_aSelectionStartingOnAnEmptyLineIsDrawn() {
        let engine = self.engine(["alpha", "", "beta"])
        XCTAssertFalse(drawableRects(engine, 6 ..< 11).isEmpty, "\"\\nbeta\" highlighted nothing")
    }

    /// The general case the empty line is only the loudest instance of: two ordinary paragraphs,
    /// selected up to the break between them.
    func test_aSelectionEndingOnAParagraphBreakIsDrawn() {
        let engine = self.engine(["alpha", "beta"])
        XCTAssertFalse(drawableRects(engine, 0 ..< 6).isEmpty, "\"alpha\\n\" highlighted nothing")
        XCTAssertFalse(drawableRects(engine, 5 ..< 7).isEmpty, "\"\\nb\" highlighted nothing")
    }

    /// One highlight per line, the empty line included — a selection that is drawn but skips a line
    /// is a different defect wearing the same clothes.
    func test_everyLineOfASelectionThroughEmptyLinesIsDrawn() {
        let engine = self.engine(["alpha", "", "", "beta"])
        let tops = Set(drawableRects(engine, 0 ..< 12).map { $0.minY.rounded() })
        XCTAssertEqual(tops.count, 4)
    }
}
