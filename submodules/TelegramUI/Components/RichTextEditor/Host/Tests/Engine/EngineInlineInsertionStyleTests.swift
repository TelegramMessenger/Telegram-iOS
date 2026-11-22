import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// An inline insertion must not stamp a stale paragraph style into engine storage.
///
/// The emoji / formula / pill insertion sites build their run through
/// `bridge.mapper.attributedString(for:)` and push it with `restoreStyleFlat`
/// (`+EditPrimitives.swift`), which writes EVERY attribute including `.paragraphStyle`. That style
/// comes straight from the shared `StyleSheet`, so once `engineReadable` began re-expressing the
/// pinned box (`EngineDocumentBridge.v2BaselinePlacedStyle`) it is the OLD one and the block ends up
/// carrying two different line boxes — one for the text the user typed and one for the character
/// just inserted into it.
///
/// `.paragraphStyle` is in `presentationKeys` (`+Settle.swift`), so `verifyPresentationIsDerived` can
/// also trap on it in DEBUG before `normalisePresentation` heals it.
@available(iOS 18.4, *)
final class EngineInlineInsertionStyleTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Alpha")]))
        ])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    /// Every distinct pinned box in the first block. One means the insertion carried the same line
    /// geometry as the text around it.
    private func distinctPinnedBoxes() -> Set<CGFloat> {
        let block = editor.engine.attributedBlocks[0]
        var boxes: Set<CGFloat> = []
        block.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: block.length),
                                 options: []) { value, _, _ in
            if let style = value as? NSParagraphStyle { boxes.insert(style.maximumLineHeight) }
        }
        return boxes
    }

    /// One case per insertion FAMILY — the emoji, the formula and the pill are three different files
    /// building their run the same way (`bridge.mapper.attributedString(for:)` + `restoreStyleFlat`),
    /// so a regression in the shared mechanism would show in any of them, and a regression in one
    /// file's own handling would show only in that one.
    private func assertOneLineBoxAfter(_ insert: () -> Void, _ label: String) {
        editor.composerSelectedRange = NSRange(location: 5, length: 0)
        insert()
        editor.setNeedsLayout(); editor.layoutIfNeeded()

        let block = editor.engine.attributedBlocks[0]
        XCTAssertGreaterThan(block.length, 5, "\(label): nothing was inserted, so this asserts nothing")
        let boxes = distinctPinnedBoxes()
        XCTAssertEqual(boxes.count, 1, "\(label): block carries \(boxes.count) pinned boxes: \(boxes)")
    }

    func test_insertingACustomEmojiLeavesOneLineBoxInTheBlock() {
        assertOneLineBoxAfter({ editor.insertEmoji(id: "1", altText: "X") }, "emoji")
    }

    func test_insertingAnInlineFormulaLeavesOneLineBoxInTheBlock() {
        assertOneLineBoxAfter({ editor.insertInlineFormula(latex: "x^2") }, "formula")
    }

    func test_insertingAnInlineButtonLeavesOneLineBoxInTheBlock() {
        assertOneLineBoxAfter({ editor.insertInlineButton(ButtonRef(label: [TextRun(text: "Go")], action: .url("https://t.me"))) }, "button")
    }
}
