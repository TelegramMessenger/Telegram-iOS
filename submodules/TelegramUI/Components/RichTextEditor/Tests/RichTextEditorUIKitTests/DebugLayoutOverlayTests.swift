#if DEBUG
#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class DebugLayoutOverlayTests: XCTestCase {
    override func tearDown() {
        RichTextEditorView.debugShowLayoutOverlay = false   // global flag — reset so other tests are unaffected
        super.tearDown()
    }

    private func overlay(in v: RichTextEditorView) -> DebugLayoutOverlayView? {
        v.subviews.compactMap { $0 as? DebugLayoutOverlayView }.first
    }

    func test_overlay_installsWhenEnabled_andRemovesWhenDisabled() {
        let v = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        v.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Hi")]))])

        // Disabled (explicit, not relying on the default): no overlay even after a layout pass.
        RichTextEditorView.debugShowLayoutOverlay = false
        _ = v.update(size: CGSize(width: 320, height: 240), insets: .zero, contentMargins: .zero)
        XCTAssertNil(overlay(in: v), "overlay absent while the flag is off")

        // Enabled → installed on the next layout, sized to the field bounds, topmost + non-interactive.
        RichTextEditorView.debugShowLayoutOverlay = true
        _ = v.update(size: CGSize(width: 320, height: 240),
                     insets: UIEdgeInsets(top: 10, left: 0, bottom: 20, right: 0),
                     contentMargins: UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8))
        let o = overlay(in: v)
        XCTAssertNotNil(o, "overlay installs when enabled")
        XCTAssertEqual(o?.frame, v.bounds, "overlay covers the field bounds")
        XCTAssertEqual(v.subviews.last, o, "overlay is the topmost subview")
        XCTAssertEqual(o?.isUserInteractionEnabled, false, "overlay is non-interactive")

        // Disabled → removed on the next layout.
        RichTextEditorView.debugShowLayoutOverlay = false
        _ = v.update(size: CGSize(width: 320, height: 240), insets: .zero, contentMargins: .zero)
        XCTAssertNil(overlay(in: v), "overlay removed when disabled")
    }
}
#endif
#endif
