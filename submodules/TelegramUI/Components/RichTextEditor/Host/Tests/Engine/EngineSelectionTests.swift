import XCTest
import UIKit
import RichTextEditorCore
@testable import RichTextEngineEditor

final class EngineSelectionTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "alpha")])),
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "beta")])),
        ])
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor)
        window.makeKeyAndVisible()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    /// "alpha\nbeta" — the flat axis the composer already speaks, and the engine's canonical axis.
    /// If this fails with an off-by-one per block, someone has invented a structural-axis
    /// conversion that must not exist.
    func test_composerRangeIsTheFlatUTF16Axis() {
        editor.composerSelectedRange = NSRange(location: 6, length: 4)
        XCTAssertEqual(editor.composerSelectedRange, NSRange(location: 6, length: 4))
        XCTAssertEqual(editor.selectedText(), "beta")
    }

    func test_caretRectIsRealForACollapsedSelection() {
        editor.composerSelectedRange = NSRange(location: 3, length: 0)
        let caret = editor.composerCaretRect()
        XCTAssertNotNil(caret)
        XCTAssertGreaterThan(caret!.height, 0)
    }

    func test_firstSelectionRectCoversTheSelection() {
        let rect = editor.composerFirstSelectionRect(forFlatRange: NSRange(location: 0, length: 5))
        XCTAssertNotNil(rect)
        XCTAssertGreaterThan(rect!.width, 0)
    }

    func test_selectionBoundingRectSpansTwoBlocks() {
        editor.composerSelectedRange = NSRange(location: 0, length: 10)
        XCTAssertGreaterThan(editor.composerSelectionBoundingRect.height,
                             editor.composerCaretRect()?.height ?? .greatestFiniteMagnitude)
    }

    /// Spec §5.2: the reshaped address. Block-relative, so it survives edits elsewhere.
    func test_blockRelativeRangeNamesTheBlockAndOffsetWithinIt() {
        editor.composerSelectedRange = NSRange(location: 6, length: 4)
        let range = editor.selectedBlockRelativeRange()
        XCTAssertEqual(range?.from.0, BlockID("p1"))
        XCTAssertEqual(range?.from.1, 0)
        XCTAssertEqual(range?.to.1, 4)
    }

    func test_aCollapsedSelectionHasNoBlockRelativeRange() {
        editor.composerSelectedRange = NSRange(location: 3, length: 0)
        XCTAssertNil(editor.selectedBlockRelativeRange())
    }
}
