#if canImport(UIKit)
import UIKit

/// Small public forwarders used by the chat-composer host (`RichTextEditorChatInputNode`). The editing
/// surface (`canvas`) and `scrollView` are module-internal, so a consumer in another module reaches these
/// behaviors only through `RichTextEditorView`. No new editor logic lives here.
@available(iOS 13.0, *)
public extension RichTextEditorView {
    /// Whether the editing surface (the canvas, the actual first responder) currently has focus.
    /// `UIView.isFirstResponder` would report the wrapper, not the canvas.
    var isEditorFirstResponder: Bool { self.canvas.isFirstResponder }

    /// Resign the editing surface's first-responder status (forwarded to the canvas).
    @discardableResult
    func resignEditorFirstResponder() -> Bool { self.canvas.resignFirstResponder() }

    /// Commit any pending marked/predictive text before send. The range return value is not needed by the host.
    func finalizeComposerMarkedText() { _ = self.canvas.finalizeMarkedText() }

    /// The selection in the chat composer's flat UTF-16 coordinate space (the document's paragraphs joined
    /// by "\n", matching `ComposerDocumentBridge`). The host reads it to track the caret and writes it to
    /// move the caret after a programmatic insert/replace; without a real mapping the host is selection-blind
    /// (the caret never advances and a surrogate-pair emoji is split on edit, leaving a stray code unit).
    var composerSelectedRange: NSRange {
        get { self.canvas.composerSelectedRange }
        set { self.canvas.composerSelectedRange = newValue }
    }

    /// Reload the editing surface's input views (after changing `customInputView`).
    func reloadComposerInputViews() { self.canvas.reloadInputViews() }

    /// The editor's content scroll offset (host maps content-space rects to the visible space).
    var composerContentOffset: CGPoint { self.scrollViewContentOffset }

    /// The built-in horizontal page margin applied to text (in addition to `contentMargins`). Defaults to
    /// 16pt (document layout); a compact composer host sets it to 0 so the host owns all horizontal insets.
    var contentPageMargin: CGFloat {
        get { self.canvas.pageMargin }
        set { self.canvas.pageMargin = newValue }
    }

    /// The base inter-block vertical inset for the document root (each side). Defaults to 8pt (document
    /// inter-paragraph gap); a compact composer host sets it to 0 so a single paragraph hugs its text height.
    var blockVerticalInset: CGFloat {
        get { self.canvas.blockVerticalInset }
        set { self.canvas.blockVerticalInset = newValue }
    }

    /// Placeholder strings drawn in empty paragraphs. Defaults to the editor's built-in hints; a host that
    /// draws its own placeholder (the chat composer) sets them to "" to suppress the editor's. Applied on the
    /// next layout pass — set before the first `update(...)`/document seed.
    var placeholders: RichTextEditorPlaceholders {
        get { self.canvas.placeholders }
        set { self.canvas.placeholders = newValue }
    }

    /// The editing canvas's background. Defaults to `.systemBackground` (the document "page"); a compact host
    /// that sits on its own surface (the chat composer, over the input panel) sets it to `.clear` so the
    /// panel's background shows through. The scroll view and block backing views are already clear.
    var canvasBackgroundColor: UIColor? {
        get { self.canvas.backgroundColor }
        set { self.canvas.backgroundColor = newValue }
    }

    /// Whether tapping in the empty area below the document's last block appends a new empty body paragraph
    /// (so you can always start a normal paragraph below the final block). Defaults to `true` for the full-page
    /// article editor; the chat composer sets it to `false`, where a tap below the content just places the
    /// caret in the existing trailing paragraph rather than growing the field.
    var tapBelowAddsTrailingParagraph: Bool {
        get { self.canvas.tapBelowAddsTrailingParagraph }
        set { self.canvas.tapBelowAddsTrailingParagraph = newValue }
    }

    /// Toggle the current selection/paragraph(s) into a code block (or back to body paragraphs).
    func makeCodeBlock() { self.canvas.makeCodeBlock() }

    /// The active keyboard's primary language while the editor is first responder, or nil when unfocused
    /// (`UIResponder.textInputMode` is nil unless first responder). Reads through the canvas's `textInputMode`
    /// override — after that override's one-time pre-selection has been consumed, this is the live keyboard.
    var inputPrimaryLanguage: String? { self.canvas.textInputMode?.primaryLanguage }

    /// The language the keyboard should open in on the next focus (the chat composer seeds it from the
    /// draft's saved `inputLanguage`). Forwarded to the canvas's one-time `textInputMode` pre-selection.
    var initialInputPrimaryLanguage: String? {
        get { self.canvas.initialPrimaryLanguage }
        set { self.canvas.initialPrimaryLanguage = newValue }
    }

    /// Re-arm the pre-selection so the next focus re-applies `initialInputPrimaryLanguage`.
    func resetInputPrimaryLanguage() { self.canvas.resetInitialPrimaryLanguage() }

    /// First selection rect for a chat-flat range, in this view's coordinate space (scroll-adjusted via
    /// the view tree). The host converts further to its own `self.view` space. nil when the range covers
    /// no glyphs (the host then shows no emoji-suggestion popover).
    func composerFirstSelectionRect(forFlatRange range: NSRange) -> CGRect? {
        guard let r = self.canvas.composerSelectionRects(forFlatRange: range).first else { return nil }
        return self.convert(r, from: self.canvas)
    }

    /// The caret rect at the selection end, in this view's coordinate space (scroll-adjusted via the view
    /// tree), or nil when there is no caret. The host converts further to its own `self.view` space.
    func composerCaretRect() -> CGRect? {
        guard let r = self.canvas.composerCaretRectInCanvas() else { return nil }
        return self.convert(r, from: self.canvas)
    }

    /// Bounding rect of the current selection in CONTENT space (un-scrolled, NOT view-converted): the sole
    /// consumer (`ChatTextInputPanelNode._showTextStyleOptions`) subtracts `composerContentOffset.y` itself.
    /// That path is dead on iOS 17+ (the legacy format menu is nil-targeted), so this is implemented for
    /// contract-honesty only. Content space == canvas space (the canvas is the scroll view's content at origin 0).
    var composerSelectionBoundingRect: CGRect { self.canvas.composerSelectionBoundingRectInCanvas() }
}
#endif
