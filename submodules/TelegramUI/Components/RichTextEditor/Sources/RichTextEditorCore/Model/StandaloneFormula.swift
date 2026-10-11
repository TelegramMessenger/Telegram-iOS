import Foundation

public extension ParagraphBlock {
    /// The LaTeX source of a paragraph that is a STANDALONE formula — a lone body paragraph whose
    /// single run carries a non-empty formula and no spoiler — or nil.
    ///
    /// A SPOILERED formula is not standalone: a `.formula` block carries no inline attribute, so it
    /// would be sent visible. It is sent as a paragraph holding the hidden formula, and spaced as one
    /// (composer harness p20; TelegramCore's `standaloneFormulaLatex` for `ChatInputContent` agrees).
    ///
    /// Lives in Core because two places need the same answer and must not drift: `InstantPageBuilder`
    /// emits `.formula` for such a paragraph, and the editor's block-spacing classification has to
    /// agree, since `.formula` and `.paragraph` take different vertical-rhythm rules.
    var standaloneFormulaLatex: String? {
        guard style == .body, list == nil, runs.count == 1 else { return nil }
        guard let latex = runs[0].attributes.formula, !latex.isEmpty else { return nil }
        guard !runs[0].attributes.spoiler else { return nil }
        return latex
    }
}
