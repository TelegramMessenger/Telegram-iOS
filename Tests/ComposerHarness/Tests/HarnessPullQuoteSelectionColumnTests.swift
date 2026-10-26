import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, a selection over two lines of a PULL QUOTE ran sideways
/// out of the pull quote's pill on both sides: the line covered to its end reached the column's
/// trailing edge, and the line covered from its beginning started at x 0, the column's leading
/// edge, under the opening-quote glyph and outside the pill.
///
///     pull quote "First paragraph.\u{2028}Second paragraph.", range 10..<30 (width 317)
///     pill 38.3..228.7; rects: line 1 x 144→267, line 2 x 0→169
///
/// **The controls, at the same line-fill rule** (a line covered to a side fills to that side):
/// a plain paragraph fills to its text column (0 and 267); a block quote and a code block fill to
/// their BAND (0..267 for both here) — their bands are exactly as wide as the column or wider, so
/// the fill reaches the band. The rule is "a covered side reaches the block's box, or its column
/// when it has none" (`selectionBoxes` in `IDBlockStackCanvasView.h`: "HORIZONTALLY the box is where
/// the selection reaches, always"). A pull quote is the one box NARROWER than its text container:
/// its text lays out across the whole column, centred, while the pill hugs it.
///
/// **Cause.** `IDDocumentLayoutCoordinator.m` (`id_selectionGeometryAttemptForCanonicalRange:`)
/// grew a covered side to the slot with `MIN`/`MAX` against the segment TextKit returned — growth
/// only. TextKit already fills a covered line to its text CONTAINER's edge, so where the box is
/// narrower than the container the growth kept TextKit's fill and never came back to the box.
///
/// **Tier 1**: `selectionRects(for:)` on the engine text view is the geometry UIKit draws.
final class HarnessPullQuoteSelectionColumnTests: XCTestCase {
    private func arrange(_ blocks: [ChatInputBlock]) throws -> HarnessRootViewController {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        _ = try HarnessEngine.node(host)
        host.setInputContent(ChatInputContent(blocks: blocks))
        HarnessEngine.settle(root)
        return root
    }

    private func rects(_ root: HarnessRootViewController, _ range: NSRange) throws -> [CGRect] {
        let view = try HarnessEngine.textView(in: root)
        let input = try XCTUnwrap(view as? UITextInput, "precondition: the engine view is not a UITextInput")
        let start = try XCTUnwrap(input.position(from: input.beginningOfDocument, offset: range.location))
        let end = try XCTUnwrap(input.position(from: input.beginningOfDocument, offset: NSMaxRange(range)))
        return input.selectionRects(for: try XCTUnwrap(input.textRange(from: start, to: end)))
            .map(\.rect).filter { !$0.isEmpty }.sorted { $0.minY < $1.minY }
    }

    /// The decoration views the host draws its container bands with, in the engine view's space.
    private func bands(_ root: HarnessRootViewController) throws -> [CGRect] {
        let view = try HarnessEngine.textView(in: root)
        return view.subviews.filter { NSStringFromClass(type(of: $0)).contains("ContainerDecoration") }.map(\.frame)
    }

    func testATwoLineSelectionInAPullQuoteStaysInsideItsPill() throws {
        let root = try self.arrange([
            .pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: "First paragraph.\nSecond paragraph.")])),
        ])
        let pill = try XCTUnwrap(try self.bands(root).first, "precondition: no pull-quote pill")
        let rects = try self.rects(root, NSRange(location: 10, length: 20))
        XCTAssertEqual(rects.count, 2, "precondition: expected one rect per line, got \(rects)")
        guard rects.count == 2 else { return }
        let (first, second) = (rects[0], rects[1])

        // The line covered to its END reaches the pill's trailing edge — no further.
        XCTAssertEqual(first.maxX, pill.maxX, accuracy: 0.5,
                       "line 1 is covered to its end and should fill to the pill's trailing edge: \(first) vs pill \(pill)")
        // The line covered from its BEGINNING reaches the pill's leading edge — no further.
        XCTAssertEqual(second.minX, pill.minX, accuracy: 0.5,
                       "line 2 is covered from its beginning and should fill from the pill's leading edge: \(second) vs pill \(pill)")
        // And the uncovered sides still hug the glyphs, well inside the pill.
        XCTAssertGreaterThan(first.minX, pill.minX + 20.0, "line 1's leading side stopped hugging its glyphs: \(first)")
        XCTAssertLessThan(second.maxX, pill.maxX - 20.0, "line 2's trailing side stopped hugging its glyphs: \(second)")
    }

    /// Control: a code block's band is as wide as the column here, and the same selection fills to it.
    func testATwoLineSelectionInACodeBlockFillsToItsBand() throws {
        let root = try self.arrange([
            .code(ChatInputCode(language: nil, runs: [ChatInputRun(text: "First paragraph.\nSecond paragraph.")])),
        ])
        let band = try XCTUnwrap(try self.bands(root).first, "precondition: no code band")
        // The code body starts at 1: offset 0 is the empty language line.
        let rects = try self.rects(root, NSRange(location: 10, length: 20))
        XCTAssertEqual(rects.count, 2, "precondition: expected one rect per line, got \(rects)")
        guard rects.count == 2 else { return }
        XCTAssertEqual(rects[0].maxX, band.maxX, accuracy: 0.5, "\(rects[0]) vs band \(band)")
        XCTAssertEqual(rects[1].minX, band.minX, accuracy: 0.5, "\(rects[1]) vs band \(band)")
    }

    /// Control: a quoted paragraph fills to the quote's band, bar included.
    func testATwoLineSelectionInABlockQuoteFillsToItsBand() throws {
        let text = "The quick brown fox jumps over the lazy dog and then keeps running far away from here."
        let root = try self.arrange([
            .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [HarnessEngine.paragraph(text)]),
                                            collapsed: false)),
        ])
        let band = try XCTUnwrap(try self.bands(root).first, "precondition: no quote band")
        let rects = try self.rects(root, NSRange(location: 10, length: 40))
        XCTAssertEqual(rects.count, 2, "precondition: expected one rect per line, got \(rects)")
        guard rects.count == 2 else { return }
        XCTAssertEqual(rects[0].maxX, band.maxX, accuracy: 0.5, "\(rects[0]) vs band \(band)")
        XCTAssertEqual(rects[1].minX, band.minX, accuracy: 0.5, "\(rects[1]) vs band \(band)")
    }
}
