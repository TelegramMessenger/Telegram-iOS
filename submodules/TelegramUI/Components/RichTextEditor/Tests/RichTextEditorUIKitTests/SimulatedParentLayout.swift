#if canImport(UIKit)
import UIKit
@testable import RichTextEditorUIKit

extension DocumentCanvasView {
    /// Test helper: makes a canvas-DIRECT test behave as if its real parent (`RichTextEditorView`) is
    /// present and eagerly re-lays the canvas out whenever it reports a content-size change. Production
    /// only NOTIFIES (`notifyContentSizeChanged()` → `onContentSizeChange`); the parent drives
    /// `layoutContent()`. Tests that read post-edit geometry (block/emoji/dust views synced in
    /// `layoutContent`) call this once after creating the canvas + setting its frame, so an edit flushes
    /// layout the way it does at runtime. Install AFTER any initial `layoutIfNeeded()`.
    func simulateParentLayout() {
        onContentSizeChange = { [weak self] in self?.layoutContent() }
    }
}
#endif
