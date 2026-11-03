#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// The geometry side of the seam: caret, point, range, line, writing direction, and navigation
/// queries, all delegating to the existing UIKit witnesses' nil-returning bodies.
///
/// Deviation D9: every member here returns `nil` for missing geometry (the CLIENT boundary), never a
/// fabricated `CGRect.zero` — `.zero` stays at the UIKit witness (`caretRect(for:)`/`firstRect(for:)` in
/// `DocumentCanvasView+UITextInput.swift`), which callers already branch on
/// (`+Interaction.swift:126`, `RichTextEditorView.swift:706`, `+EditMenu.swift:35`). This client calls
/// the SAME `legacyCaretRect`/`legacyFirstRect` nil-returning helpers those witnesses now wrap, so the
/// `.zero` fallback is never duplicated here.
///
/// Every member (except the non-optional `baseWritingDirection`, whose contract has no nil case) first
/// checks `revision == canvas.documentRevision` and returns `nil` on mismatch (D32) — no rebase is
/// attempted; a stale caller must re-fetch a fresh position.
///
/// `purpose:` is accepted on every OTHER member (`caretGeometry`, `closestPosition`, `firstRect`) and
/// DELIBERATELY UNUSED there: the legacy canvas has exactly one caret/point/rect for a given position
/// regardless of who's asking — the keyboard, the loupe, the edit menu, accessibility — so there is no
/// caller-intent branch to make without inventing new (behavior-changing) geometry.
///
/// `selectionSegments(for:revision:)` is the ONE member where the spec's purpose-conditional rule
/// (endpoint requests outrank visible-only drawing requests) applies — but it is honoured structurally,
/// through `RichTextInputSelectionGeometryRequest`'s own fields (`visibleRect` + `includeStart/
/// EndEndpoint`), not by switching on `request.purpose`'s enum value. A caller varies those fields
/// according to its purpose (a presentation redraw passes a `visibleRect`; a canonical Select-All or an
/// accessibility walk passes `nil`); this client just honours whichever shape it's handed. So
/// `request.purpose` itself is still read by nothing here — it is retained on the request only because
/// the protocol's spec-mandated shape carries it, not because this backend branches on it.
@MainActor
@available(iOS 13.0, *)
final class TelegramGeometryInputClient: RichTextInputGeometryClient {
    /// `unowned`, deliberately, not `weak` — see `TelegramDocumentInputClient`'s doc comment for the
    /// full rationale (the canvas strictly outlives its clients). Tests that discard the canvas via `_`
    /// must bind it and use `withExtendedLifetime` instead.
    private unowned let canvas: DocumentCanvasView

    init(canvas: DocumentCanvasView) { self.canvas = canvas }

    var layoutGeneration: UInt64 { canvas.layoutGeneration }

    func caretGeometry(
        at position: RichTextInputPosition,
        revision: UInt64,
        purpose: RichTextInputGeometryPurpose
    ) -> RichTextInputCaretGeometry? {
        guard revision == canvas.documentRevision else { return nil }
        let offset = canvas.clampGlobal(position.utf16Offset)
        guard let rect = canvas.legacyCaretRect(globalOffset: offset) else { return nil }
        let direction: RichTextInputWritingDirection =
            canvas.resolvedDirection(forGlobal: offset) == .rightToLeft ? .rightToLeft : .leftToRight
        // The ID lives on `RichTextInputCaretGeometry.lineID` only — NOT on `lineRange`'s return value
        // (see the interfaces note in the task brief: `lineRange`/`caretGeometry` split
        // `legacyLineRegion`'s tuple, each discarding the half it doesn't need). A position with no
        // enclosing leaf region (a structural boundary — already excluded above by the nil `rect` guard
        // in every real case, but kept total here) falls back to an empty sentinel ID.
        let lineID = canvas.legacyLineRegion(containingGlobal: offset)?.lineID
            ?? RichTextInputLineID(blockID: BlockID(""), regionIndex: 0)
        return RichTextInputCaretGeometry(
            position: .downstream(offset),
            rect: rect,
            writingDirection: direction,
            lineID: lineID,
            documentRevision: canvas.documentRevision,
            layoutGeneration: canvas.layoutGeneration)
    }

    func closestPosition(
        to point: CGPoint,
        within range: NSRange?,
        revision: UInt64,
        purpose: RichTextInputGeometryPurpose
    ) -> RichTextInputPosition? {
        guard revision == canvas.documentRevision else { return nil }
        var offset = canvas.closestGlobalPosition(to: point)
        if let range {
            offset = min(max(offset, range.location), range.location + range.length)
        }
        return .downstream(offset)
    }

    func characterRange(at point: CGPoint, revision: UInt64) -> NSRange? {
        guard revision == canvas.documentRevision else { return nil }
        // Mirrors the witness `characterRange(at:)`: the naive [p, p+1) range, NOT grapheme-aware
        // (`+UITextInput.swift`'s own comment on the same non-goal).
        let p = canvas.closestGlobalPosition(to: point)
        let end = min(p + 1, canvas.documentSizeValue)
        return NSRange(location: p, length: end - p)
    }

    func lineRange(enclosing position: RichTextInputPosition,
                   revision: UInt64) -> (range: NSRange, resolvedAffinity: RichTextInputAffinity)? {
        guard revision == canvas.documentRevision,
              let region = canvas.legacyLineRegion(
                  containingGlobal: canvas.clampGlobal(position.utf16Offset)) else { return nil }
        // Deviation D6: the legacy backend has no affinity model and never emits .upstream.
        return (range: region.range, resolvedAffinity: .downstream)
    }

    /// Deviation D8: `anchorPositionOffset` is accepted and IGNORED, and nil is returned.
    /// Sticky-x is not preserved today — +Navigation.swift:164-168 re-derives x from the current
    /// caret at each step — and preserving it here would be a behavior change.
    func navigate(
        from position: RichTextInputPosition,
        direction: RichTextInputLayoutDirection,
        offset: Int,
        anchorPositionOffset: CGFloat?,
        revision: UInt64
    ) -> RichTextInputNavigationResult? {
        guard revision == canvas.documentRevision else { return nil }
        var current = canvas.clampGlobal(position.utf16Offset)
        for _ in 0..<max(offset, 0) {
            switch direction {
            case .right: current = canvas.nextTextPosition(after: current)
            case .left: current = canvas.prevTextPosition(before: current)
            case .down: current = canvas.verticalPosition(from: current, down: true)
            case .up: current = canvas.verticalPosition(from: current, down: false)
            }
        }
        return RichTextInputNavigationResult(position: .downstream(current),
                                             anchorPositionOffset: nil,
                                             documentRevision: canvas.documentRevision,
                                             layoutGeneration: canvas.layoutGeneration)
    }

    func firstRect(
        for range: NSRange,
        revision: UInt64,
        purpose: RichTextInputGeometryPurpose
    ) -> CGRect? {
        guard revision == canvas.documentRevision else { return nil }
        return canvas.legacyFirstRect(globalFrom: range.location, globalTo: range.location + range.length)
    }

    /// The bounded large-selection query (spec: "ask for the current visible bounds plus complete
    /// endpoints"). `purpose` is not read here — the purpose-conditional behavior (endpoint requests
    /// outrank visible-only drawing requests) is expressed structurally by `request.visibleRect` +
    /// `includeStart/EndEndpoint` themselves (`legacySelectionSegments`'s `alwaysInclude`), not by a
    /// branch on `purpose`. D26: this is built and proven but NOT wired into `refreshSelectionUI()` or
    /// `selectionRects(for:)` in stage 1 — see those call sites' own comments.
    func selectionSegments(for request: RichTextInputSelectionGeometryRequest,
                           revision: UInt64) -> [RichTextInputSelectionSegment]? {
        guard revision == canvas.documentRevision else { return nil }
        let from = canvas.clampGlobal(request.range.location)
        let to = canvas.clampGlobal(request.range.location + request.range.length)
        return canvas.legacySelectionSegments(
            globalFrom: from, globalTo: to, visibleRect: request.visibleRect,
            includeStartEndpoint: request.includeStartEndpoint,
            includeEndEndpoint: request.includeEndEndpoint
        ).map {
            // .leftToRight / false match LegacySelectionRect's hardcoded values
            // (S/InputBackend/Legacy/LegacyTextPosition.swift) — the witness has never reported anything else,
            // and reporting a real direction here would be new behavior.
            RichTextInputSelectionSegment(
                range: $0.range, rect: $0.rect,
                containsStart: $0.containsStart, containsEnd: $0.containsEnd,
                writingDirection: .leftToRight, isVertical: false,
                documentRevision: canvas.documentRevision,
                layoutGeneration: canvas.layoutGeneration)
        }
    }

    func baseWritingDirection(
        at position: RichTextInputPosition,
        revision: UInt64
    ) -> RichTextInputWritingDirection {
        guard revision == canvas.documentRevision else { return .leftToRight }
        let offset = canvas.clampGlobal(position.utf16Offset)
        return canvas.resolvedDirection(forGlobal: offset) == .rightToLeft ? .rightToLeft : .leftToRight
    }
}
#endif
