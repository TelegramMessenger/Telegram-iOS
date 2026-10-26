#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextInputDecHost

/// Keyboard traits follow the caret into and out of code.
///
/// Legacy's rule, ported (`DocumentCanvasView+MarkedText.swift`, `refreshCodeInputTraitsIfNeeded`):
/// a code block's text and its language line are identifiers, not prose, so autocapitalization,
/// autocorrection, spell checking, inline predictions and smart punctuation are off there. Otherwise the keyboard
/// capitalizes `let` to `Let` and corrects identifiers into English words. The engine synthesizes
/// fixed prose traits at construction and knows nothing about regions, so the host switches them.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {
    /// True when the caret — the selection's start — sits in a code block's text or its language line.
    internal var caretIsInCodeRegion: Bool {
        guard let index = roleIndex(atFlatOffset: engineSelectedRange.location) else { return false }
        let role = currentRoles[index]
        if role.secondaryKind == .codeLanguage { return true }
        if case .standalone(.code) = role.position { return true }
        return false
    }

    /// Re-derives the traits from the caret's region. UIKit caches traits and re-reads them only on
    /// `reloadInputViews()`; the engine's setters are no-ops for an unchanged value, and the batch
    /// reloads at most once, so ordinary caret movement costs no reload.
    internal func refreshCodeInputTraits() {
        let inCode = caretIsInCodeRegion
        engine.id_updateTextInputTraits {
            engine.autocapitalizationType = inCode ? .none : .sentences
            engine.autocorrectionType = inCode ? .no : .default
            engine.spellCheckingType = inCode ? .no : .default
            engine.inlinePredictionType = inCode ? .no : .default
            // Smart punctuation rewrites the characters themselves — `"` to a curly quote, `--` to
            // a dash, a paste padded with spaces — which breaks code as surely as autocorrection.
            engine.smartQuotesType = inCode ? .no : .default
            engine.smartDashesType = inCode ? .no : .default
            engine.smartInsertDeleteType = inCode ? .no : .default
        }
    }
}
#endif
