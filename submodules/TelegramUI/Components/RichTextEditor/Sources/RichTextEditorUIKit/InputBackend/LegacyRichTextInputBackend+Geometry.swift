#if canImport(UIKit)
import UIKit

/// TASK 25 — Family 2: geometry. The eight `UITextInput` witnesses that answer OS-facing geometry
/// queries (`firstRect(for:)`, `caretRect(for:)`, `selectionRects(for:)`, `closestPosition(to:)`,
/// `closestPosition(to:within:)`, `characterRange(at:)`, `baseWritingDirection(for:in:)`, and
/// `setBaseWritingDirection(_:for:)`) now live here, forwarding to `TelegramGeometryInputClient` via
/// the `geometry` accessor — the SAME `legacyCaretRect`/`legacyFirstRect`/`legacySelectionSegments`/
/// `closestGlobalPosition`/`resolvedDirection` canvas helpers the pre-seam witnesses called directly,
/// just reached one hop further out. Every body below is a byte-for-byte-equivalent translation of the
/// canvas witness it replaces — verified per-member below, not assumed.
///
/// **FIX ROUND 1 (Critical, reviewer)** — that "verified per-member" claim was WRONG for
/// `selectionRects(for:)`: the original body took `containsStart`/`containsEnd` straight from
/// `RichTextInputSelectionSegment`, which `legacySelectionSegments` derives per REGION (endpoint-owner
/// resolution), not per RECT (array position) the way the pre-seam witness did — a real, reachable
/// divergence on ordinary multi-line selections. See that member's own doc comment for the fix and
/// `BoundedSelectionGeometryTests` for the re-based/added tests. The clamp-vs-reject bounds-semantics
/// paragraph below was independently re-verified and still holds — this was a DIFFERENT axis of the
/// same member (which rule assembles the two descriptive flags), not a bounds question.
///
/// **Deviation D9 — where the `?? .zero` / `?? []` translation lives.** The geometry CLIENT boundary
/// (`RichTextInputGeometryClient`) returns `nil` for missing geometry, per the spec's "never a
/// fabricated `CGRect.zero`". UIKit's own `caretRect(for:)`/`firstRect(for:)` are non-optional and
/// existing callers already branch on `.zero` (`+Interaction.swift:126`, `RichTextEditorView.swift:706`,
/// `+EditMenu.swift:35`), so the translation happens HERE, at the backend's UIKit-facing member — NOT
/// in the canvas router (`+UITextInput.swift`, now a pure one-line forward) and NOT inside the client.
/// This is the ONLY transformation performed anywhere in this family — every other member either
/// forwards a value through unchanged or performs pure arithmetic that is itself the pre-seam behavior
/// (see each member below). `GeometryRouterTests` asserts this directly.
///
/// **GEOMETRY-SPECIFIC RULING (carried from the Task 24 review): no `RichTextInputContractViolation`
/// report on any of these eight.** Their fallbacks (`.zero`, `[]`, `nil`) are already each member's own
/// sanctioned answer, and every one of these members is called PER FRAME (caret blink, selection
/// drag, scroll, VoiceOver) — an unthrottled report here is exactly the flooding case Task 24's own
/// fix round warned Family 2 about. Guard and return the sanctioned value, silently.
///
/// **No force-unwraps.** Every member below guards `legacyCanvas`/`document`/`geometry` explicitly and
/// returns the fallback the pre-seam witness's own failure branch already returned (a failed `as?`
/// cast, the D9 `.zero`/`[]`, or `nil` where the return type was already optional) — never
/// `legacyCanvas!`/`document!`/`host!`. `document`, `geometry`, and `legacyCanvas` are ALL derived from
/// the same weak `host` (`RichTextInputHost`'s three accessors, plus `LegacyRichTextInputHost`'s
/// `legacyCanvas`, are all non-optional REQUIREMENTS on the host protocol), so they are nil/non-nil
/// TOGETHER — a single combined guard covering all three at once is not a shortcut that hides a
/// half-guarded state, it is the precise shape of the invariant. This closes the exact gap Task 24's
/// Critical opened (nine force-unwraps of these same three accessors, reachable any time `host` is nil
/// while `isAttached` may still read `true` — a swallowed attach, the contract-sanctioned
/// attached-but-host-deallocated state, the detach→reattach window, the canvas's own `deinit` window,
/// or a `DocumentTokenizer` querying during interaction teardown). R15
/// (`Tests/RichTextEditorCoreTests/SourceBoundary/InputBackendSourceBoundaryTests.swift`) now makes
/// this mechanically enforced under the whole `InputBackend/` tree, not just this family.
///
/// **Bounds semantics — clamp vs. reject (D27 follow-on question, carried from Task 24's review).**
/// Every member below was checked against its pre-seam witness's OWN bounds behavior (not assumed):
/// `firstRect`, `caretRect`, `closestPosition` (both arities), and `characterRange(at:)` all reproduce
/// the pre-seam witness EXACTLY, because `TelegramGeometryInputClient`'s own bodies are, byte for byte,
/// the SAME `legacyFirstRect`/`legacyCaretRect`/`closestGlobalPosition`/arithmetic the witnesses called
/// directly — there is no second implementation to diverge from the first. `selectionRects(for:)`
/// is the one member whose client path (`selectionSegments(for:revision:)`) clamps both endpoints via
/// `canvas.clampGlobal(...)` before the pre-seam witness's own `selectionRects(globalFrom:globalTo:)`
/// did NOT — but that clamp is a no-op relative to the per-region clamping
/// `selectionRects(globalFrom:globalTo:)`/`legacySelectionSegments` already does internally (every
/// leaf region's `max(globalFrom, r.globalStart)`/`min(globalTo, r.globalStart + r.length)` already
/// bounds the effective range to `[0, documentSize]`-ish territory regardless of what raw values come
/// in, and `leafRegionEndpoint`'s own degrade-at-the-extremes fallback — `.following` past the last
/// region already falls back to `all.last`, `.preceding` before the first already falls back to
/// `all.first` — produces the identical endpoint pick whether the caller pre-clamps or not). Traced
/// algebraically against `leafRegionEndpoint`/`legacySelectionSegments`
/// (`Canvas/DocumentCanvasView.swift`) for both a very-negative and a very-large endpoint; no
/// observable divergence found. **Conclusion: unlike Family 1's `text(in:)` (which had to bypass
/// `TelegramDocumentInputClient.plainText(in:)` because that client REJECTS an out-of-bounds range
/// where the canvas clamps), Family 2's geometry client was built clamp-compatible from the start
/// (Tasks 15-16) — there is no clamp-vs-reject divergence to route around or file here.** Nothing is
/// added to the D27 follow-on project by this family.
@available(iOS 13.0, *)
extension LegacyRichTextInputBackend {
    // MARK: - Caret / range rects

    /// Was `DocumentCanvasView.caretRect(for:)`. `caretRect` must report a REAL position even when the
    /// visible caret is hidden (a structural row/column selection, or a tap-selected image) — it feeds
    /// the OS's nav/scroll/loupe/edit-menu geometry, per `legacyCaretRect`'s own doc comment
    /// (`+UITextInput.swift`), which this body reaches unchanged through the geometry client.
    ///
    /// DEVIATION D34 (disclosed performance regression, NOT a behavior change — reviewer Major, fix
    /// round 1). `caretGeometry(at:revision:purpose:)` computes `rect`/`writingDirection`/`lineID` in
    /// one call — 3 `allLeafRegions()` walks plus an O(n) prefix `reduce` inside
    /// `legacyLineRegion(containingGlobal:)` — and this member reads only `.rect`, discarding the other
    /// three. Pre-seam cost was 1 walk. `caretRect(for:)` is reached from 7 canvas-internal call sites,
    /// two of which (`+Interaction.swift:579-580`) run per drag frame. Filed against the D26/D27
    /// follow-on project rather than fixed here: restoring the single-walk shape means either bypassing
    /// this member's own client-routing shape or fusing three independent, already-shipped canvas APIs
    /// into one internal query — real feature work with its own correctness surface, not a two-line
    /// patch, and risking a new bug in a function every OTHER `caretGeometry` caller also depends on.
    func caretRect(for position: UITextPosition) -> CGRect {
        guard let p = position as? LegacyTextPosition, let document = self.document,
              let geometry = self.geometry else { return .zero }
        // Deviation D9: the geometry CLIENT returns nil for missing geometry, per the spec's
        // "never a fabricated CGRect.zero". UIKit's caretRect(for:) is non-optional and existing
        // callers branch on .zero (+Interaction.swift:126, RichTextEditorView.swift:706,
        // +EditMenu.swift:35), so the translation happens here, at the UIKit edge, and nowhere else.
        return geometry.caretGeometry(at: .downstream(p.offset),
                                      revision: document.revision,
                                      purpose: .caret)?.rect ?? .zero
    }

    /// Was `DocumentCanvasView.firstRect(for:)`. Ordered exactly like the pre-seam witness (`min`/`max`,
    /// no clamp — see this file's header comment for why no clamp is needed: `legacyFirstRect` already
    /// degrades gracefully at any range, in or out of bounds).
    func firstRect(for range: UITextRange) -> CGRect {
        guard let r = range as? LegacyTextRange, let document = self.document,
              let geometry = self.geometry else { return .zero }
        let lo = min(r.from.offset, r.to.offset), hi = max(r.from.offset, r.to.offset)
        // Deviation D9, same rationale as `caretRect(for:)` above.
        return geometry.firstRect(for: NSRange(location: lo, length: hi - lo),
                                  revision: document.revision,
                                  purpose: .selectionEndpoint) ?? .zero
    }

    /// Was `DocumentCanvasView.selectionRects(for:)`.
    ///
    /// DEVIATION D26. The bounded request (Task 16) is BUILT and PROVEN, but nothing in production
    /// sends it in stage 1: this witness passes `visibleRect: nil`, and
    /// TelegramPresentationInputClient.apply still delegates to refreshSelectionUI() (DCV:1536),
    /// which walks allLeafRegions(). Bounding either one changes what is drawn during a large
    /// Select All (offscreen wash segments stop being realized until scrolled to) — a
    /// performance-motivated BEHAVIOR change, forbidden inside an extraction by Global
    /// Constraint 17, and it needs a scroll-driven re-request path that does not exist yet.
    /// Adopting it is the first task of the follow-on project; this client API is what that
    /// project consumes. Phase 6 gate item 8 is worded to match.
    ///
    /// FIX ROUND 1 (Critical, reviewer) — `containsStart`/`containsEnd` are derived HERE, by ARRAY
    /// POSITION over `segments` (`index == 0` / `index == segments.count - 1`), exactly like the
    /// pre-seam witness derived them over its own flat rect list. They are NOT taken from
    /// `RichTextInputSelectionSegment.containsStart`/`.containsEnd` — `legacySelectionSegments`
    /// derives THOSE per REGION, from the endpoint-owner resolution (`leafRegionEndpoint`,
    /// `DocumentCanvasView.swift`), a DIFFERENT rule: a region contributing 2+ rects (any region
    /// whose text WRAPS at the layout width) would carry the SAME region-level flag on every one of
    /// those rects, so a 3-line single-paragraph selection came back with EVERY rect
    /// `containsStart == containsEnd == true` where the pre-seam witness flagged only the first/last
    /// rect; and an endpoint landing exactly on the FOLLOWING region's `globalStart` (a 2-position-wide
    /// structural gap) could leave NO rect flagged `containsEnd` at all, since that region's clamped
    /// span is empty and never appears in `segments`. Per-index derivation over `segments` is exactly
    /// equivalent to the pre-seam algorithm because `segments`' iteration order and per-region rect
    /// expansion (one entry per `r.layout.selectionRects(start:end:)` result) are IDENTICAL to
    /// `selectionRects(globalFrom:globalTo:)`'s own — both walk `allLeafRegions()` in the same order
    /// and call the same per-region method with `visibleRect: nil` — so `segments.count == rects.count`
    /// and the two arrays correspond index-for-index.
    ///
    /// DEVIATION D34 (disclosed performance regression, NOT a behavior change — reviewer Major, fix
    /// round 1, same deviation as `caretRect(for:)` above). `legacyCanvas`'s `leafRegionEndpoint` runs
    /// TWICE (once per endpoint) before the main walk, so this member costs 3-5 `allLeafRegions()` walks
    /// against the pre-seam witness's 1. Filed against the D26/D27 follow-on project for the same
    /// reason `caretRect(for:)`'s note gives.
    ///
    /// `BoundedSelectionGeometryTests.test_wrappingRegion_flagsOnlyTheFirstAndLastRectNotEveryRectInTheRegion`
    /// pins the wrapping case that was missed. The two pre-existing tests that used to be cited here as
    /// standing proof — `test_segmentsMatchTheWitnessRectsForASmallSelection` and
    /// `test_containsEndMatchesTheWitnessAtAnInteriorStructuralGap` — were re-based onto a frozen,
    /// independently-computed oracle (`preSeamWitnessRects(_:from:to:)`, inlining the array-position
    /// algorithm over the UNTOUCHED `selectionRects(globalFrom:globalTo:)` helper) because comparing
    /// against `v.selectionRects(for:)` — the now-ROUTED witness — had become tautological: after this
    /// family landed, both sides of that comparison ran through this very function.
    func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        guard let r = range as? LegacyTextRange, let document = self.document,
              let geometry = self.geometry else { return [] }
        let lo = min(r.from.offset, r.to.offset), hi = max(r.from.offset, r.to.offset)
        let request = RichTextInputSelectionGeometryRequest(
            range: NSRange(location: lo, length: hi - lo), visibleRect: nil,
            includeStartEndpoint: true, includeEndEndpoint: true, purpose: .selectionPresentation)
        let segments = geometry.selectionSegments(for: request, revision: document.revision) ?? []
        return segments.enumerated().map { index, seg in
            LegacySelectionRect(rect: seg.rect, containsStart: index == 0, containsEnd: index == segments.count - 1)
        }
    }

    // MARK: - Hit testing

    /// Was `DocumentCanvasView.closestPosition(to:)`. The pre-seam witness never returned `nil` (it
    /// always wrapped `closestGlobalPosition(to:)`'s Int), but this member's return type is optional
    /// UIKit protocol surface — the ONLY reachable `nil` here is the documented detached window (no
    /// `document`/`geometry`), which cannot occur while `revision` is read fresh from the SAME call
    /// (see this file's header note on the three accessors' shared nil-ness).
    func closestPosition(to point: CGPoint) -> UITextPosition? {
        guard let document = self.document, let geometry = self.geometry,
              let p = geometry.closestPosition(to: point, within: nil,
                                               revision: document.revision,
                                               purpose: .selectionEndpoint) else { return nil }
        return LegacyTextPosition(p.utf16Offset)
    }

    /// Was `DocumentCanvasView.closestPosition(to:within:)`. `range.location + range.length` recovers
    /// `r.to.offset` even when `r.from.offset > r.to.offset` (an UNORDERED range — the canvas hands
    /// UIKit one of these for a reversed drag, per `RichTextCanonicalSelection.normalizedRange`'s own
    /// doc comment), because `NSRange` here is plain arithmetic storage with no validation: the client's
    /// `min(max(offset, range.location), range.location + range.length)` reduces to EXACTLY the
    /// pre-seam witness's own `min(max(p.offset, r.from.offset), r.to.offset)` — including its
    /// pre-existing behavior of always collapsing to `r.to.offset` on a reversed range (`max(p, from)`
    /// is always `>= from > to` there, so the outer `min(_, to)` always wins). Not a clamp-vs-reject
    /// divergence — the SAME formula, just carried through an `NSRange` rather than two raw `Int`s.
    func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
        guard let r = range as? LegacyTextRange, let document = self.document,
              let geometry = self.geometry,
              let p = geometry.closestPosition(
                  to: point,
                  within: NSRange(location: r.from.offset, length: r.to.offset - r.from.offset),
                  revision: document.revision,
                  purpose: .selectionEndpoint) else { return nil }
        return LegacyTextPosition(p.utf16Offset)
    }

    /// Was `DocumentCanvasView.characterRange(at:)`. The client's own body is the exact same
    /// `closestGlobalPosition(to:)` + `min(p + 1, documentSizeValue)` arithmetic the pre-seam witness
    /// used (`documentSizeValue == documentSize`), so this reproduces it exactly.
    func characterRange(at point: CGPoint) -> UITextRange? {
        guard let document = self.document, let geometry = self.geometry,
              let r = geometry.characterRange(at: point, revision: document.revision) else { return nil }
        return LegacyTextRange(LegacyTextPosition(r.location), LegacyTextPosition(r.location + r.length))
    }

    // MARK: - Writing direction

    /// Was `DocumentCanvasView.baseWritingDirection(for:in:)`. The pre-seam witness's cast-failure
    /// fallback was `typingWritingDirection` (a CANVAS-STATE-DEPENDENT value, not a constant) — so the
    /// combined guard below covers BOTH failure modes with the fallback each one needs: on a cast
    /// failure with an attached canvas, `self.legacyCanvas` is still available and `typingWritingDirection`
    /// is read from the live canvas, exactly like the pre-seam witness; only in the genuinely detached
    /// window (no host at all) does it fall further, to `.leftToRight` (the same constant the geometry
    /// client's own revision-mismatch fallback already uses for this member, and there is no live
    /// canvas to derive a typing direction from in that window). `resolvedDirection(forGlobal:)` never
    /// returns `.natural` (verified: every branch of `DocumentCanvasView+WritingDirection.swift`
    /// resolves to `.leftToRight`/`.rightToLeft` only), so the client's two-case
    /// `RichTextInputWritingDirection` loses no information translating back to `NSWritingDirection`.
    func baseWritingDirection(for position: UITextPosition, in direction: UITextStorageDirection) -> NSWritingDirection {
        guard let p = position as? LegacyTextPosition, let document = self.document,
              let geometry = self.geometry else {
            return self.legacyCanvas?.typingWritingDirection ?? .leftToRight
        }
        let resolved = geometry.baseWritingDirection(at: .downstream(p.offset), revision: document.revision)
        return resolved == .rightToLeft ? .rightToLeft : .leftToRight
    }

    /// Was `DocumentCanvasView.setBaseWritingDirection(_:for:)` — already an empty no-op body there.
    /// No-op by design, ported verbatim: the whole-document override (`layoutDirectionModel`) is the
    /// single manual control, so per-range UIKit writing-direction writes are ignored (that would imply
    /// per-paragraph control the editor deliberately does not build). This relocation is
    /// behavior-preserving on its own terms — an empty body moved from one type to another performs
    /// identically — and touches none of `legacyCanvas`/`document`/`geometry`, so there is no
    /// host-reachability question for it at all.
    func setBaseWritingDirection(_ direction: NSWritingDirection, for range: UITextRange) {}
}
#endif
