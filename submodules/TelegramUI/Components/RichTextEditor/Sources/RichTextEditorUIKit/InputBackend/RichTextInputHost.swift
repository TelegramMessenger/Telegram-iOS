#if canImport(UIKit)
import UIKit

/// The Telegram side of the seam. `DocumentCanvasView` conforms to this in Phase 3; the backend
/// retains it WEAKLY.
@MainActor
@available(iOS 13.0, *)
protocol RichTextInputHost: AnyObject {
    /// The actual first-responder view. All UIKit-facing geometry is in this view's coordinates.
    ///
    /// DEVIATION D23: the spec names this `inputView`. `DocumentCanvasView` already declares
    /// `override var inputView: UIView? { return self.customInputView }` — the
    /// UIResponder custom-keyboard hook that deviation D5 deliberately keeps un-routed (re-confirmed
    /// at Task 30, which routed that member's neighbours and left this one alone). One type
    /// cannot have two members named `inputView`, and `UIView?` does not satisfy a `UIView`
    /// requirement, so the host member is `hostInputView`.
    ///
    /// **FIX ROUND 1 (Min-4): the `DCV:628` line number is GONE rather than re-measured, and so are the
    /// two in `LegacyRichTextInputBackend+Commands.swift`.** Task 30 replaced `:628` with `:759` and
    /// wrote a note boasting that it had corrected a 131-line drift — while itself landing 26 lines off,
    /// because it measured against the PARENT tree and its own commit moved the member to `:785`. A
    /// citation that is stale in the commit that records it is worse than none: it reads as freshly
    /// verified. The member name identifies it uniquely; that is what a reader greps for anyway. Stage 2's
    /// IDTextEditorBackendClientBridge uses the same name.
    var hostInputView: UIView { get }

    var documentClient: any RichTextInputDocumentClient { get }
    var geometryClient: any RichTextInputGeometryClient { get }
    var annotationClient: any RichTextInputAnnotationClient { get }
    var presentationClient: any RichTextInputPresentationClient { get }
    var lifecycleClient: any RichTextInputLifecycleClient { get }
    var commandClient: any RichTextInputCommandClient { get }
}
#endif
