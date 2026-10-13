#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// Link commands. Like the character toggles, they operate over the same targets as
/// `characterFormatTargets()` — every leaf region the text selection touches, or every cell of a
/// structurally-selected table row/column — so a link is continuous across cells. A link carries a
/// value, so these build on `applyCharacterAttribute` (a value-set sibling of `applyCharacterToggle`)
/// rather than the toggle engine. A bare collapsed caret (no table selection) is a no-op. The visible
/// blue styling (no underline) is injected into the live storage here AND emitted by the mapper on
/// rebuild, and suppressed on read-back — so the model stays link-only (see `AttributedStringMapper`).
@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// Runs `mutate` on each (storage, range) `characterFormatTargets()` covers, inside `editing { }`.
    /// No toggle direction — just a per-range mutation. No-op when nothing is targeted.
    func applyCharacterAttribute(_ mutate: (NSTextStorage, NSRange) -> Void) {
        let covered = characterFormatTargets()
        guard !covered.isEmpty else { return }
        // TASK 39b: same shape and same policy as `applyCharacterToggle` — see its call site for the
        // one statement of why. (It used to say "and for the disclosed `.preserveIfRebasable`
        // degradation"; TASK 41 closed that gap and also measured this site unable to reach it —
        // `editing { }` finalizes any composition first. The corrected statement is at that call site;
        // this one is pinned by `MarkedStateAuthorityTests
        // .test_aSetLinkDuringACompositionCommitsIt_asItAlreadyDidAtBase`, a separate arm because
        // `applyCharacterAttribute` is a separate call site.)
        synchronizingExternalChange(reason: .formatting, markedTextPolicy: .preserveIfRebasable) {
            editing {
                for c in covered {
                    mutate(c.storage, c.range)
                    // Direct NSTextStorage mutation bypasses BlockLayout's renderVersion bump sites, so a
                    // view-backed paragraph wouldn't repaint (its renderSignature wouldn't change). Bump here.
                    c.layout.bumpRenderVersion()
                }
                return .unchanged
            }
        }
    }

    /// Sets `url` as the link over the selection, with the render-only blue styling (no underline).
    func setLink(_ url: String) {
        // A code block's language is a plain string on the wire — a link there would be dropped on
        // read-back (an inert edit that still dirties the model).
        if selectionIsEntirelyInCodeLanguageRegion() { return }
        applyCharacterAttribute { storage, range in
            storage.addAttribute(.link, value: url, range: range)
            storage.addAttribute(.foregroundColor, value: self.mapper.theme.accent, range: range)
            // No underline: reference design shows links as blue text only.
        }
    }

    /// Removes the link over the selection and its render-only styling (resets foreground to the
    /// mapper's default so the text renders like any other unlinked run).
    func removeLink() {
        applyCharacterAttribute { storage, range in
            storage.removeAttribute(.link, range: range)
            // Defensive: storage written before 6a may carry a link underline; clear it.
            storage.removeAttribute(.underlineStyle, range: range)
            // Restore the mapper's default unlinked-run foreground so the text renders like any other run
            // (the mapper writes ca.foreground ?? primaryText, or secondaryText for .caption). We don't
            // removeAttribute(.foregroundColor) — that would leave live storage colorless (black) until the
            // next rebuild. KNOWN LIMITATION: this writes primaryText regardless of style, so removing a link
            // inside a .caption run under a theme where primaryText != secondaryText leaves an explicit
            // foreground that the read-back strip (which compares captions against secondaryText) won't clear,
            // lightly polluting the model for that run. Latent until a host sets such a theme; revisit with the
            // host-wiring work.
            storage.addAttribute(.foregroundColor, value: self.mapper.theme.primaryText, range: range)
        }
    }

    /// The link the entire target carries (the text selection, or a structurally-selected table
    /// row/column — matching what `setLink` would apply), or nil if nothing is targeted, any covered
    /// text is unlinked, or two different links are mixed. Used to prefill the demo's URL prompt.
    func currentLink() -> String? {
        let targets = characterFormatTargets()
        guard !targets.isEmpty else { return nil }
        var values = Set<String>()
        var sawUnlinked = false
        for t in targets {
            t.storage.enumerateAttribute(.link, in: t.range, options: []) { v, _, _ in
                if let s = (v as? String) ?? (v as? URL)?.absoluteString { values.insert(s) }
                else { sawUnlinked = true }
            }
        }
        guard !sawUnlinked, values.count == 1 else { return nil }
        return values.first
    }
}
#endif
