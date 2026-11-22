#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit

/// Task C7 (Family 4) — recovers the semantic intent UIKit's raw
/// `TGRichTextInputDecTextStorageFacade.replaceCharactersInRange:withString:` destroys. The latch
/// (`TGRichTextInputDecIntent`) is set by the pre-mutation private input-delegate callbacks
/// (`TGRichTextInputDecCanvasCallbacks.m`) BEFORE UIKit drives the storage mutation, and cleared by
/// the façade to `.programmatic` after every transaction — see that class's own doc comment.
///
/// SHAPES. These are the stage-1 `RichTextInputMutation` cases verbatim, re-confirmed against
/// `RichTextInputTypes.swift` for this task (seam Task 27's `legacyApplyMutation` switch, cited by
/// the task brief, is the same source read a different way):
///   insertText(text: NSAttributedString, replacing: RichTextCanonicalSelection,
///              origin: RichTextInputMutationOrigin)
///   insertParagraphBreak(replacing: RichTextCanonicalSelection, origin: …)
///   replaceText(range: NSRange, text: NSAttributedString, origin: …)
///   setMarkedText(text: NSAttributedString, replacing: NSRange,
///                 selectedRangeInMarkedText: NSRange)
///   deleteBackward(selection: RichTextCanonicalSelection, proposedRange: NSRange?)
///   unmarkText
/// There is NO `.paste` case: paste is an ORIGIN, not a mutation. Every text-bearing case takes an
/// `NSAttributedString`, never a `String`.
@available(iOS 17.0, *)
enum IDTextEditorBackendIntent {
    /// `typingAttributes` — Task R2 addition. Evaluated LAZILY and ONLY for the plain `.insertText`
    /// (non-newline) branch, mirroring `ReferenceMutationBackend.insertText(_:)`'s own
    /// `document.typingAttributes(at: …)` read (the stage-1 contract's own reference shape for what
    /// "insert text" means: `.insertText(text:...)`'s carried `NSAttributedString` is resolved
    /// against the caret's inherited formatting, fresh on every call — deviation D25, "the legacy
    /// backend caches nothing"). Every other branch never invokes the closure, so a caller that has
    /// no host/document client handy for those cases pays nothing and reads nothing extra
    /// (`IDBackendMutationContractTests.test_typingAttributesAreResolvedPerCall_…` pins the read
    /// COUNT, not just the resulting attribute). Defaults to `{ [:] }` so
    /// `IDTextEditorBackendIntentTests`'s existing calls (no host, pure value-type coverage) keep
    /// compiling and keep returning plain, unattributed text exactly as before.
    ///
    /// `markedTextSelectedRange` — Task D4d addition, and the ONLY argument here that cannot be
    /// recovered from `(intent, range, text, selection)`. `UITextInput`'s
    /// `setMarkedText(_:selectedRange:)` carries a caret expressed RELATIVE TO THE MARKED TEXT, and
    /// the raw `replaceCharactersInRange:withString:` crossing point this method reconstructs from
    /// destroys it exactly the way it destroys the intent — so it travels the same way the intent
    /// does, latched beside it (`IDTextEditorBackend.latchMarkedTextIntent(selectedRange:)`,
    /// consumed by `IDTextEditorBackendClientBridge.prepareAndCommitReplacement`). `nil` means "no
    /// latch reached this transaction", and the end-of-marked-text fallback below is then the least
    /// wrong answer — it is what a CJK/IME composition asks for anyway.
    static func mutation(for intent: TGRichTextInputDecIntent,
                         range: NSRange,
                         text: String,
                         selection: RichTextCanonicalSelection,
                         typingAttributes: () -> [NSAttributedString.Key: Any] = { [:] },
                         markedTextSelectedRange: NSRange? = nil) -> RichTextInputMutation {
        switch intent {
        case .insertText where text == "\n":
            return .insertParagraphBreak(replacing: selection, origin: .softwareKeyboard)
        case .insertText:
            return .insertText(text: NSAttributedString(string: text, attributes: typingAttributes()),
                               replacing: selection, origin: .softwareKeyboard)
        case .markedText:
            // TASK D4d — the marked-text-relative caret is the CALLER's, never fabricated when one
            // was supplied. `DocumentCanvasView.legacySetMarkedText(_:selectedRange:)` reads this
            // value TWICE: it places the caret at `lo + selectedRange.location`, and it derives
            // `isPrediction: selectedRange.location == 0 && selectedRange.length == 0` — the flag
            // `refreshPredictionStyling()` paints the grey inline-prediction ghost from. The
            // unconditional `{text.utf16.count, 0}` this used to build therefore did TWO wrong
            // things at once: it put the caret at the END of a system inline prediction (measured
            // as a uniform `+2` across all nine `inline-prediction-ios26.5-v1` scenarios — 33 in
            // stock, 35 here, on the 2-character offer "to"), and it made every prediction present
            // as a CJK composition. Retained ONLY as the no-latch fallback: `{count, 0}` is
            // precisely what a CJK composition supplies, so an unlatched `.markedText` transaction
            // still behaves as it always did.
            return .setMarkedText(text: NSAttributedString(string: text),
                                  replacing: selection.normalizedRange,
                                  selectedRangeInMarkedText: markedTextSelectedRange
                                      ?? NSRange(location: text.utf16.count, length: 0))
        case .deleteBackward:
            return .deleteBackward(selection: selection, proposedRange: range)
        case .paste:
            // The intent survives as the ORIGIN. The client's `allowsPaste` edit-policy check
            // reads exactly this.
            return .insertText(text: NSAttributedString(string: text), replacing: selection, origin: .paste)
        case .dictation:
            return .insertText(text: NSAttributedString(string: text), replacing: selection, origin: .dictation)
        case .programmatic:
            return .replaceText(range: range, text: NSAttributedString(string: text), origin: .programmatic)
        @unknown default:
            return .replaceText(range: range, text: NSAttributedString(string: text), origin: .programmatic)
        }
    }
}
#endif
