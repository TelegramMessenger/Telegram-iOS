#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class SpoilerTypingTests: XCTestCase {
    /// Concatenated text of paragraph `id`'s runs whose attributes satisfy `pred`, read from the live model.
    private func spoileredText(_ c: DocumentCanvasView, _ id: String) -> String {
        for b in c.currentBlocks() {
            if case .paragraph(let p) = b, p.id == BlockID(id) {
                return p.runs.filter { $0.attributes.spoiler }.map { $0.text }.joined()
            }
        }
        return ""
    }

    func test_typingAtEndOfSpoiler_extendsTheSpoiler() {
        let c = DocumentCanvasView()
        c.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "abc")]))], width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        c.layoutIfNeeded()
        let start = c.boxes[0].textStart
        c.setSelectionForTesting(anchor: start, head: start + 3)   // select "abc"
        c.toggleSpoiler()
        c.setSelectionForTesting(anchor: start + 3, head: start + 3)   // caret at the end of the spoiler run
        c.insertText("X")
        XCTAssertEqual(spoileredText(c, "p1"), "abcX", "a char typed at the end of a spoiler run inherits the marker")
    }

    func test_typingBeforeSpoiler_isNotSpoilered() {
        // Use "xy" + spoiler on "bc" (positions 1-2) so the caret at position 0 is before an
        // un-spoilered character ("x"), confirming the clamp doesn't inherit the spoiler.
        let c = DocumentCanvasView()
        c.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "xbc")]))], width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        c.layoutIfNeeded()
        let start = c.boxes[0].textStart
        c.setSelectionForTesting(anchor: start + 1, head: start + 3)   // select "bc" only
        c.toggleSpoiler()
        c.setSelectionForTesting(anchor: start, head: start)   // caret BEFORE "x" (position 0 — not inside the spoiler)
        c.insertText("Z")                              // typed at the very start — not inside/adjacent to the spoiler
        XCTAssertEqual(spoileredText(c, "p1"), "bc", "a char typed before an unspoilered prefix is NOT spoilered")
    }
}
#endif
