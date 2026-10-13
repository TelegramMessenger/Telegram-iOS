#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// Transient spelling/grammar/autocorrection annotations. Storage is Telegram's existing
/// BlockID-keyed side table in region-local UTF-16 (DCV:489,495).
///
/// DEVIATION D17: the spec requires annotation state to rebase or clear explicitly across document
/// mutations. It does NOT today — the side table's ranges deliberately do not shift across edits
/// (documented at DCV:486-488), so a flagged word after a mid-region edit renders at a stale offset
/// until it self-heals. Repairing that is a behavior change and is out of scope for the seam.
///
/// `addRenderingAttributes` recognizes exactly two keys — ghost foreground (inline prediction) and
/// spoiler hidden — because those are the only two rendering-attribute mechanisms the layout seam
/// exposes (BlockLayoutEngine.setGhostForeground / setSpoilerHidden). It is not a general attribute
/// channel and returns false for anything else.
///
/// DEVIATION D29: the spec requires a successful visual change to invalidate `.annotations` or
/// `.spelling` — a RichTextInputPresentationInvalidation. This client emits none. It bumps
/// `layoutGeneration` and calls `setNeedsSpellUnderlineDisplay()` directly on the canvas it
/// already holds, which is how the legacy path has always expressed annotation invalidation.
/// Adding a real invalidation would introduce a presentation pass that does not exist today.
/// `test_annotationClientEmitsNoPresentationInvalidation` pins the absence.
@MainActor
@available(iOS 13.0, *)
final class TelegramAnnotationInputClient: RichTextInputAnnotationClient {
    /// `unowned`, deliberately, not `weak` — see `TelegramDocumentInputClient`'s doc comment for the
    /// full rationale (the canvas strictly outlives its clients). Tests that discard the canvas via `_`
    /// must bind it and use `withExtendedLifetime` instead.
    private unowned let canvas: DocumentCanvasView

    init(canvas: DocumentCanvasView) { self.canvas = canvas }

    // MARK: RichTextInputAnnotationClient

    /// Delegates verbatim to the existing controller-facing callback — no new translation, no rebasing.
    func annotatedSubstring(in range: NSRange, revision: UInt64) -> NSAttributedString? {
        guard revision == canvas.documentRevision else { return nil }
        guard let textRange = canvas.nativeTextRange(forGlobalLocation: range.location, length: range.length) else {
            return nil
        }
        return canvas.annotatedSubstring(for: textRange)
    }

    /// `key` is accepted but UNUSED: the legacy `spellResults` side table has exactly one annotation
    /// channel per block — a `SpellStyle` (`.spelling`/`.grammar`/`.correction`) per flagged range — so
    /// there is no key-based multiplexing to perform. The stored `SpellStyle` is the returned value.
    func annotationValue(for key: AnyHashable, at position: RichTextInputPosition, revision: UInt64) -> Any? {
        guard revision == canvas.documentRevision else { return nil }
        let offset = canvas.clampGlobal(position.utf16Offset)
        guard let (region, local) = canvas.leafRegion(containingGlobal: offset),
              let id = canvas.spellCheckableRef(region.ref),
              let entry = canvas.spellResults[id] else { return nil }
        return entry.ranges.first { NSLocationInRange(local, $0.range) }?.style
    }

    /// `key` is unused (see `annotationValue`'s doc). `value` must be a `DocumentCanvasView.SpellStyle`
    /// — anything else is refused. `range` must resolve to a checkable, non-excluded region (the same
    /// `clampedSpellRegionLocal` gate the native controller's own delivery path uses), so this can't
    /// flag text inside a link / inline-code / spoiler run, the active IME composition, or the word
    /// currently under the caret — exactly like the legacy `applyNativeAnnotations` it wraps.
    @discardableResult
    func addAnnotation(key: AnyHashable, value: Any, range: NSRange, revision: UInt64) -> Bool {
        guard revision == canvas.documentRevision else { return false }
        guard let style = value as? DocumentCanvasView.SpellStyle else { return false }
        guard canvas.clampedSpellRegionLocal(global: range) != nil else { return false }
        canvas.applyNativeAnnotations(global: range, style: style)   // also calls setNeedsSpellUnderlineDisplay()
        canvas.bumpLayoutGeneration()
        return true
    }

    /// `key` is unused (see `annotationValue`'s doc) — removal, unlike creation, is not gated by the
    /// exclusion filter (a flag can always be cleared regardless of what now overlaps it). Fails only
    /// when `range` doesn't even resolve to a checkable region; clearing a region with nothing flagged
    /// is a legitimate no-op, mirroring `clearNativeAnnotations`'s own silent-no-op shape.
    @discardableResult
    func removeAnnotation(key: AnyHashable, range: NSRange, revision: UInt64) -> Bool {
        guard revision == canvas.documentRevision else { return false }
        guard let (region, _) = canvas.leafRegion(containingGlobal: range.location),
              canvas.spellCheckableRef(region.ref) != nil else { return false }
        canvas.clearNativeAnnotations(global: range)   // also calls setNeedsSpellUnderlineDisplay()
        canvas.bumpLayoutGeneration()
        return true
    }

    @discardableResult
    func addRenderingAttributes(_ attributes: [NSAttributedString.Key: Any], range: NSRange, revision: UInt64) -> Bool {
        guard revision == canvas.documentRevision else { return false }
        guard range.location >= 0, range.length >= 0,
              range.location + range.length <= canvas.documentSizeValue else { return false }
        guard let (region, local) = canvas.leafRegion(containingGlobal: range.location) else { return false }
        var applied = false
        if let color = attributes[.richTextInputGhostForeground] as? UIColor {
            let end = min(local + range.length, region.length)
            region.layout.setGhostForeground(color, start: local, end: end)
            applied = true
        }
        if let hidden = attributes[.richTextInputSpoilerHidden] as? Bool {
            let end = min(local + range.length, region.length)
            region.layout.setSpoilerHidden(hidden ? [NSRange(location: local, length: max(0, end - local))] : [])
            applied = true
        }
        guard applied else { return false }
        canvas.bumpLayoutGeneration()
        canvas.setNeedsSpellUnderlineDisplay()
        return true
    }

    @discardableResult
    func removeRenderingAttributes(_ keys: [NSAttributedString.Key], range: NSRange, revision: UInt64) -> Bool {
        guard revision == canvas.documentRevision else { return false }
        guard range.location >= 0, range.length >= 0,
              range.location + range.length <= canvas.documentSizeValue else { return false }
        guard let (region, _) = canvas.leafRegion(containingGlobal: range.location) else { return false }
        var applied = false
        if keys.contains(.richTextInputGhostForeground) {
            region.layout.setGhostForeground(nil, start: 0, end: 0)
            applied = true
        }
        if keys.contains(.richTextInputSpoilerHidden) {
            region.layout.setSpoilerHidden([])
            applied = true
        }
        guard applied else { return false }
        canvas.bumpLayoutGeneration()
        canvas.setNeedsSpellUnderlineDisplay()
        return true
    }

    /// Marks the underline overlays dirty without touching `spellResults` itself — the pure
    /// "repaint, nothing changed" request the contract's name implies.
    func invalidateTemporaryAttributes(in range: NSRange, revision: UInt64) {
        guard revision == canvas.documentRevision else { return }
        canvas.bumpLayoutGeneration()
        canvas.setNeedsSpellUnderlineDisplay()
    }
}

/// The two rendering-attribute mechanisms `BlockLayoutEngine` exposes (`setGhostForeground` /
/// `setSpoilerHidden`), given `NSAttributedString.Key` identities so `addRenderingAttributes` /
/// `removeRenderingAttributes` can address them through the contract's generic dictionary/array
/// shape. Not display attributes in their own right — see `TelegramAnnotationInputClient`'s header.
@available(iOS 13.0, *)
extension NSAttributedString.Key {
    static let richTextInputGhostForeground = NSAttributedString.Key("RichTextInputAnnotation.ghostForeground")
    static let richTextInputSpoilerHidden = NSAttributedString.Key("RichTextInputAnnotation.spoilerHidden")
}
#endif
