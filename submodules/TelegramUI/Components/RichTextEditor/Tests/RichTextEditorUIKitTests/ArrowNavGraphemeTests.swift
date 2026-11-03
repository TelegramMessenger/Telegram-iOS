#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// Left/right arrow navigation (`position(from:in:direction:)` → `next/prevTextPosition`) must cross a
/// whole grapheme in one step. Stepping one UTF-16 unit lands mid-surrogate inside an emoji, so the caret
/// appears not to move and a second press is needed to cross it.
final class ArrowNavGraphemeTests: XCTestCase {
    private func makeCanvas(text: String) -> DocumentCanvasView {
        let c = DocumentCanvasView()
        c.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: text)]))], width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
        c.layoutIfNeeded()
        return c
    }

    func test_nextTextPosition_crossesWholeSurrogatePairEmoji() {
        let c = makeCanvas(text: "a\u{1F600}b")   // a(0..1) 😀(1..3) b(3..4)
        let base = c.boxes[0].textStart
        XCTAssertEqual(c.nextTextPosition(after: base + 1), base + 3, "one right-step crosses the whole emoji")
    }

    func test_prevTextPosition_crossesWholeSurrogatePairEmoji() {
        let c = makeCanvas(text: "a\u{1F600}b")
        let base = c.boxes[0].textStart
        XCTAssertEqual(c.prevTextPosition(before: base + 3), base + 1, "one left-step crosses the whole emoji")
    }

    func test_nextTextPosition_crossesZWJSequence() {
        let fam = "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}"   // 11 UTF-16 units
        let c = makeCanvas(text: "a\(fam)b")
        let base = c.boxes[0].textStart
        XCTAssertEqual(c.nextTextPosition(after: base + 1), base + 1 + 11, "one right-step crosses the whole ZWJ family")
    }

    func test_plainCharacters_stepOneAtATime() {
        let c = makeCanvas(text: "abc")
        let base = c.boxes[0].textStart
        XCTAssertEqual(c.nextTextPosition(after: base + 1), base + 2)
        XCTAssertEqual(c.prevTextPosition(before: base + 2), base + 1)
    }
}
#endif
