#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// A tap must place the caret on a composed-character-sequence boundary — never inside a surrogate-pair /
/// ZWJ emoji. A mid-cluster caret lets a later insert/delete split the cluster, leaving a stray code unit
/// (the chat-composer "service character", and a broken grapheme-aware backspace).
final class ClosestOffsetGraphemeTests: XCTestCase {
    private func sweep(_ string: String, forbidden: Set<Int>, allowed: Set<Int>) {
        let attr = NSAttributedString(string: string, attributes: [.font: UIFont.systemFont(ofSize: 17)])
        let layout = makeBlockLayout(attributedString: attr, width: 300)
        let y = layout.caretRect(atOffset: 0).midY
        // Collect the distinct offsets returned across a horizontal sweep, then assert ONCE — a per-pixel
        // XCTAssert would emit hundreds of lines (and look like a hang) when it regresses.
        var returned = Set<Int>()
        for xi in stride(from: CGFloat(-10), through: 320, by: 2) {
            returned.insert(layout.closestOffset(toPoint: CGPoint(x: xi, y: y)))
        }
        XCTAssertTrue(returned.isDisjoint(with: forbidden),
                      "closestOffset returned mid-grapheme offset(s) \(returned.intersection(forbidden).sorted()) for \"\(string)\"")
        XCTAssertTrue(returned.isSubset(of: allowed),
                      "closestOffset returned unexpected offset(s) \(returned.subtracting(allowed).sorted()) for \"\(string)\"")
    }

    func test_surrogatePairEmoji_neverMidCluster() {
        // "a😀b" — a(0..1), 😀(1..3), b(3..4). Offset 2 is mid-surrogate.
        sweep("a\u{1F600}b", forbidden: [2], allowed: [0, 1, 3, 4])
    }

    func test_zwjSequence_neverMidCluster() {
        // "👨‍👩‍👧‍👦" is one grapheme spanning 11 UTF-16 units → only offsets 0 and 11 are caret stops.
        let fam = "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}"
        sweep(fam, forbidden: Set(1...10), allowed: [0, 11])
    }
}
#endif
