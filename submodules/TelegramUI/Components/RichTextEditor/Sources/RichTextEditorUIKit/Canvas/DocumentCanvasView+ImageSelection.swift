#if canImport(UIKit)
import UIKit
import RichTextEditorCore

@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// True when `img` should render its selection tint — either it is the tap-selected atom, or a
    /// non-collapsed text selection spans across its atom (a range flowing over it). A collapsed gap
    /// caret and a caption-only selection are both excluded.
    /// (`selFrom <= nodeStart && selTo >= textStart` ⇒ the range runs from at/before the gap to at/after
    /// the caption start, i.e. it fully contains the image atom.)
    func isImageSelected(_ img: MediaBlockBox) -> Bool {
        if imageSelection == img.id { return true }
        return selFrom != selTo && selFrom <= img.nodeStart && selTo >= img.textStart
    }

    /// The canvas-coords rect the selection tint fills for `img`, or nil when it isn't selected.
    /// Single geometry seam so a unit test and the actual draw cannot diverge.
    func imageSelectionTintRect(for img: MediaBlockBox) -> CGRect? {
        isImageSelected(img) ? img.mediaRect() : nil
    }

    func clearImageSelection() {
        guard imageSelection != nil else { return }
        imageSelection = nil
        refreshSelectionUI(); setNeedsDisplay()
    }

    /// Clears BOTH structural selections (table row/column AND image atom). Called by every
    /// "this action moves on" site that previously cleared only the table selection.
    func clearStructuralSelections() { clearTableSelection(); clearImageSelection() }

    /// Selects the top-level image `img` as an atom: parks the (hidden) caret at its gap, sets
    /// `imageSelection`, and clears any table structural selection. The tint over the image is the
    /// indicator. Mirrors `selectTableRows`.
    func selectImage(_ img: MediaBlockBox) {
        finalizeMarkedText()        // a deliberate selection change finalizes marked text (uniform invariant)
        clearTableSelection()
        // Bracket the caret move with the input-delegate notification (like `setCaret`) so the OS re-reads
        // `selectedTextRange` = the gap. Without it the OS keeps the STALE prior caret, and a hardware Arrow
        // key runs `position(from:in:)` from the previous position instead of the image (the reported bug).
        // TASK 26: unsuppressed selection bracket (this site never consulted the coalescing flag).
        // TASK 39: `applyCaretOutcome` (`+Editing.swift`) inside the UNCHANGED bracket, not
        // `setSelection` — see `applySelection` in `+SelectionActions.swift` for the shared reasoning
        // (population C: this bracket neither opens a transaction nor suppresses, so a publish takes
        // the full path). Here it would be worse than a doubling: `selectImage` reports NOTHING to the
        // host today — there is no `onSelectionChange?()` below — so a publish would INVENT one.
        inputBackend.notifyingSelectionChangeIgnoringCoalescing {
            applyCaretOutcome(.caret(at: img.nodeStart))
        }
        imageSelection = img.id
        refreshSelectionUI(); setNeedsDisplay()
    }

    /// Tapping a top-level media atom selects it (parks the caret at its gap + draws the tint). Media has
    /// NO edit menu — Spoiler / Delete live in the host's per-media "•••" menu, and the selected atom is also
    /// deletable via Backspace (see the object-replacement-range invariants). A repeat tap is a no-op.
    func handleImageTap(_ img: MediaBlockBox, wasMenuVisible: Bool, wasFirstResponder: Bool) {
        if imageSelection != img.id {
            dismissEditMenu()
            selectImage(img)
        }
    }
}
#endif
