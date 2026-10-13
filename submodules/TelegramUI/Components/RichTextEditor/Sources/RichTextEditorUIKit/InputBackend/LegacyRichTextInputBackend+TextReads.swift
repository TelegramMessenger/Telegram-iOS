#if canImport(UIKit)
import UIKit

/// TASK 24 — Family 1: document reads and position/range conversion. The eleven
/// `RichTextInputTextBackend` witnesses that used to run directly on `DocumentCanvasView`
/// (`+UITextInput.swift`, `+Navigation.swift`) now live here. This is the FIRST family whose witnesses
/// are LIVE — the OS calls them constantly (every keystroke, every arrow key, every IME composition
/// reads document context through `text(in:)`/`tokenizer`) — so every body below is a byte-for-byte
/// port of the canvas witness it replaces, not a reimplementation.
///
/// Three routing shapes are used, chosen per member by whether going through a client changes any
/// edge-case behavior (never invented casually — see each member's own comment):
///   1. **Pure arithmetic on the `LegacyTextPosition`/`LegacyTextRange` identity objects** —
///      `textRange(from:to:)`, `compare(_:to:)`, `offset(from:to:)`, `position(within:farthestIn:)` —
///      these never touched canvas state at all, so they need neither a client nor `legacyCanvas`, and
///      carry no `host`-reachability guard for the same reason.
///   2. **The document client** (`TelegramDocumentInputClient`, via `document.utf16Length`) — used
///      ONLY for a pure document-length value read (`endOfDocument`, `characterRange(byExtending:in:)`,
///      `position(from:offset:)`'s bounds check), where the client's value is provably identical to
///      the canvas's own `documentSize` with no differing bounds-rejection semantics to worry about.
///   3. **The `legacyCanvas` D24 escape hatch**, through a purpose-built `legacy`-prefixed hook —
///      the renderable-snapping in `beginningOfDocument`/`endOfDocument`/`position(from:offset:)`
///      (`legacySnapToRenderable(_:forward:)`), the OS-facing navigation stepping in
///      `position(from:in:offset:)` (`legacyPositionOffset(from:in:offset:)`), and `text(in:)` itself
///      (`legacyPlainText(globalFrom:globalTo:)`) — each because the algorithm needs canvas-internal
///      machinery (renderable slots, leaf regions, grapheme stepping) with no client abstraction for
///      it, or (for `text(in:)` specifically) because the document client's OWN `plainText(in:)`
///      rejects an out-of-bounds range instead of clamping it, a real behavior change relative to the
///      original witness — see that member's own comment. **Filed, not fixed**: this means
///      `TelegramDocumentInputClient.plainText(in:)` currently has zero production consumers — a
///      provably behavior-identical client-based version exists (clamp both endpoints to
///      `[0, utf16Length]` before calling the client) but is deliberately NOT adopted here; it is the
///      D27 follow-on project's to pick up (see that deviation's row, corrected by this fix round).
///
/// TASK 24 FIX ROUND 1 (Critical, reviewer Focal Point 1) — read members used to force-unwrap
/// `legacyCanvas!`/`document!` on the theory that nothing calls a witness before `attach(to:)` sets
/// `host`. That is true only for the PRE-attach window; it is FALSE for five reachable POST-attach
/// states, all reducible to `host == nil` while `isAttached` may still read `true`: (1) a swallowed
/// `attach(to:)` throw (`DocumentCanvasView.init`'s own comment: "alive but inert" is a documented,
/// non-crashing degradation, not a trap); (2) the contract-sanctioned "host deallocated while still
/// attached" state `BackendAttachDetachTests.test_backendRetainsHostWeakly` asserts directly; (3) the
/// detach → re-attach window; (4) `DocumentCanvasView.deinit`, where Swift zeroes `weak host` BEFORE
/// `deinit`'s body runs, while `self` is still fully alive; (5) a concrete driver for (4):
/// `DocumentTokenizer` holds `unowned canvas` and UIKit retains the tokenizer object across that same
/// window, so a tokenizer query during interaction teardown reads a live `canvas` but a nil `host`.
/// Every read member below now guards `legacyCanvas`/`document` explicitly and returns the SAME value
/// its own pre-seam failure branch already returned (a failed `as?` cast, or the out-of-bounds `nil`,
/// or — for the two non-optional document-bounds members — the pre-Task-24 stub's own
/// `LegacyTextPosition(0)`). `tokenizer` has no such natural fallback (its return type is
/// non-optional and unrelated to any cast), so it is built EAGERLY in `attach(to:)` (where `host` is
/// non-nil by construction) and reset in `performDetachSteps()` (Major 1) — the read path here never
/// dereferences `legacyCanvas` at all, falling back to a stateless no-op tokenizer for the
/// (documented) window where no attached canvas exists. Per the review's guidance, only the three
/// non-per-keystroke members (`tokenizer`, `beginningOfDocument`, `endOfDocument`) report a
/// `RichTextInputContractViolation` on the fallback path — the remaining members are on the IME's
/// per-keystroke read path, where an unthrottled report would flood.
@available(iOS 13.0, *)
extension LegacyRichTextInputBackend {
    // MARK: - `tokenizer`

    /// Was `DocumentCanvasView.tokenizer` (`+UITextInput.swift`). The lazy cache moved from the
    /// canvas's own `inputTokenizer` storage to this class's `tokenizerStorage` at Task 24 — but is
    /// built EAGERLY at `attach(to:)` (see `+Attachment.swift`), not lazily here, so this read path
    /// never needs `legacyCanvas` at all. The fallback below is for the documented "attached but host
    /// gone" / "not yet attached" window only.
    ///
    /// **TASK 43 finished the move**: `inputTokenizer` is deleted from the canvas (it had been dead
    /// storage with zero readers since Task 24), and the CONSTRUCTION moved off the canvas too — the
    /// `legacyMakeTokenizer()` D24 hook is gone and `attach(to:)` writes `DocumentTokenizer(canvas:)`
    /// itself. So `tokenizer` is no longer a Family-3 D24-hook member at all; it is backend-owned end
    /// to end, with exactly one construction site (pinned by `InputBackendSourceBoundaryTests`
    /// `.test_theTokenizerHasExactlyOneConstructionSite` — two assertions, a construction scan plus a
    /// blunt identifier-mention allowance, because three of the five valid construction spellings put
    /// no `(` after the type name).
    var tokenizer: UITextInputTokenizer {
        guard let existing = tokenizerStorage else {
            RichTextInputContractViolation.report(
                "tokenizer read while no canvas is attached — returning a no-op fallback: \(#function)")
            return Self.detachedFallbackTokenizer
        }
        return existing
    }

    /// TASK 24 FIX ROUND 1 (Critical) — the non-crashing answer for a `tokenizer` read outside the
    /// attached window. A `static let` in an extension is legal (only INSTANCE stored properties are
    /// forbidden); one shared stateless instance is enough since the type carries no state.
    private static let detachedFallbackTokenizer: UITextInputTokenizer = NoOpTextInputTokenizer()

    // MARK: - Document bounds

    /// Was `DocumentCanvasView.beginningOfDocument`. The first position the caret can occupy must be
    /// RENDERABLE (a leaf region start/end or an image gap), not the document's structural open-token
    /// slot at 0 — otherwise "move to start of document" would hide the caret. `LegacyTextPosition(0)`
    /// on the detached fallback is the SAME value the pre-Task-24 `pendingRouting` stub returned.
    var beginningOfDocument: UITextPosition {
        guard let legacyCanvas = self.legacyCanvas else {
            RichTextInputContractViolation.report(
                "beginningOfDocument read while no canvas is attached: \(#function)")
            return LegacyTextPosition(0)
        }
        return LegacyTextPosition(legacyCanvas.legacySnapToRenderable(0, forward: true))
    }

    /// Was `DocumentCanvasView.endOfDocument`. Same rationale as `beginningOfDocument` above, snapping
    /// backward from the document's structural close-token slot.
    var endOfDocument: UITextPosition {
        guard let legacyCanvas = self.legacyCanvas, let document = self.document else {
            RichTextInputContractViolation.report(
                "endOfDocument read while no canvas is attached: \(#function)")
            return LegacyTextPosition(0)
        }
        return LegacyTextPosition(legacyCanvas.legacySnapToRenderable(document.utf16Length, forward: false))
    }

    // MARK: - Text projection

    /// Was `DocumentCanvasView.text(in:)` — the "\n"-at-every-top-level-paragraph-boundary projection
    /// the system keyboard reads document context through (load-bearing for the Hangul/CJK IME, which
    /// composes via `insertText` + a ranged `selectedTextRange` set + `deleteBackward`, never
    /// `setMarkedText`, and relies on this separator to avoid recomposing a syllable across an
    /// invisible line break). Routed to `legacyCanvas.legacyPlainText(globalFrom:globalTo:)` directly,
    /// NOT `TelegramDocumentInputClient.plainText(in:)`: the client REJECTS (returns `nil`) an
    /// out-of-bounds `NSRange`, while `legacyPlainText` CLAMPS (via `clampGlobal`) exactly like the
    /// original witness relied on. Going through the client here would be a real, if rare, behavior
    /// change for a stale/out-of-range range object — this preserves the edge case exactly (filed
    /// against the D27 follow-on project rather than fixed here — see the file header).
    ///
    /// Per-keystroke read: no `RichTextInputContractViolation` report on the detached fallback (an
    /// unthrottled report on the IME's read loop would flood) — `nil` is already this member's own
    /// failed-cast answer.
    func text(in range: UITextRange) -> String? {
        guard let r = range as? LegacyTextRange, let legacyCanvas = self.legacyCanvas else { return nil }
        return legacyCanvas.legacyPlainText(globalFrom: r.from.offset, globalTo: r.to.offset)
    }

    // MARK: - Range/position conversion — pure arithmetic on the identity objects, no canvas state,
    // so no `host`/`legacyCanvas`/`document` reachability question arises for any of the four below.

    /// Was `DocumentCanvasView.textRange(from:to:)`. ORDERS its two arguments into the range's
    /// `from`/`to` — load-bearing (`RichTextCanonicalSelection.normalizedRange`'s own doc comment notes
    /// the canvas hands UIKit an UNORDERED range for a reversed drag elsewhere; this member is where an
    /// unordered pair of positions gets sorted into a range). Do not "fix" to preserve caller order.
    func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange? {
        guard let f = fromPosition as? LegacyTextPosition, let t = toPosition as? LegacyTextPosition else { return nil }
        return f.offset <= t.offset ? LegacyTextRange(f, t) : LegacyTextRange(t, f)
    }

    /// Was `DocumentCanvasView.compare(_:to:)`.
    func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
        let a = (position as? LegacyTextPosition)?.offset ?? 0
        let b = (other as? LegacyTextPosition)?.offset ?? 0
        return a < b ? .orderedAscending : (a > b ? .orderedDescending : .orderedSame)
    }

    /// Was `DocumentCanvasView.offset(from:to:)`.
    func offset(from: UITextPosition, to other: UITextPosition) -> Int {
        ((other as? LegacyTextPosition)?.offset ?? 0) - ((from as? LegacyTextPosition)?.offset ?? 0)
    }

    /// Was `DocumentCanvasView.position(within:farthestIn:)`.
    func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition? {
        guard let r = range as? LegacyTextRange else { return nil }
        return (direction == .left || direction == .up) ? r.start : r.end
    }

    /// Was `DocumentCanvasView.characterRange(byExtending:in:)`. The trailing-edge branch needs the
    /// document's own length — read through the document client's `utf16Length` (a pure value read, no
    /// bounds-rejection semantics to diverge on, unlike `text(in:)` above: `utf16Length` always answers
    /// `canvas.documentSizeValue` verbatim, exactly what the original witness read as `documentSize`).
    /// Per-keystroke-adjacent read: no report on the detached fallback, same rationale as `text(in:)`.
    func characterRange(byExtending position: UITextPosition, in direction: UITextLayoutDirection) -> UITextRange? {
        guard let p = position as? LegacyTextPosition, let document = self.document else { return nil }
        return (direction == .left || direction == .up)
            ? LegacyTextRange(LegacyTextPosition(0), p)
            : LegacyTextRange(p, LegacyTextPosition(document.utf16Length))
    }

    // MARK: - Stepping — needs the canvas's renderable-snapping / navigation machinery.

    /// Was `DocumentCanvasView.position(from:offset:)`. Still snaps to a renderable slot exactly as
    /// before — the system tokenizer (Option+Arrow word nav, double-tap select, …) must never park the
    /// caret on a non-renderable structural token. Per-keystroke read: no report on the detached
    /// fallback, same rationale as `text(in:)`.
    func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
        guard let p = position as? LegacyTextPosition,
              let document = self.document, let legacyCanvas = self.legacyCanvas else { return nil }
        let n = p.offset + offset
        guard n >= 0, n <= document.utf16Length else { return nil }
        return LegacyTextPosition(legacyCanvas.legacySnapToRenderable(n, forward: offset >= 0))
    }

    /// Was `DocumentCanvasView+Navigation.position(from:in:offset:)` — the ONLY read member in this
    /// family carrying a `UITextLayoutDirection`, and OS-facing vertical-nav geometry: hardware arrows
    /// are driven by the OS through this method + the `selectedTextRange` setter, not `keyCommands`.
    /// The full stepping algorithm (grapheme-aware horizontal steps via `nextTextPosition`/
    /// `prevTextPosition`, geometric vertical steps via `verticalPosition`, the captionless-atom-gap
    /// step-through those two already implement, and the defense-in-depth renderable snap on a vertical
    /// move) is untouched — moved verbatim to `legacyPositionOffset(from:in:offset:)` in
    /// `+Navigation.swift`. Without the gap step-through, a multi-line move that stalls on a captionless
    /// atom's gap (offset:2 == offset:1) reads to the OS as "no progress"; it abandons
    /// `position(from:in:)` and falls back to its own line geometry that SKIPS the atom (the
    /// intermittent "arrow jumps over the quote/media" bug) — this router changes none of that.
    /// Per-keystroke-adjacent read: no report on the detached fallback, same rationale as `text(in:)`.
    func position(from position: UITextPosition, in direction: UITextLayoutDirection, offset: Int) -> UITextPosition? {
        guard let p = position as? LegacyTextPosition, let legacyCanvas = self.legacyCanvas else { return nil }
        return LegacyTextPosition(legacyCanvas.legacyPositionOffset(from: p.offset, in: direction, offset: offset))
    }
}

/// TASK 24 FIX ROUND 1 (Critical) — the stateless fallback `tokenizer` vends when read outside the
/// attached window (see `tokenizer`'s own doc comment above). Mirrors
/// `SpyRichTextInputBackend.SpyNoOpTokenizer` (test-only, so not reusable from here) — every member
/// answers with the "nothing to report" value UIKit already tolerates from any tokenizer.
private final class NoOpTextInputTokenizer: NSObject, UITextInputTokenizer {
    func rangeEnclosingPosition(_ position: UITextPosition, with granularity: UITextGranularity, inDirection direction: UITextDirection) -> UITextRange? { nil }
    func isPosition(_ position: UITextPosition, atBoundary granularity: UITextGranularity, inDirection direction: UITextDirection) -> Bool { false }
    func position(from position: UITextPosition, toBoundary granularity: UITextGranularity, inDirection direction: UITextDirection) -> UITextPosition? { nil }
    func isPosition(_ position: UITextPosition, withinTextUnit granularity: UITextGranularity, inDirection direction: UITextDirection) -> Bool { false }
}
#endif
