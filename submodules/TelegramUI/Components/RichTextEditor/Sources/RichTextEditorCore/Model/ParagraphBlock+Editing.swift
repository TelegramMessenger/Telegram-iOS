import Foundation

extension ParagraphBlock {
    /// Splits this paragraph at a UTF-16 offset into `[0, offset)` and `[offset, end)`.
    /// The upper half keeps this block's `id`; the lower half gets `newID`. Both inherit
    /// `style`, `paragraph`, and `list`. A run straddling the offset is bisected with its
    /// `CharacterAttributes` preserved on both halves.
    public func split(at utf16Offset: Int, newID: BlockID) -> (ParagraphBlock, ParagraphBlock) {
        let cut = max(0, min(utf16Offset, utf16Count))
        var upperRuns: [TextRun] = []
        var lowerRuns: [TextRun] = []
        var consumed = 0
        for run in runs {
            let runLen = run.utf16Count
            if consumed + runLen <= cut {
                upperRuns.append(run)
            } else if consumed >= cut {
                lowerRuns.append(run)
            } else {
                let local = cut - consumed
                let ns = run.text as NSString
                let left = ns.substring(to: local)
                let right = ns.substring(from: local)
                if !left.isEmpty { upperRuns.append(TextRun(text: left, attributes: run.attributes)) }
                if !right.isEmpty { lowerRuns.append(TextRun(text: right, attributes: run.attributes)) }
            }
            consumed += runLen
        }
        let upper = ParagraphBlock(id: id, style: style, paragraph: paragraph, list: list, runs: upperRuns)
        let lower = ParagraphBlock(id: newID, style: style, paragraph: paragraph, list: list, runs: lowerRuns)
        return (upper, lower)
    }

    /// Returns this paragraph with `other`'s runs appended. Keeps this block's identity:
    /// `id`, `style`, `paragraph`, and `list` (the surviving/upper block wins).
    ///
    /// When the two paragraphs have DIFFERENT styles, `other`'s runs move into THIS block's style, so their
    /// display-only per-run font size (pinned on read-back — see the font-size tech-debt note in
    /// RichTextEditorUIKit/CLAUDE.md) is dropped, letting the merged text inherit this style's size — e.g.
    /// body text merged into a heading renders heading-sized, and the mirror on the other side. Same-style
    /// merges keep the pinned size (preserving the 15pt table-cell round-trip, which is a same-style merge).
    public func merging(_ other: ParagraphBlock) -> ParagraphBlock {
        let otherRuns = style == other.style
            ? other.runs
            : other.runs.map { var r = $0; r.attributes.fontSize = nil; return r }
        return ParagraphBlock(id: id, style: style, paragraph: paragraph, list: list, runs: runs + otherRuns)
    }
}
