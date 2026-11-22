import CoreGraphics
import Foundation
import XCTest
@testable import MessageWidget

/// Text selection (sdk-v1 §5.10): the geometry main answers the selection's questions from, without the runtime.
final class SelectableTextTests: XCTestCase {
    private typealias Run = MessageWidgetSelectableText.Run

    /// "ab cd" on one line (two runs of node 1), then "ef" on the next (node 2); 8 pt a character, 10 pt a line.
    private let twoLines = MessageWidgetSelectableText(text: "ab cd\nef", runs: [
        Run(start: 0, length: 2, box: CGRect(x: 0.0, y: 0.0, width: 16.0, height: 10.0), carets: [0.0, 8.0, 16.0], transform: .identity, node: 1, nodeOffset: 0),
        Run(start: 3, length: 2, box: CGRect(x: 24.0, y: 0.0, width: 16.0, height: 10.0), carets: [0.0, 8.0, 16.0], transform: .identity, node: 1, nodeOffset: 3),
        Run(start: 6, length: 2, box: CGRect(x: 0.0, y: 12.0, width: 16.0, height: 10.0), carets: [0.0, 8.0, 16.0], transform: .identity, node: 2, nodeOffset: 0)
    ])

    func testAPointOnAWordMapsToItsCharacter() {
        XCTAssertEqual(self.twoLines.index(at: CGPoint(x: 9.0, y: 5.0), nearest: false), 1)
        XCTAssertEqual(self.twoLines.index(at: CGPoint(x: 25.0, y: 5.0), nearest: false), 3)
        XCTAssertEqual(self.twoLines.index(at: CGPoint(x: 1.0, y: 15.0), nearest: false), 6)
    }

    /// A finger lands a little off the glyphs: a point within half a run's height above or below it still hits it (the
    /// nearer line wins), as a text bubble answers from its closest line; farther off, nothing.
    func testAPointJustOffALineStillHitsIt() {
        XCTAssertEqual(self.twoLines.index(at: CGPoint(x: 9.0, y: 10.5), nearest: false), 1)
        XCTAssertEqual(self.twoLines.index(at: CGPoint(x: 9.0, y: 11.6), nearest: false), 7)
        XCTAssertEqual(self.twoLines.index(at: CGPoint(x: 9.0, y: -4.0), nearest: false), 1)
        XCTAssertNil(self.twoLines.index(at: CGPoint(x: 9.0, y: -6.0), nearest: false))
        XCTAssertNil(self.twoLines.index(at: CGPoint(x: 9.0, y: 28.0), nearest: false))
    }

    /// Final review M1: the reach is a few points, not half a line, so a hold on an unselectable line right under a
    /// selectable one does not select the word above.
    func testAHoldOnTheLineBelowDoesNotReachUp() {
        let text = MessageWidgetSelectableText(text: "ab", runs: [
            Run(start: 0, length: 2, box: CGRect(x: 0.0, y: 0.0, width: 16.0, height: 18.0), carets: [0.0, 8.0, 16.0], transform: .identity, node: 1, nodeOffset: 0)
        ])
        XCTAssertEqual(text.index(at: CGPoint(x: 9.0, y: 21.0), nearest: false), 1)
        XCTAssertNil(text.index(at: CGPoint(x: 9.0, y: 25.0), nearest: false))
    }

    /// Final review I2: a Text node whose data changes in place keeps its node, so a selection's ends come back at the
    /// same offsets in new text; the remapped range covers whole characters, never half of a surrogate pair.
    func testARemappedRangeNeverSplitsASurrogatePair() {
        func text(_ string: String) -> MessageWidgetSelectableText {
            let units = (string as NSString).length
            return MessageWidgetSelectableText(text: string as NSString, runs: [
                Run(start: 0, length: units, box: CGRect(x: 0.0, y: 0.0, width: CGFloat(units) * 8.0, height: 10.0), carets: (0 ... units).map { CGFloat($0) * 8.0 }, transform: .identity, node: 1, nodeOffset: 0)
            ])
        }
        let before = text("9 \u{1F600}")
        let after = text("10 \u{1F600}")
        // The emoji was selected: units 2 ..< 4 before.
        guard let remapped = after.remap(NSRange(location: 2, length: 2), from: before) else {
            return XCTFail("dropped")
        }
        let selected = after.text.substring(with: remapped) as NSString
        for i in 0 ..< selected.length {
            let unit = selected.character(at: i)
            if CFStringIsSurrogateHighCharacter(unit) {
                XCTAssertTrue(i + 1 < selected.length && CFStringIsSurrogateLowCharacter(selected.character(at: i + 1)), "a lone high surrogate")
            }
            if CFStringIsSurrogateLowCharacter(unit) {
                XCTAssertTrue(i > 0 && CFStringIsSurrogateHighCharacter(selected.character(at: i - 1)), "a lone low surrogate")
            }
        }
        // A node that is gone drops it.
        let other = MessageWidgetSelectableText(text: "x", runs: [Run(start: 0, length: 1, box: .zero, carets: [0.0, 8.0], transform: .identity, node: 2, nodeOffset: 0)])
        XCTAssertNil(other.remap(NSRange(location: 2, length: 2), from: before))
    }

    func testAPointBetweenRunsIsNilUnlessNearest() {
        XCTAssertNil(self.twoLines.index(at: CGPoint(x: 20.0, y: 5.0), nearest: false))
        XCTAssertEqual(self.twoLines.index(at: CGPoint(x: 18.0, y: 5.0), nearest: true), 2)
        XCTAssertEqual(self.twoLines.index(at: CGPoint(x: -5.0, y: 5.0), nearest: true), 0)
        XCTAssertEqual(self.twoLines.index(at: CGPoint(x: 100.0, y: 15.0), nearest: true), 8)
        XCTAssertEqual(self.twoLines.index(at: CGPoint(x: 9.0, y: 40.0), nearest: true), 7)
    }

    func testRangeRectsMergeALinesRuns() {
        XCTAssertEqual(self.twoLines.rangeRects(NSRange(location: 0, length: 5))?.rects, [CGRect(x: 0.0, y: 0.0, width: 40.0, height: 10.0)])
        XCTAssertEqual(self.twoLines.rangeRects(NSRange(location: 1, length: 6))?.rects, [
            CGRect(x: 8.0, y: 0.0, width: 32.0, height: 10.0),
            CGRect(x: 0.0, y: 12.0, width: 8.0, height: 10.0)
        ])
        XCTAssertNil(self.twoLines.rangeRects(NSRange(location: 2, length: 1)))
    }

    func testEdgesAreAtTheRangesEnds() {
        let result = self.twoLines.rangeRects(NSRange(location: 1, length: 3))
        XCTAssertEqual(result?.start, MessageWidgetSelectableText.Edge(x: 8.0, y: 0.0, height: 10.0))
        XCTAssertEqual(result?.end, MessageWidgetSelectableText.Edge(x: 32.0, y: 0.0, height: 10.0))
    }

    func testATransformedRunMapsThroughItsTransform() {
        let transform = CGAffineTransform(a: 2.0, b: 0.0, c: 0.0, d: 2.0, tx: 100.0, ty: 50.0)
        let text = MessageWidgetSelectableText(text: "ab", runs: [
            Run(start: 0, length: 2, box: CGRect(x: 0.0, y: 0.0, width: 16.0, height: 10.0), carets: [0.0, 8.0, 16.0], transform: transform, node: 1, nodeOffset: 0)
        ])
        XCTAssertEqual(text.index(at: CGPoint(x: 118.0, y: 60.0), nearest: false), 1)
        XCTAssertNil(text.index(at: CGPoint(x: 9.0, y: 5.0), nearest: false))
        XCTAssertEqual(text.rangeRects(NSRange(location: 0, length: 2))?.rects, [CGRect(x: 100.0, y: 50.0, width: 32.0, height: 20.0)])
        XCTAssertEqual(text.rangeRects(NSRange(location: 0, length: 2))?.end, MessageWidgetSelectableText.Edge(x: 132.0, y: 50.0, height: 20.0))
    }

    func testRTLCaretsMapBothWays() {
        let text = MessageWidgetSelectableText(text: "\u{05E9}\u{05DC}", runs: [
            Run(start: 0, length: 2, box: CGRect(x: 0.0, y: 0.0, width: 16.0, height: 10.0), carets: [16.0, 8.0, 0.0], transform: .identity, node: 1, nodeOffset: 0)
        ])
        XCTAssertEqual(text.index(at: CGPoint(x: 12.0, y: 5.0), nearest: false), 0)
        XCTAssertEqual(text.index(at: CGPoint(x: 3.0, y: 5.0), nearest: false), 1)
        XCTAssertEqual(text.rangeRects(NSRange(location: 0, length: 1))?.rects, [CGRect(x: 8.0, y: 0.0, width: 8.0, height: 10.0)])
    }

    func testPositionsRoundTrip() {
        for index in 0 ... self.twoLines.text.length {
            guard let position = self.twoLines.position(at: index) else {
                XCTFail("no position at \(index)")
                continue
            }
            XCTAssertEqual(self.twoLines.index(of: position), index)
        }
        XCTAssertEqual(self.twoLines.position(at: 4), MessageWidgetSelectableText.Position(node: 1, offset: 4))
        XCTAssertEqual(self.twoLines.position(at: 7), MessageWidgetSelectableText.Position(node: 2, offset: 1))
        XCTAssertNil(self.twoLines.index(of: MessageWidgetSelectableText.Position(node: 3, offset: 0)))
        XCTAssertNil(self.twoLines.index(of: MessageWidgetSelectableText.Position(node: 2, offset: 9)))
    }

    /// Review Focus 1: a point on either half of an emoji is that emoji, never the boundary between its two halves.
    func testIndicesNeverSplitASurrogatePair() {
        let text = MessageWidgetSelectableText(text: "a\u{1F600}b", runs: [
            Run(start: 0, length: 4, box: CGRect(x: 0.0, y: 0.0, width: 32.0, height: 10.0), carets: [0.0, 8.0, 8.0, 24.0, 32.0], transform: .identity, node: 1, nodeOffset: 0)
        ])
        XCTAssertEqual(text.index(at: CGPoint(x: 10.0, y: 5.0), nearest: false), 1)
        XCTAssertEqual(text.index(at: CGPoint(x: 20.0, y: 5.0), nearest: false), 1)
        XCTAssertEqual(text.index(at: CGPoint(x: 25.0, y: 5.0), nearest: false), 3)
    }
}
