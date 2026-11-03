import XCTest
import UIKit
import RichTextEditorCore
@testable import RichTextEngineEditor

@available(iOS 18.4, *)
final class EnginePaddingCheckTests: XCTestCase {
    /// Pins that the composer's editor adds NO container padding of its own: the first glyph starts
    /// at its block's leading edge. Before `lineFragmentPadding` was zeroed this was 5pt, which
    /// landed on top of the margins the host had already asked for.
    func test_theEditorAddsNoContainerPaddingOfItsOwn() {
        let editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor); window.makeKeyAndVisible()
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Hn")])),
        ])
        editor.setNeedsLayout(); editor.layoutIfNeeded()

        let block = editor.engine.id_frameForBlock(at: 0)
        guard let glyph = editor.engine
            .id_rects(forCanonicalRange: NSRange(location: 0, length: 2))
            .map(\.cgRectValue).first else { return XCTFail("no text geometry") }

        XCTAssertEqual(editor.engine.lineFragmentPadding, 0.0, accuracy: 0.01,
                       "the composer's editor must add no container padding of its own")
        // Measured on the glyphs, not just read back off the property: the first character starts at
        // its block's leading edge. This was 5pt — NSTextContainer's default — landing on top of the
        // margins the host had already asked for.
        XCTAssertEqual(glyph.minX - block.minX, 0.0, accuracy: 0.5,
                       "the text is inset from its own block, so the container is still padding it")
        window.isHidden = true
    }
}
