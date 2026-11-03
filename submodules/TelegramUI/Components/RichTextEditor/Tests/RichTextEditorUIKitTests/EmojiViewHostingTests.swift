#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class EmojiViewHostingTests: XCTestCase {
    /// A provider that hands out a fresh tagged view per call and records how many times it was asked.
    private final class Provider {
        var calls = 0
        func make(_ id: String, _ size: CGSize) -> UIView & RichTextEmojiView {
            calls += 1
            let v = TestEmojiView(frame: CGRect(origin: .zero, size: size))
            v.accessibilityIdentifier = id
            return v
        }
    }

    private func canvasWithEmoji() -> (DocumentCanvasView, Provider) {
        let c = DocumentCanvasView()
        let p = Provider()
        c.emojiViewProvider = { p.make($0, $1) }
        c.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "ab")]))], width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        c.layoutIfNeeded()
        c.simulateParentLayout()
        c.setSelectionForTesting(anchor: c.boxes[0].textStart + 1, head: c.boxes[0].textStart + 1)
        c.insertEmoji(id: "star", altText: nil)
        c.layoutIfNeeded()
        return (c, p)
    }

    func test_emojiView_isHostedInOverlay_atGlyphRect() {
        let (c, _) = canvasWithEmoji()
        XCTAssertEqual(c.hostedEmojiCountForTesting, 1)
        let view = c.firstHostedEmojiForTesting
        XCTAssertNotNil(view?.superview, "the emoji view is parented")
        XCTAssertFalse(view?.frame.isEmpty ?? true, "positioned at a real glyph rect")
    }

    func test_emojiView_isReusedAcrossLayoutPasses() {
        let (c, p) = canvasWithEmoji()
        let first = c.firstHostedEmojiForTesting
        c.setNeedsLayout(); c.layoutIfNeeded()
        let second = c.firstHostedEmojiForTesting
        XCTAssertTrue(first === second, "same instanceID reuses the same view object")
        XCTAssertEqual(p.calls, 1, "the provider is asked once per instanceID")
    }

    func test_emojiView_removedWhenEmojiDeleted() {
        let (c, _) = canvasWithEmoji()
        c.deleteBackward()        // caret was after the emoji
        c.layoutIfNeeded()
        XCTAssertEqual(c.hostedEmojiCountForTesting, 0)
    }

    func test_nilProvider_hostsNoView() {
        let c = DocumentCanvasView()
        c.emojiViewProvider = { _, _ in nil }
        c.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "ab")]))], width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        c.setSelectionForTesting(anchor: c.boxes[0].textStart + 1, head: c.boxes[0].textStart + 1)
        c.insertEmoji(id: "star", altText: nil)
        c.layoutIfNeeded()
        XCTAssertEqual(c.hostedEmojiCountForTesting, 0)
    }

    func test_cull_hidesEmojiOutsideExpandedViewport() {
        let (c, _) = canvasWithEmoji()
        let view = c.firstHostedEmojiForTesting
        c.cullEmojiViews(visibleRect: CGRect(x: 0, y: 0, width: 320, height: 10))   // emoji is ~ on line 1
        XCTAssertFalse(view?.isHidden ?? true)
        c.cullEmojiViews(visibleRect: CGRect(x: 0, y: 1000, width: 320, height: 50)) // far below
        XCTAssertTrue(view?.isHidden ?? false)
    }

    func test_facade_insertEmoji_andProvider_forwardToCanvas() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        editor.registerEmojiViewProvider { id, size in
            let v = TestEmojiView(frame: CGRect(origin: .zero, size: size)); v.accessibilityIdentifier = id; return v
        }
        editor.document = Document(
            blocks: [.paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "ab")]))])
        editor.layoutIfNeeded()
        editor.insertEmoji(id: "star", altText: ":star:")
        editor.layoutIfNeeded()
        let hasEmoji = editor.document.blocks.contains { block in
            if case let .paragraph(p) = block { return p.runs.contains { $0.attributes.emoji?.id == "star" } }
            return false
        }
        XCTAssertTrue(hasEmoji, "façade insertEmoji forwards to the canvas")
    }
}

/// A minimal `RichTextEmojiView` for the emoji-hosting tests. Shared across the test target; the editor
/// pushes `dynamicColor` (the template-emoji tint), which the tests can read back.
final class TestEmojiView: UIView, RichTextEmojiView {
    var dynamicColor: UIColor?
}
#endif
