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
/// `addRenderingAttributes` recognizes THREE mechanisms — ghost foreground (inline prediction),
/// spoiler hidden, and (TASK H2) the transient spell/grammar/correction marker. The first two are
/// the only rendering-attribute mechanisms the layout seam exposes
/// (`BlockLayoutEngine.setGhostForeground` / `setSpoilerHidden`); the third does not go through the
/// layout seam at all but through `spellResults`, the BlockID-keyed side table the underline overlay
/// actually draws from. It is still not a general attribute channel and returns false for anything
/// else — but the two keys it used to drop, `NSUnderlineStyle` / `NSUnderlineColor`, are exactly the
/// two upstream's own end-to-end test names as the misspelling marker, so dropping them was dropping
/// the only delivery this class exists to receive (`task-G2-report.md` rows F3/F9).
///
/// TASK H2 — **the revision gate is gone.** Every member used to open with
/// `guard revision == canvas.documentRevision`, on a revision read RAW off the incoming range
/// (`TGRichTextInputDecLayoutController.m:151-162`, deliberately un-rebased). Upstream has no
/// staleness gate at all: it CLIPS into the document as it currently stands
/// (`IDRichTextLayoutController.m:1369-1374`). The gate rejected precisely the case it had to
/// accept, because a correction annotation is BY NATURE delivered after the replacement that bumped
/// the revision. What it was protecting against — a range computed against an older document
/// landing out of bounds — is already handled, and by the code that must handle it anyway: every
/// mutating member below resolves through `clampedSpellRegionLocal(global:)` or
/// `leafRegion(containingGlobal:)` and the explicit `documentSizeValue` bounds checks, all of which
/// clamp into the CURRENT document and refuse a range that does not land in a checkable region. The
/// residual — a late range flagging the wrong current word — is D17 above, already this side table's
/// documented, self-healing behaviour, and strictly better than never flagging at all.
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
        guard let textRange = canvas.nativeTextRange(forGlobalLocation: range.location, length: range.length) else {
            return nil
        }
        return canvas.annotatedSubstring(for: textRange)
    }

    /// `key` is accepted but UNUSED: the legacy `spellResults` side table has exactly one annotation
    /// channel per block — a `SpellStyle` (`.spelling`/`.grammar`/`.correction`) per flagged range — so
    /// there is no key-based multiplexing to perform. The stored `SpellStyle` is the returned value.
    func annotationValue(for key: AnyHashable, at position: RichTextInputPosition, revision: UInt64) -> Any? {
        let offset = canvas.clampGlobal(position.utf16Offset)
        guard let (region, local) = canvas.leafRegion(containingGlobal: offset),
              let id = canvas.spellCheckableRef(region.ref),
              let entry = canvas.spellResults[id] else { return nil }
        return entry.ranges.first { NSLocationInRange(local, $0.range) }?.style
    }

    /// TASK H2 — **this was a constant `false`.** The body used to open
    /// `guard let style = value as? DocumentCanvasView.SpellStyle`, and the layout controller never
    /// sends a Swift enum: for a correction it sends a **boxed integer** under
    /// `_NSTextAlternativesDisplayStyleAttributeName` (upstream pins exactly that, `@1` under that
    /// key, `Tests/IDBlockSpellingIntegrationTests.m:326-341`). So the cast always failed, the method
    /// always answered `false`, nothing was stored, and nothing painted — G1/G2's ranked suspect 1,
    /// and the "constant `false` return" shape this port has now produced four times.
    ///
    /// The classifier is REUSED, not rewritten: `DocumentCanvasView.markerStyle(fromAttributes:)` is
    /// the canvas's own reading of these exact keys, previously wired only to the checking-controller
    /// path. A `SpellStyle` value is still accepted verbatim (the in-tree callers pass one).
    ///
    /// `range` must still resolve to a checkable, non-excluded region (the same
    /// `clampedSpellRegionLocal` gate the native controller's own delivery path uses), so this can't
    /// flag text inside a link / inline-code / spoiler run, the active IME composition, or the word
    /// currently under the caret — exactly like the legacy `applyNativeAnnotations` it wraps.
    ///
    /// **Measured caveat, stated because it bounds the claim:** this member is on the kernel's
    /// layout-controller path, and that path did NOT fire on either arm while the private checking
    /// controller flagged a misspelling (Task H2's probe: `addAnnotationAttribute:value:forRange:`
    /// and `addRenderingAttributes:forRange:` recorded zero calls under both `.inputDec` and
    /// `.legacy`). So this fix removes a real constant `false` and is covered by
    /// `TelegramAnnotationInputClientTests`, but it is NOT what made the user's underline appear —
    /// that was the canvas's own client surface (`DocumentCanvasView+NativeTextCheckingClient.swift`).
    @discardableResult
    func addAnnotation(key: AnyHashable, value: Any, range: NSRange, revision: UInt64) -> Bool {
        guard let style = Self.spellStyle(forKey: key, value: value) else { return false }
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
        guard let (region, _) = canvas.leafRegion(containingGlobal: range.location),
              canvas.spellCheckableRef(region.ref) != nil else { return false }
        canvas.clearNativeAnnotations(global: range)   // also calls setNeedsSpellUnderlineDisplay()
        canvas.bumpLayoutGeneration()
        return true
    }

    @discardableResult
    func addRenderingAttributes(_ attributes: [NSAttributedString.Key: Any], range: NSRange, revision: UInt64) -> Bool {
        guard range.location >= 0, range.length >= 0,
              range.location + range.length <= canvas.documentSizeValue else { return false }
        guard let (region, local) = canvas.leafRegion(containingGlobal: range.location) else { return false }
        var applied = false
        // TASK H2 — the transient spell marker. Upstream turns EVERY key of this dictionary into a
        // TextKit-2 temporary attribute (`IDRichTextLayoutController.m:1428-1443`) and its underline
        // is drawn from them; this renderer has no general temporary-attribute channel, so the
        // marker is translated into `spellResults`, which is what the underline overlay draws from.
        // Same `clampedSpellRegionLocal` exclusion gate as `addAnnotation`, for the same reason.
        if let style = DocumentCanvasView.markerStyle(fromAttributes: attributes),
           canvas.clampedSpellRegionLocal(global: range) != nil {
            canvas.applyNativeAnnotations(global: range, style: style)
            applied = true
        }
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
        guard range.location >= 0, range.length >= 0,
              range.location + range.length <= canvas.documentSizeValue else { return false }
        guard let (region, _) = canvas.leafRegion(containingGlobal: range.location) else { return false }
        var applied = false
        // TASK H2 — symmetric with the marker branch of `addRenderingAttributes` above. Removal is
        // not gated by the exclusion filter, matching `removeAnnotation`'s own rule: a flag can
        // always be cleared regardless of what now overlaps it.
        if !DocumentCanvasView.markerAttributeKeys.isDisjoint(with: keys) {
            canvas.clearNativeAnnotations(global: range)
            applied = true
        }
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

    /// TASK H2 — the key/value pair the layout controller sends, read as a flag style, or `nil` when
    /// it denotes no flag at all.
    ///
    /// A `DocumentCanvasView.SpellStyle` value is accepted verbatim (that is what every in-tree
    /// caller passes and what the previous body required). Everything else is classified by the
    /// canvas's OWN classifier, `markerStyle(fromAttributes:)`, from a one-entry dictionary — the
    /// same shape the checking-controller path hands it. `key` crosses the bridge as an opaque
    /// `AnyHashable` (`IDTextEditorBackendClientBridge.hashableAnnotationKey`), so the three
    /// spellings an ObjC attribute name can arrive as are all unwrapped here rather than assumed.
    private static func spellStyle(forKey key: AnyHashable, value: Any) -> DocumentCanvasView.SpellStyle? {
        if let style = value as? DocumentCanvasView.SpellStyle { return style }
        guard let name = attributeKeyName(key) else { return nil }
        return DocumentCanvasView.markerStyle(fromAttributes: [NSAttributedString.Key(name): value])
    }

    private static func attributeKeyName(_ key: AnyHashable) -> String? {
        if let name = key.base as? String { return name }
        if let attributeKey = key.base as? NSAttributedString.Key { return attributeKey.rawValue }
        if let name = key.base as? NSString { return name as String }
        return nil
    }

    /// Marks the underline overlays dirty without touching `spellResults` itself — the pure
    /// "repaint, nothing changed" request the contract's name implies.
    func invalidateTemporaryAttributes(in range: NSRange, revision: UInt64) {
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
