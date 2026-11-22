#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// The editor convention: a view never `setNeedsLayout()`s itself for a content-height change — it
/// NOTIFIES its parent (`onContentSizeChange`), which drives layout explicitly. `notifyContentSizeChanged()`
/// is that notifier.
final class LayoutNotificationTests: XCTestCase {
    func test_notifyContentSizeChanged_firesCallback() {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hi")]))], width: 320)
        var count = 0
        v.onContentSizeChange = { count += 1 }
        v.notifyContentSizeChanged()
        XCTAssertEqual(count, 1, "notifyContentSizeChanged() fires the host content-size callback")
    }
}
#endif
