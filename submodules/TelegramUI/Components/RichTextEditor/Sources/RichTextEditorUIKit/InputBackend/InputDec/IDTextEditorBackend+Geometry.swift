#if canImport(UIKit)
import UIKit
import RichTextInputDecObjC

/// TASK F1 — Family 2 (geometry), REROUTED from the kernel onto the host-supplied geometry client.
///
/// # Why these eight members left `IDTextEditorBackend.swift`
///
/// Task C5 routed them into `kernelInput`, one bare forward each. That was wrong on two independent
/// axes, and the second one crashed the app on the very first tap (`Telegram-2026-08-26-171558.ips`,
/// `EXC_BREAKPOINT`; see `IDBackendCaretPlacementGeometryTests` for the reproduction):
///
///  1. **The kernel is not the geometry authority — Telegram is.** The vendored kernel lays out
///     through its OWN synthetic, unstyled `NSTextContainer` and has never been told anything about
///     this editor's blocks, fonts, page margins, table scrolling or viewport offsets. R8 instrumented
///     the `id_` geometry bridge and measured ZERO calls through it for point hit-testing; the
///     differential corpus measured 108 `caretRect` and 108 `selectionRects` divergences from stock
///     attributed to exactly this (`docs/input-backend-differential-baseline.md` §8.3(a)). The
///     authority is `RichTextInputGeometryClient` — the client the spec names as "the sole authority"
///     for caret, point, range, line and navigation geometry, and the one
///     `LegacyRichTextInputBackend+Geometry.swift` has always used. Routing here is IMPLEMENTING the
///     contract, not working around the kernel: the pinned test is literally named
///     `IDBackendFamily2Tests.test_caretRectForAKnownOffset_matchesTheGeometryClient`.
///
///  2. **The kernel cannot even be ASKED with the position the production caller hands us.**
///     `DocumentCanvasView+UITextInput.swift`'s `caretRect(atGlobal:)` — the spelling five canvas
///     sites, `+EditMenu.swift` and `RichTextEditorView.scrollCaretIntoView(animated:)` all use —
///     mints a canvas-side identity object (`LegacyTextIdentity.position(atGlobal:)`) regardless of
///     which backend is installed. `TGRichTextInputDecLayoutController` casts every incoming position
///     to `TGRichTextInputDecPosition` UNCHECKED and sends it `-utf16Offset`, so forwarding that
///     object raised `unrecognized selector`, the exception guard converted it to an `NSError`, and
///     `reportKernelFailure(_:witness:)` trapped in DEBUG. Every pre-existing `IDBackendFamily2Tests`
///     case passed a KERNEL-minted position instead, which is why the suite never saw it.
///
/// # The position axis, and why `LegacyTextIdentity` is read here
///
/// Both identity types carry the SAME number: a canvas-global UTF-16 offset.
/// `IDTextEditorBackendClientBridge.caretGeometry(atOffset:…)` already hands
/// `TGRichTextInputDecPosition.utf16Offset` straight to `RichTextInputGeometryClient` untranslated,
/// and `TelegramGeometryInputClient` feeds it to `canvas.clampGlobal(_:)`/`legacyCaretRect(globalOffset:)`
/// — the same axis `LegacyTextPosition.offset` is on. So `resolvedGlobalOffset(of:)` below accepts
/// EITHER and rejects everything else.
///
/// Reading `LegacyTextIdentity` from the ID backend is deliberate and is the narrow, hotfix-shaped
/// choice. That namespace's own doc comment anticipates a stage-2 backend having a DIFFERENT identity
/// surface — but the canvas mints Legacy-shaped identity at seven sites today
/// (`caretRect(atGlobal:)`, `setSelectedGlobalRange(from:to:)`, `documentEndOffset`,
/// `+SelectionActions.swift`, `+NativeTextCheckingClient.swift`), so under `.inputDec` it is in
/// practice the CANVAS's vocabulary, not the legacy backend's. Accepting it here is what makes the
/// production caret path work at all; making the canvas mint backend-neutral identity is real
/// follow-on work (see this task's report). Only the sanctioned `LegacyTextIdentity` accessors are
/// used — never the identity types themselves — so nothing new is coupled to their shape.
///
/// # Deviation D9 is preserved exactly
///
/// The geometry CLIENT returns `nil` for missing geometry ("never a fabricated `CGRect.zero`"); the
/// `?? .zero` / `?? []` translation happens HERE, at the UIKit-facing witness, and nowhere else —
/// existing callers branch on `.zero` (`+Interaction.swift`, `RichTextEditorView.swift`,
/// `+EditMenu.swift`). Same rule, same place, as `LegacyRichTextInputBackend+Geometry.swift`.
///
/// # No `RichTextInputContractViolation` report on any of these eight
///
/// Carried verbatim from the legacy family's own ruling: every member here is called PER FRAME
/// (caret blink, selection drag, scroll, VoiceOver), their fallbacks are each member's own sanctioned
/// answer, and an unthrottled report would flood. Guard and return the sanctioned value, silently.
/// They also no longer touch `kernelInput` at all, so there is nothing here for
/// `reportKernelFailure(_:witness:)` to record — which is the point.
@available(iOS 17.0, *)
extension IDTextEditorBackend {
    // MARK: - Position / range resolution

    /// The canvas-global UTF-16 offset carried by `position`, or `nil` when it was minted by neither
    /// this backend (`TGRichTextInputDecPosition`, what the kernel and this backend's own Family-1
    /// witnesses vend) nor the canvas (`LegacyTextIdentity`, what `caretRect(atGlobal:)` and friends
    /// vend). `nil` is what makes `test_caretRectForAnUnrenderablePositionIsZero` — a genuinely
    /// foreign `UITextPosition` conformer — still degrade to `.zero` rather than fabricate a rect.
    func resolvedGlobalOffset(of position: UITextPosition) -> Int? {
        if let p = position as? TGRichTextInputDecPosition { return p.utf16Offset }
        return LegacyTextIdentity.globalOffset(of: position)
    }

    /// The two endpoints of `range`, UNORDERED and verbatim — `min`/`max` is each caller's own job,
    /// exactly as in the legacy family (an unordered range is load-bearing for a reversed drag; see
    /// `RichTextCanonicalSelection.normalizedRange`). Resolved endpoint-by-endpoint rather than by
    /// narrowing the RANGE type, so a `TGRichTextInputDecRange` and a canvas-minted range both work
    /// through one path.
    func resolvedGlobalRange(of range: UITextRange) -> (from: Int, to: Int)? {
        guard let from = resolvedGlobalOffset(of: range.start),
              let to = resolvedGlobalOffset(of: range.end) else { return nil }
        return (from, to)
    }

    /// TASK F4 — re-mints `range` as the kernel's own `TGRichTextInputDecRange` when it was minted
    /// by the CANVAS (`LegacyTextIdentity`), and answers `nil` when no re-minting is needed or
    /// possible: nil for a range the kernel already understands (it is passed through untouched)
    /// and nil for a genuinely foreign `UITextRange` (which must keep degrading, never be
    /// fabricated into a range over the document).
    ///
    /// Exists because the kernel casts every incoming range to its own type unchecked — the same
    /// asymmetry that was defect 1 of task F1, here reached by `IDTextEditorBackend.text(in:)`
    /// rather than by a geometry witness. Endpoints are stamped with the LIVE document revision,
    /// matching `mintedPosition(at:affinity:revision:)`'s own convention (a current stamp lets the
    /// kernel's `TGResolvePosition` skip a rebase it does not need).
    func normalizedKernelRange(for range: UITextRange) -> UITextRange? {
        if range is TGRichTextInputDecRange { return nil }
        guard let resolved = resolvedGlobalRange(of: range) else { return nil }
        let revision = host?.documentClient.revision ?? state.documentRevision
        return TGRichTextInputDecRange(
            from: TGRichTextInputDecPosition(offset: resolved.from, affinity: .forward,
                                             revision: revision),
            to: TGRichTextInputDecPosition(offset: resolved.to, affinity: .forward,
                                           revision: revision))
    }

    /// TASK H2 — the POSITION twin of `normalizedKernelRange(for:)`, and the same asymmetry it
    /// exists for: the kernel casts every incoming position to `TGRichTextInputDecPosition`
    /// unchecked and sends it `-utf16Offset`, so a CANVAS-minted `LegacyTextPosition` raises
    /// `unrecognized selector`, the exception guard converts it to an `NSError`, and the witness
    /// falls back to its sanctioned "no reply" answer.
    ///
    /// **That fallback is a WRONG answer, not an absent one, and it was the second half of the
    /// spelling defect.** `compare(_:to:)` has no "unknown" case and answers `.orderedSame`;
    /// `offset(from:to:)` answers `0`. Both read as "these two positions are the same place".
    /// Measured on an attached `.inputDec` canvas while the private checking controller was
    /// resolving the word `"mispelled"` (a swizzle over the canvas's `UITextInput` witnesses; `L` =
    /// canvas identity, `k` = kernel identity):
    ///
    /// ```
    /// compare(k1,k11)=-1      <- both kernel-minted: correct
    /// compare(L1,k11)= 0      <- the range the CHECKER handed in; reads as an EMPTY word
    /// ```
    ///
    /// The controller had already read the text back correctly by that point and stopped there,
    /// having concluded the word it was asked about was zero characters long. The `L1` comes from
    /// `DocumentCanvasView.nativeTextRange(forGlobalLocation:length:)`, which mints the canvas shape
    /// under EVERY backend (F4's finding, unchanged) — so this backend must accept it.
    ///
    /// `nil` means "no re-minting needed or possible": nil for a position the kernel already
    /// understands (passed through untouched) and nil for a genuinely foreign `UITextPosition`,
    /// which must keep degrading rather than be fabricated into an offset in the document.
    /// Affinity is `.forward` and the revision is the live one, matching
    /// `normalizedKernelRange(for:)`'s own convention — a canvas-minted position carries neither.
    func normalizedKernelPosition(for position: UITextPosition) -> UITextPosition? {
        if position is TGRichTextInputDecPosition { return nil }
        guard let offset = resolvedGlobalOffset(of: position) else { return nil }
        let revision = host?.documentClient.revision ?? state.documentRevision
        return TGRichTextInputDecPosition(offset: offset, affinity: .forward, revision: revision)
    }

    /// The identity object this backend hands BACK to UIKit for a resolved offset. Must be a
    /// `TGRichTextInputDecPosition`: the answer flows straight into this backend's own Family-1
    /// witnesses (`compare(_:to:)`, `offset(from:to:)`, `textRange(from:to:)`, `position(from:offset:)`),
    /// every one of which still routes into the kernel — and the kernel accepts only its own type
    /// (that asymmetry is the whole of defect 2 above). Stamped with the revision the query was
    /// answered at, so `TGResolvePosition` sees a current position and preserves the affinity rather
    /// than paying for a rebase.
    private func mintedPosition(at offset: Int, affinity: RichTextInputAffinity,
                                revision: UInt64) -> UITextPosition {
        TGRichTextInputDecPosition(offset: offset,
                                   affinity: affinity == .upstream ? .backward : .forward,
                                   revision: revision)
    }

    // MARK: - Caret / range rects

    /// Mirrors `LegacyRichTextInputBackend.caretRect(for:)`. `caretRect` must report a REAL position
    /// even when the visible caret is hidden (a structural row/column selection, a tap-selected
    /// image) — it feeds the OS's nav/scroll/loupe/edit-menu geometry.
    func caretRect(for position: UITextPosition) -> CGRect {
        guard let host, let offset = resolvedGlobalOffset(of: position) else { return .zero }
        // D9: the client answers nil for missing geometry; the `.zero` translation lives here.
        return host.geometryClient.caretGeometry(at: .downstream(offset),
                                                 revision: host.documentClient.revision,
                                                 purpose: .caret)?.rect ?? .zero
    }

    /// Mirrors `LegacyRichTextInputBackend.firstRect(for:)` — ordered `min`/`max`, no clamp (the
    /// client degrades gracefully at any range, in or out of bounds).
    func firstRect(for range: UITextRange) -> CGRect {
        guard let host, let r = resolvedGlobalRange(of: range) else { return .zero }
        let lo = min(r.from, r.to), hi = max(r.from, r.to)
        return host.geometryClient.firstRect(for: NSRange(location: lo, length: hi - lo),
                                             revision: host.documentClient.revision,
                                             purpose: .selectionEndpoint) ?? .zero
    }

    /// Mirrors `LegacyRichTextInputBackend.selectionRects(for:)` with ONE deliberate difference: the
    /// request is BOUNDED by the host input view's bounds, where legacy passes `visibleRect: nil`.
    ///
    /// That is not a liberty — it is this backend's specified behaviour, pinned by
    /// `IDBackendFamily2Tests.test_selectionRectsAreBoundedByTheVisibleRect` (500-paragraph Select
    /// All; the request the client receives must carry `visibleRect == canvas.bounds`) and by
    /// `…test_selectAllRealizesNoAdditionalBlockViews` beside it. Legacy's own deviation **D26**
    /// records that the bounded request is BUILT and PROVEN at the client boundary but deliberately
    /// unsent by the legacy witness, because adopting it there would change what the LEGACY canvas
    /// draws during a large Select All — a behaviour change forbidden inside that extraction. No such
    /// constraint applies here: this witness is new code with its own pinned expectation.
    ///
    /// `containsStart`/`containsEnd` are derived BY ARRAY POSITION over `segments`, never taken from
    /// `RichTextInputSelectionSegment.containsStart`/`.containsEnd`. This carries legacy's fix-round-1
    /// Critical: the client derives those flags per REGION (endpoint-owner resolution), so a region
    /// whose text WRAPS contributes several rects all carrying the same region-level flag — a
    /// three-line single-paragraph selection would come back with EVERY rect flagged both start and
    /// end. `isVertical`/`writingDirection` DO come from the segment (legacy's `LegacySelectionRect`
    /// hard-codes them because its own pre-seam witness did; `TGRichTextInputDecSelectionRect` models
    /// both, and `IDTextEditorBackendClientBridge.selectionRects(forRange:visibleRect:revision:)`
    /// already fills them from the segment, so this matches the ID backend's own established shape).
    func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        guard let host, let r = resolvedGlobalRange(of: range) else { return [] }
        let lo = min(r.from, r.to), hi = max(r.from, r.to)
        let request = RichTextInputSelectionGeometryRequest(
            range: NSRange(location: lo, length: hi - lo),
            visibleRect: host.hostInputView.bounds,
            includeStartEndpoint: true, includeEndEndpoint: true,
            purpose: .selectionPresentation)
        let segments = host.geometryClient.selectionSegments(
            for: request, revision: host.documentClient.revision) ?? []
        return segments.enumerated().map { index, segment in
            TGRichTextInputDecSelectionRect(
                rect: segment.rect,
                containsStart: index == 0,
                containsEnd: index == segments.count - 1,
                isVertical: segment.isVertical,
                writingDirection: segment.writingDirection == .rightToLeft ? .rightToLeft : .leftToRight)
        }
    }

    // MARK: - Hit testing

    /// Mirrors `LegacyRichTextInputBackend.closestPosition(to:)`. The only reachable `nil` is the
    /// documented detached window (no host) or a client that declines to resolve the point.
    func closestPosition(to point: CGPoint) -> UITextPosition? {
        guard let host else { return nil }
        let revision = host.documentClient.revision
        guard let p = host.geometryClient.closestPosition(to: point, within: nil,
                                                          revision: revision,
                                                          purpose: .selectionEndpoint) else { return nil }
        return mintedPosition(at: p.utf16Offset, affinity: p.affinity, revision: revision)
    }

    /// Mirrors `LegacyRichTextInputBackend.closestPosition(to:within:)`, including its handling of an
    /// UNORDERED range: `NSRange(location: from, length: to - from)` is plain arithmetic storage with
    /// no validation, and the client's `min(max(offset, location), location + length)` reduces to the
    /// same formula legacy's own witness applies — collapsing to `to` on a reversed range, exactly as
    /// legacy already does.
    func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
        guard let host, let r = resolvedGlobalRange(of: range) else { return nil }
        let revision = host.documentClient.revision
        guard let p = host.geometryClient.closestPosition(
                to: point,
                within: NSRange(location: r.from, length: r.to - r.from),
                revision: revision,
                purpose: .selectionEndpoint) else { return nil }
        return mintedPosition(at: p.utf16Offset, affinity: p.affinity, revision: revision)
    }

    /// Mirrors `LegacyRichTextInputBackend.characterRange(at:)`. The minted endpoints carry
    /// `.downstream`: the client returns an `NSRange`, which models no affinity of its own, and
    /// `.downstream`/`.forward` is the seam's documented default (deviation D6).
    func characterRange(at point: CGPoint) -> UITextRange? {
        guard let host else { return nil }
        let revision = host.documentClient.revision
        guard let r = host.geometryClient.characterRange(at: point, revision: revision) else { return nil }
        guard let start = mintedPosition(at: r.location, affinity: .downstream, revision: revision)
                as? TGRichTextInputDecPosition,
              let end = mintedPosition(at: r.location + r.length, affinity: .downstream, revision: revision)
                as? TGRichTextInputDecPosition else { return nil }
        return TGRichTextInputDecRange(from: start, to: end)
    }

    // MARK: - Writing direction

    /// Mirrors `LegacyRichTextInputBackend.baseWritingDirection(for:in:)`. The client's
    /// `RichTextInputWritingDirection` has two cases and never answers `.natural`, so translating
    /// back to `NSWritingDirection` loses nothing. Unresolvable position or no host: `.natural` — the
    /// same "no directional claim" absent value the pre-F1 witness used, and the honest answer when
    /// there is no position to resolve a direction FOR.
    func baseWritingDirection(for position: UITextPosition,
                              in direction: UITextStorageDirection) -> NSWritingDirection {
        guard let host, let offset = resolvedGlobalOffset(of: position) else { return .natural }
        let resolved = host.geometryClient.baseWritingDirection(at: .downstream(offset),
                                                                revision: host.documentClient.revision)
        return resolved == .rightToLeft ? .rightToLeft : .leftToRight
    }

    /// No-op by design, carried unchanged from the pre-F1 body and identical to legacy's: the
    /// whole-document override (`layoutDirectionModel`) is this editor's single manual control, so
    /// per-range UIKit writing-direction writes are ignored.
    func setBaseWritingDirection(_ direction: NSWritingDirection, for range: UITextRange) {}
}
#endif
