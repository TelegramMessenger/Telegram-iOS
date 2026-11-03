#if canImport(UIKit)
import UIKit

/// Per-host geometry for code blocks. Every field defaults to `nil`, meaning "take the shared
/// render-metrics value" (`StyleSheet.metrics.code`) — so a host that never sets
/// `RichTextEditorView.codeStyle` renders exactly what the InstantPage V2 renderer will.
///
/// Code used to borrow `QuoteStyle.leadingInset` / `trailingInset` / `topInset` / `bottomInset`,
/// which is why the composer shipped a 9/22 interior padding against the renderer's 9/9. Side
/// padding is no longer a knob at all: it is the paragraph inset, by construction.
@available(iOS 13.0, *)
public struct CodeStyle: Equatable {
    /// Visible gap from the band's top/bottom edge to the glyphs. `nil` = `metrics.code.verticalInset`.
    public var verticalInset: CGFloat?
    /// Gap between the bold language line and the first code line. `nil` = `metrics.code.languageSpacing`.
    public var languageSpacing: CGFloat?
    /// How far the band extends past the text column on each side. `nil` (default) reaches the CANVAS
    /// edge — the document-editor look, and what the InstantPage V2 renderer does in a bubble.
    ///
    /// A compact host must set a value: the canvas is inset INSIDE the input field's rounded
    /// background, and its right content margin additionally reserves room for the accessory and send
    /// buttons — so "reach the canvas edge" there means reaching well past the field's visible edge
    /// and under its buttons. The parallel of `MediaBlockStyle.horizontalBleed`, which the composer
    /// zeroes for the same reason.
    public var horizontalBleed: CGFloat?
    /// Extra inset of the code text INWARD from the band's edges. 0 (default) keeps the text at the
    /// paragraph inset of its nesting level — the renderer's rule, where the band's side padding IS
    /// that inset because the band bleeds outward past it.
    ///
    /// A host that cannot let the band bleed (a compact field) sets this instead: the band then spans
    /// exactly the text column and the code is indented within it. The two are alternatives — bleed
    /// moves the BAND out, this moves the TEXT in — and a host normally sets one or the other.
    public var horizontalInset: CGFloat
    /// Corner radius of the band. 0 (default) is square, matching the renderer. A compact host rounds
    /// it slightly so the band sits inside the field's own rounded background instead of fighting it.
    public var cornerRadius: CGFloat

    public init(verticalInset: CGFloat? = nil, languageSpacing: CGFloat? = nil,
                horizontalBleed: CGFloat? = nil, horizontalInset: CGFloat = 0,
                cornerRadius: CGFloat = 0) {
        self.verticalInset = verticalInset
        self.languageSpacing = languageSpacing
        self.horizontalBleed = horizontalBleed
        self.horizontalInset = horizontalInset
        self.cornerRadius = cornerRadius
    }

    public static let `default` = CodeStyle()
}
#endif
