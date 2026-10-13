import Foundation

public extension ParagraphBlock {
    /// The LaTeX source of a paragraph that is a STANDALONE formula — a lone body paragraph whose
    /// single run carries a non-empty formula — or nil.
    ///
    /// Lives in Core because two places need the same answer and must not drift: `InstantPageBuilder`
    /// emits `.formula` for such a paragraph, and the editor's block-spacing classification has to
    /// agree, since `.formula` and `.paragraph` take different vertical-rhythm rules.
    var standaloneFormulaLatex: String? {
        guard style == .body, list == nil, runs.count == 1 else { return nil }
        guard let latex = runs[0].attributes.formula, !latex.isEmpty else { return nil }
        return latex
    }
}
