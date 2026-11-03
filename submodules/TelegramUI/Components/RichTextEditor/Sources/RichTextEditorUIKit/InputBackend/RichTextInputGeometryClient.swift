#if canImport(UIKit)
import UIKit

/// The geometry boundary is TextKit-neutral. All rectangles are in
/// `RichTextInputHost.hostInputView` coordinates (deviation D23 renames the spec's `inputView`).
/// Telegram accounts for page margins, nested blocks, table horizontal scrolling, and viewport offsets
/// before returning them.
///
/// Authority: caret, point, range, line, and navigation geometry are the sole authority of this
/// client. Missing geometry returns `nil` here — never a fabricated `CGRect.zero` (deviation D9 keeps
/// `.zero` only at the UIKit-witness router, never across this boundary).
@MainActor
@available(iOS 13.0, *)
protocol RichTextInputGeometryClient: AnyObject {
    var layoutGeneration: UInt64 { get }

    func caretGeometry(
        at position: RichTextInputPosition,
        revision: UInt64,
        purpose: RichTextInputGeometryPurpose
    ) -> RichTextInputCaretGeometry?

    func closestPosition(
        to point: CGPoint,
        within range: NSRange?,
        revision: UInt64,
        purpose: RichTextInputGeometryPurpose
    ) -> RichTextInputPosition?

    func characterRange(
        at point: CGPoint,
        revision: UInt64
    ) -> NSRange?

    func lineRange(
        enclosing position: RichTextInputPosition,
        revision: UInt64
    ) -> (range: NSRange, resolvedAffinity: RichTextInputAffinity)?

    /// Telegram resolves horizontal and vertical visual navigation; the backend does not substitute
    /// UTF-16 arithmetic for visual navigation. `anchorPositionOffset` is preserved through vertical
    /// navigation.
    func navigate(
        from position: RichTextInputPosition,
        direction: RichTextInputLayoutDirection,
        offset: Int,
        anchorPositionOffset: CGFloat?,
        revision: UInt64
    ) -> RichTextInputNavigationResult?

    func firstRect(
        for range: NSRange,
        revision: UInt64,
        purpose: RichTextInputGeometryPurpose
    ) -> CGRect?

    /// A visible rectangle requests bounded drawing geometry. Endpoint flags require the corresponding
    /// endpoint segments even when offscreen, so a complete canonical Select All does not require
    /// materializing every intermediate block. Segment order is canonical document order, not subview
    /// order. Reversed selections retain logical endpoint roles.
    func selectionSegments(
        for request: RichTextInputSelectionGeometryRequest,
        revision: UInt64
    ) -> [RichTextInputSelectionSegment]?

    func baseWritingDirection(
        at position: RichTextInputPosition,
        revision: UInt64
    ) -> RichTextInputWritingDirection
}
#endif
