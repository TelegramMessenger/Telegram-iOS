import XCTest
import UIKit
import TelegramCore
@testable import InstantPageUI

/// Laid-out rich text carries, run by run, the quotable node it shows and the flat range of that node
/// the run stands for; the selection adapter maps a selection to quote boundaries through it, and a
/// quote back to the text it highlights.
final class InstantPageQuoteSourceTests: XCTestCase {
    private let first = InstantPageTextNodeId(blockPath: [0], part: .text)
    private let second = InstantPageTextNodeId(blockPath: [1], part: .text)

    private func stack() -> InstantPageTextStyleStack {
        let stack = InstantPageTextStyleStack()
        stack.push(.fontSize(17.0))
        stack.push(.textColor(.black))
        stack.push(.linkColor(.blue))
        return stack
    }

    private func stamped(_ text: RichText, node: InstantPageTextNodeId) -> NSAttributedString {
        return attributedStringForRichText(text, styleStack: self.stack(), formatDate: { _, _ in "FORMATTED" }, quoteSource: InstantPageQuoteSourceCursor(node: node))
    }

    private struct Leaf: Equatable {
        let display: NSRange
        let flatStart: Int
        let flatLength: Int
        let isAtomic: Bool
    }

    private func leaves(_ string: NSAttributedString) -> [Leaf] {
        var result: [Leaf] = []
        string.enumerateAttribute(InstantPageQuoteLeafAttribute, in: NSRange(location: 0, length: string.length), options: []) { value, range, _ in
            if let leaf = value as? InstantPageQuoteLeaf {
                result.append(Leaf(display: range, flatStart: leaf.flatStart, flatLength: leaf.flatLength, isAtomic: leaf.isAtomic))
            }
        }
        return result
    }

    private func adapter(_ strings: [NSAttributedString]) -> InstantPageMultiTextAdapter {
        var entries: [InstantPageMultiTextAdapter.Entry] = []
        for (index, string) in strings.enumerated() {
            let (item, _, _) = layoutTextItemWithString(string, boundingWidth: 1000.0, offset: CGPoint())
            entries.append(InstantPageMultiTextAdapter.Entry(item: item!, frameOrigin: CGPoint(x: 0.0, y: CGFloat(index) * 100.0)))
        }
        return InstantPageMultiTextAdapter(entries: entries)
    }

    func testPlainRunsMapOneToOne() {
        XCTAssertEqual(self.leaves(self.stamped(.concat([.plain("ab"), .bold(.plain("cd"))]), node: self.first)), [
            Leaf(display: NSRange(location: 0, length: 2), flatStart: 0, flatLength: 2, isAtomic: false),
            Leaf(display: NSRange(location: 2, length: 2), flatStart: 2, flatLength: 2, isAtomic: false)
        ])
    }

    func testAtomsCoverTheirDisplayAndStandForTheirFlatText() {
        let date: RichText = .textDate(text: .plain("today"), date: 1, format: .full(timeFormat: .short, dateFormat: .long, dayOfWeek: false))
        let string = self.stamped(.concat([.plain("a"), .textCustomEmoji(fileId: 1, alt: "👍"), date, .plain("z")]), node: self.first)
        XCTAssertEqual(string.string, "a\u{FFFC}FORMATTEDz")
        XCTAssertEqual(self.leaves(string), [
            Leaf(display: NSRange(location: 0, length: 1), flatStart: 0, flatLength: 1, isAtomic: false),
            Leaf(display: NSRange(location: 1, length: 1), flatStart: 1, flatLength: 2, isAtomic: true),
            Leaf(display: NSRange(location: 2, length: 9), flatStart: 3, flatLength: 5, isAtomic: true),
            Leaf(display: NSRange(location: 11, length: 1), flatStart: 8, flatLength: 1, isAtomic: false)
        ])
    }

    func testImagesAndEmptyAnchorsAreAtomsOfNoText() {
        let image: RichText = .image(id: EngineMedia.Id(namespace: 0, id: 1), dimensions: PixelDimensions(width: 10, height: 10))
        let string = self.stamped(.concat([.plain("a"), image, .anchor(text: .empty, name: "n"), .plain("b")]), node: self.first)
        // The image and the empty anchor are both "no text at flat offset 1", so their runs merge.
        XCTAssertEqual(self.leaves(string), [
            Leaf(display: NSRange(location: 0, length: 1), flatStart: 0, flatLength: 1, isAtomic: false),
            Leaf(display: NSRange(location: 1, length: 2), flatStart: 1, flatLength: 0, isAtomic: true),
            Leaf(display: NSRange(location: 3, length: 1), flatStart: 1, flatLength: 1, isAtomic: false)
        ])
    }

    // A formula is not rendered here: SwiftMath's fonts are not in the test bundle (it traps in
    // `MTFont`). Its run is stamped by the same wrapper path as an emoji's, from this length.
    func testAtomFlatLengths() {
        XCTAssertEqual(RichText.formula(latex: "x^2").instantPageQuoteAtomFlatLength, 3)
        XCTAssertEqual(RichText.textCustomEmoji(fileId: 1, alt: "👍").instantPageQuoteAtomFlatLength, 2)
        XCTAssertEqual(RichText.textButton(InstantPageButton(text: .bold(.plain("Go")), action: .url(""), color: nil)).instantPageQuoteAtomFlatLength, 2)
        XCTAssertNil(RichText.anchor(text: .plain("ab"), name: "n").instantPageQuoteAtomFlatLength)
        XCTAssertNil(RichText.bold(.plain("ab")).instantPageQuoteAtomFlatLength)
    }

    func testNonEmptyAnchorIsCountedOnce() {
        let result = self.leaves(self.stamped(.concat([.anchor(text: .plain("ab"), name: "n"), .plain("c")]), node: self.first))
        XCTAssertEqual(result.map(\.flatStart), [0, 2])
    }

    func testNoCursorNoStamp() {
        let string = attributedStringForRichText(.plain("x"), styleStack: self.stack())
        XCTAssertNil(string.attribute(InstantPageQuoteLeafAttribute, at: 0, effectiveRange: nil))
    }

    // Every run a selection touches, in display order; TelegramCore orders them by document position
    // (`richQuoteSelectionBoundaries`), since display order is not document order in a spanned table.
    func testSelectionMapsToNodeRuns() {
        // Combined text: "Hello " 0..<6, the emoji placeholder at 6, "\n\n" at 7..<9, "world" 9..<14.
        let adapter = self.adapter([
            self.stamped(.concat([.plain("Hello "), .textCustomEmoji(fileId: 1, alt: "👍")]), node: self.first),
            self.stamped(.plain("world"), node: self.second)
        ])
        let insideFirst = adapter.richQuoteRuns(for: NSRange(location: 2, length: 5))
        XCTAssertEqual(insideFirst.map(\.id), [self.first, self.first])
        XCTAssertEqual(insideFirst.map(\.range), [2 ..< 6, 6 ..< 8])

        let acrossNodes = adapter.richQuoteRuns(for: NSRange(location: 4, length: 8))
        XCTAssertEqual(acrossNodes.map(\.id), [self.first, self.first, self.second])
        XCTAssertEqual(acrossNodes.map(\.range), [4 ..< 6, 6 ..< 8, 0 ..< 3])

        XCTAssertTrue(adapter.richQuoteRuns(for: NSRange(location: 7, length: 2)).isEmpty)
    }

    func testRangesShowingNodeRanges() {
        let adapter = self.adapter([
            self.stamped(.concat([.plain("Hello "), .textCustomEmoji(fileId: 1, alt: "👍")]), node: self.first),
            self.stamped(.plain("world"), node: self.second)
        ])
        let ranges = adapter.ranges(showing: [(id: self.first, range: 2 ..< 8), (id: self.second, range: 0 ..< 3)])
        XCTAssertEqual(ranges, [NSRange(location: 2, length: 5), NSRange(location: 9, length: 3)])
    }

    // A quote's highlight takes one rect per line (`LinkHighlightingNode` reads consecutive rects as
    // consecutive lines and splits overlapping ones at their middle), so the runs a quote covers come
    // back as one span. One range per run drew a line of an emoji and bold text as the emoji's top
    // half beside the text's bottom half.
    func testQuoteOverSeveralRunsOfALineIsOneSpan() {
        // Display: the emoji placeholder, " ", "Chain or belt?" (16); flat: "⚙️" (2), " ", the text (17).
        let adapter = self.adapter([
            self.stamped(.concat([.textCustomEmoji(fileId: 1, alt: "⚙️"), .plain(" "), .bold(.plain("Chain or belt?"))]), node: self.first)
        ])
        let ranges = adapter.ranges(showing: [(id: self.first, range: 0 ..< 17)])
        XCTAssertEqual(ranges, [NSRange(location: 0, length: 16)])
        XCTAssertEqual(ranges.compactMap { adapter.textRangeRects(in: $0) }.flatMap(\.rects).count, 1)
    }
}
