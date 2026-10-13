#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// Indent / outdent for LIST ITEMS only (GFM-faithful: list nesting maps to markdown; body-paragraph
/// indentation has no markdown form, so non-list paragraphs are a no-op). Mirrors `setList`: mutate
/// `ListMembership.level` on every list box the selection touches, restyle, recompute. Works on a
/// collapsed caret (it's a paragraph-level command). Outdent clamps at level 0 (it does NOT drop the
/// list — that's the list toggle's job); indent clamps at `maxListLevel`.
@available(iOS 13.0, *)
extension DocumentCanvasView {
    private var maxListLevel: Int { 8 }

    func indent() { changeListLevel(by: 1) }
    func outdent() { changeListLevel(by: -1) }

    private func changeListLevel(by delta: Int) {
        guard !boxes.isEmpty else { return }
        editing {
            for box in boxes {
                guard let p = box as? BlockBox, let m = p.listMembership else { continue }
                let boxLo = p.textStart, boxHi = p.textStart + p.textLength
                guard selFrom <= boxHi && selTo >= boxLo else { continue }
                let newLevel = max(0, min(m.level + delta, maxListLevel))
                // preserve `checked` — a `.checklist` membership must always carry a non-nil checked state
                // (indent/outdent must not silently uncheck or drift to bullet on round-trip)
                p.listMembership = ListMembership(marker: m.marker, level: newLevel, checked: m.checked)
                restyle(p)
            }
            recomputeSpans()   // symmetry with setList; a level bump leaves token spans unchanged
            return .unchanged
        }
    }
}
#endif
