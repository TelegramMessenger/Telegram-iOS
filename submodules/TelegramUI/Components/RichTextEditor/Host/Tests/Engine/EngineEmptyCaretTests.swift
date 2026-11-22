import XCTest
import UIKit
import RichTextEditorCore
@testable import RichTextEngineEditor

/// An empty composer's caret must be the same size as one on a typed line.
///
/// Reported from the device: "when the text field is empty the cursor is unusually small" — 15.7pt
/// against 23.7pt. The caret is derived from the block's text storage, and an empty storage carries
/// no attributes, so neither the font nor the paragraph style's pinned line height reaches TextKit.
///
/// Pinned HERE as well as upstream because the composer configures the engine differently from a
/// bare editor — its own metrics, theme and zeroed container padding — and the defect is only
/// meaningful to a user in that configuration.
@available(iOS 18.4, *)
final class EngineEmptyCaretTests: XCTestCase {
    private var window: UIWindow!

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.makeKeyAndVisible()
    }

    override func tearDown() { window.isHidden = true; window = nil; super.tearDown() }

    private func caret(forText text: String) -> CGRect {
        let editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 120))
        window.addSubview(editor)
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"),
                                      runs: text.isEmpty ? [] : [TextRun(text: text)])),
        ])
        editor.setNeedsLayout()
        editor.layoutIfNeeded()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        return editor.engine.caretRect(for: editor.engine.endOfDocument)
    }

    private func caret(atStartOf text: String) -> CGRect {
        let editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 120))
        window.addSubview(editor)
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: text)])),
        ])
        editor.setNeedsLayout()
        editor.layoutIfNeeded()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        return editor.engine.caretRect(for: editor.engine.beginningOfDocument)
    }

    func test_anEmptyFieldsCaretIsTheSameSizeAsATypedOne() {
        let empty = caret(forText: "")
        let typed = caret(forText: "x")

        XCTAssertGreaterThan(typed.height, 0.0)
        XCTAssertEqual(empty.height, typed.height, accuracy: 1.0,
                       "the empty field's caret is a different size from a typed line's: "
                       + "empty=\(empty) typed=\(typed)")
        XCTAssertEqual(empty.minY, typed.minY, accuracy: 1.0,
                       "the empty caret sits on a different line box")

        // Same PLACE and WIDTH as a caret at the start of a typed line, not merely the same height.
        // The composer runs with zero container padding, so the line begins at the container's edge
        // and a caret even half a point off — or zero-width — draws clipped there. Asserting only the
        // height let exactly that through.
        let typedStart = caret(atStartOf: "x")
        XCTAssertEqual(empty.minX, typedStart.minX, accuracy: 0.5,
                       "empty=\(empty) typedStart=\(typedStart)")
        XCTAssertEqual(empty.width, typedStart.width, accuracy: 0.5,
                       "empty=\(empty) typedStart=\(typedStart)")
        XCTAssertGreaterThan(typedStart.width, 0.0, "a caret with no width cannot be drawn")
    }
}
