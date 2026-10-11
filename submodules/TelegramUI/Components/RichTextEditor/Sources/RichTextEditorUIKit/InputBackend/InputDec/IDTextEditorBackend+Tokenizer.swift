#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit

/// Task R12 (cluster 12) — adapts `DocumentTokenizer` (`LegacyDocumentTokenizer.swift`, canvas-level
/// word/paragraph-boundary logic already shared by both backends) to mint THIS backend's own
/// `TGRichTextInputDecPosition`/`TGRichTextInputDecRange` identity objects, rather than Legacy's
/// `LegacyTextPosition`/`LegacyTextRange`. See `IDTextEditorBackend.tokenizerStorage`'s own doc
/// comment for why this wrapping is necessary, not optional: `IDBackendFamily9Tests
/// .test_selectWordRoutesThroughTheInteractionCapability` found that the vendored kernel's OWN
/// `IDUIKitInteractionCapability.selectWord()` hands a tokenizer's output straight back into this
/// backend's OTHER witnesses (`compare(_:to:)`, `textRange(from:to:)`, both `IDTextEditorBackend.swift`)
/// — a `LegacyTextPosition` there is a foreign object those witnesses, and the real private
/// controller behind them, cannot make sense of (confirmed directly: an earlier draft handing back
/// `DocumentTokenizer`'s own `LegacyTextPosition` result produced a LIVE
/// `-[RichTextEditorUIKit.LegacyTextPosition documentRevision]: unrecognized selector` failure from
/// exactly this round-trip, not a hypothetical).
///
/// **Every word/paragraph boundary computation below is `DocumentTokenizer`'s own — this type
/// performs no text scanning itself, per "mirror Legacy, do not invent."** Only the seam converts:
/// (1) an incoming `TGRichTextInputDecPosition` is unwrapped to its raw UTF-16 offset and re-wrapped
/// as a `LegacyTextPosition` before reaching `DocumentTokenizer` (whose own methods never see this
/// backend's identity type — matching `LegacyDocumentTokenizer.swift`'s own `off(_:)` helper's
/// contract, which already tolerates a foreign `UITextPosition` by defaulting to offset 0); (2) the
/// `LegacyTextPosition`/`LegacyTextRange` `DocumentTokenizer` returns is unwrapped back to an offset
/// and re-minted as `TGRichTextInputDecPosition`/`TGRichTextInputDecRange`, stamped with
/// `currentRevision()` — the SAME "stamp the live document revision" convention
/// `IDTextEditorBackend.mintKernelSelectedTextRange()` already establishes, so the kernel's own
/// staleness/rebase check (`TGRichTextInputDecPosition.documentRevision`'s own header comment) sees
/// a fresh position for a tokenizer-derived result, never a stale one that would trigger a spurious
/// rebase attempt.
///
/// **Living in its own file, under a name that does NOT contain "DocumentTokenizer" as a whole
/// word, is load-bearing for `InputBackendSourceBoundaryTests
/// .test_theTokenizerHasExactlyTwoConstructionSites`** — see that test's own updated header for the
/// full reasoning: `DocumentTokenizer` now legitimately has two independent construction sites (one
/// per backend), and naming this adapter `IDDocumentTokenizer` rather than re-exporting
/// `DocumentTokenizer` under an alias keeps the two backends' sites textually distinguishable to
/// that scan without any special-casing.
@available(iOS 17.0, *)
final class IDDocumentTokenizer: NSObject, UITextInputTokenizer, DocumentBoundaryTokenizer {
    private let inner: DocumentTokenizer
    private let currentRevision: () -> UInt64

    /// `currentRevision` is a closure, not a stored `UInt64`, because the document's revision moves
    /// across this instance's lifetime (every mutation bumps it) and must be read FRESH at every
    /// call — the same reason `mintKernelSelectedTextRange()` reads `state.documentRevision` live
    /// rather than caching it at construction. `IDTextEditorBackend.attach(to:)`'s construction site
    /// passes `[weak self] in self?.state.documentRevision ?? 0` — a WEAK capture, not `unowned`,
    /// since this instance is stored ON that very `self` (`tokenizerStorage`) and a strong or
    /// `unowned` capture back would be a needless retain cycle / crash risk for a call that can
    /// never legitimately happen once the owning backend starts deallocating.
    init(canvas: IDDocumentCanvasView, currentRevision: @escaping () -> UInt64) {
        self.inner = DocumentTokenizer(canvas: canvas)
        self.currentRevision = currentRevision
        super.init()
    }

    /// A foreign (non-`TGRichTextInputDecPosition`) input collapses to offset 0 — the same
    /// "unrecognized position defaults to 0" convention `LegacyDocumentTokenizer.swift`'s own
    /// `off(_:)` helper already uses for a `LegacyTextPosition`-only reader handed something else.
    private func offset(_ position: UITextPosition) -> Int {
        (position as? TGRichTextInputDecPosition)?.utf16Offset ?? 0
    }

    private func mintPosition(_ offset: Int) -> TGRichTextInputDecPosition {
        TGRichTextInputDecPosition(offset: offset, affinity: .forward, revision: currentRevision())
    }

    func position(from position: UITextPosition, toBoundary granularity: UITextGranularity,
                  inDirection direction: UITextDirection) -> UITextPosition? {
        guard let result = inner.position(from: LegacyTextPosition(offset(position)),
                                           toBoundary: granularity, inDirection: direction) else {
            return nil
        }
        return mintPosition((result as? LegacyTextPosition)?.offset ?? 0)
    }

    func isPosition(_ position: UITextPosition, atBoundary granularity: UITextGranularity,
                    inDirection direction: UITextDirection) -> Bool {
        inner.isPosition(LegacyTextPosition(offset(position)), atBoundary: granularity, inDirection: direction)
    }

    func isPosition(_ position: UITextPosition, withinTextUnit granularity: UITextGranularity,
                    inDirection direction: UITextDirection) -> Bool {
        inner.isPosition(LegacyTextPosition(offset(position)), withinTextUnit: granularity, inDirection: direction)
    }

    func rangeEnclosingPosition(_ position: UITextPosition, with granularity: UITextGranularity,
                                inDirection direction: UITextDirection) -> UITextRange? {
        guard let result = inner.rangeEnclosingPosition(LegacyTextPosition(offset(position)),
                                                        with: granularity, inDirection: direction)
                as? LegacyTextRange else {
            return nil
        }
        return TGRichTextInputDecRange(from: mintPosition(result.from.offset),
                                       to: mintPosition(result.to.offset))
    }

    // MARK: - `DocumentBoundaryTokenizer`
    //
    // TASK F4 — the three canvas sites that need STRUCTURAL boundaries (double-tap word select,
    // triple-tap paragraph select, spell-check word targeting) reached them with
    // `tokenizer as? DocumentTokenizer`, a CONCRETE cast this adapter can never satisfy — so all
    // three silently no-oped under `.inputDec`. Both members answer in GLOBAL UTF-16 offsets, so
    // there is no identity to convert and no scanning to duplicate: `inner`'s own answer, verbatim,
    // exactly as this type's header requires ("every word/paragraph boundary computation below is
    // `DocumentTokenizer`'s own").

    func wordRange(at pos: Int) -> (from: Int, to: Int)? { inner.wordRange(at: pos) }
    func paragraphRange(at pos: Int) -> (from: Int, to: Int)? { inner.paragraphRange(at: pos) }
}
#endif
