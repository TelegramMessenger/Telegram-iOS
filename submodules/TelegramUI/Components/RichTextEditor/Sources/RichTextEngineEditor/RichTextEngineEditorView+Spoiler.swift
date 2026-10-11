#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
import RichTextInputDecUpstream

/// R9-inline Task 6 — spoilers.
///
/// The only inline feature whose styling must not be written into the document. Links and inline code
/// write presentation into the document and let read-back strip it; a spoiler cannot, twice over: its
/// hide is a foreground colour, which read-back captures into `CharacterAttributes.foreground` and
/// would SEND; and it reveals while the selection is inside it, so a document write per caret move
/// would put an undo entry on every arrow key.
///
/// So the marker lives in the document and the hide rides the engine's display-decoration channel.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    internal static let spoilerAttributeKey = NSAttributedString.Key.rtSpoiler

    public func isSpoilerActive() -> Bool {
        (engine.hostAttributeValue(forKey: Self.spoilerAttributeKey) as? Bool) == true
    }

    public func toggleSpoiler() {
        // Across a table's structural selection the value is decided ONCE and applied to each covered
        // cell — `transformInlineAttributes` is a SET, so the result is uniform by construction.
        if acrossStructuralSelection(deciding: { self.isSpoilerActive() },
                                     apply: { self.applySpoiler(enabling: $0) }) { return }
        let enabling = !isSpoilerActive()
        deliveringChangeNotification { recordingInlineFormatStep { self.applySpoiler(enabling: enabling) } }
    }

    internal func applySpoiler(enabling: Bool) {
        engine.transformInlineAttributes { attributes in
            var result = attributes
            if enabling {
                result[Self.spoilerAttributeKey] = true
            } else {
                result.removeValue(forKey: Self.spoilerAttributeKey)
            }
            return result
        }
        // The model carries a spoiler on an INLINE atom (formula, button, custom emoji — the
        // read-back keeps it) but not on a MEDIA atom or a BUTTON ROW, whose blocks render from
        // their shape: re-derived, the marker leaves those and stays on the inline ones
        // (`HarnessAtomInlineFormatDriftTests`, edited-content fuzz seed 17).
        rederiveAtomPresentation(touching: engineSelectedRange)
        engine.setNeedsDisplayDecorationUpdate()
        setNeedsLayout()
    }

    internal func installSpoilerDecorator() {
        engine.displayDecorator = { [weak self] text, blockIdentifier in
            guard let self else { return text }
            return self.spoilerDecorated(text, blockIdentifier: blockIdentifier)
        }
    }

    // MARK: The reveal rule — ONE definition

    /// Whether the selection reveals a run at this canonical range.
    ///
    /// INTERNAL AND SHARED, deliberately. The hidden text and the dust cloud both need this answer,
    /// and two copies of the rule would eventually disagree — dust over readable text, or an invisible
    /// run with no dust. Matches the legacy canvas: overlapping selection, or a collapsed caret INSIDE
    /// the run. Not at its edges, or a caret parked just after a spoiler would hold it open forever.
    internal func selectionRevealsCanonicalRange(_ range: NSRange) -> Bool {
        guard let selection = selectionCanonicalRange() else { return false }
        if selection.length == 0 {
            return selection.location > range.location
                && selection.location < NSMaxRange(range)
        }
        return NSIntersectionRange(selection, range).length > 0
    }

    private func selectionCanonicalRange() -> NSRange? {
        guard let selected = engine.selectedTextRange else { return nil }
        let location = engine.offset(from: engine.beginningOfDocument, to: selected.start)
        let length = engine.offset(from: selected.start, to: selected.end)
        guard location >= 0, length >= 0 else { return nil }
        return NSRange(location: location, length: length)
    }

    /// Removes `.link` from the text handed to the RENDERER, keeping it in the document.
    ///
    /// TextKit underlines `.link` itself, and it cannot be talked out of it: the model carries no
    /// underline attribute, setting `.underlineStyle = 0` does not suppress it, and legacy renders
    /// links as accent text only. The colour is already applied as a real attribute, so dropping the
    /// key costs nothing visually and removes the default styling with it.
    ///
    /// Render-only by construction — the document keeps `.link`, which is what round-trips to
    /// `CharacterAttributes.link` and reaches the sent message.
    internal static func withoutRenderedLinkAttribute(_ text: NSAttributedString) -> NSAttributedString {
        let whole = NSRange(location: 0, length: text.length)
        var hasLink = false
        text.enumerateAttribute(.link, in: whole, options: []) { value, _, stop in
            if value != nil { hasLink = true; stop.pointee = true }
        }
        guard hasLink else { return text }
        let result = NSMutableAttributedString(attributedString: text)
        result.removeAttribute(.link, range: whole)
        return result
    }

    /// A block's first canonical position. Blocks are separated by one position on the engine's axis.
    /// From the engine view's identity cache: the canvas asks once per block per pass, and walking
    /// `attributedBlocks` + `tgid_blockIdentifiers` (each built afresh) per call was O(n²) in a pass.
    internal func canonicalStart(ofBlock blockIdentifier: UUID) -> Int? {
        let start = engine.tgid_canonicalStart(ofBlockIdentifier: blockIdentifier)
        return start == NSNotFound ? nil : start
    }

    // MARK: Hiding the text

    /// Hides every spoiler run the selection does not reveal.
    ///
    /// HIDES GLYPHS ONLY. An attachment — a custom emoji — is a hosted view and is unaffected by a
    /// foreground colour, so it would stay visible behind the dust. The engine hosts no attachment
    /// views today (they land with custom emoji, R9 Task 5), so there is nothing yet to hide; when
    /// that rung lands it MUST hide the views intersecting a hidden run, or spoilers leak their
    /// emoji. Recorded here and in the R9 plan rather than left to be rediscovered.
    private func spoilerDecorated(_ text: NSAttributedString,
                                  blockIdentifier: UUID) -> NSAttributedString {
        let whole = NSRange(location: 0, length: text.length)
        var hidden: [NSRange] = []
        guard let blockStart = canonicalStart(ofBlock: blockIdentifier) else {
            return Self.withoutRenderedLinkAttribute(text)
        }
        text.enumerateAttribute(Self.spoilerAttributeKey, in: whole, options: []) { value, range, _ in
            guard (value as? Bool) == true else { return }
            let canonical = NSRange(location: blockStart + range.location, length: range.length)
            if !selectionRevealsCanonicalRange(canonical) { hidden.append(range) }
        }
        guard !hidden.isEmpty else { return Self.withoutRenderedLinkAttribute(text) }

        let result = NSMutableAttributedString(attributedString: Self.withoutRenderedLinkAttribute(text))
        for range in hidden {
            result.addAttribute(.foregroundColor, value: UIColor.clear, range: range)
        }
        return result
    }
}
#endif
