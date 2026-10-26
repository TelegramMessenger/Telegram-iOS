#if canImport(UIKit)
import UIKit
import RichTextEditorCore

@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// Every code box in the document, recursing containers — a code block can sit inside a quote, a
    /// detail block, or a table cell. Mirrors `stackContainingCodeBox(id:)`'s traversal.
    func forEachCodeBox(_ body: (CodeBlockBox) -> Void) {
        func walk(_ stack: BlockStack) {
            for b in stack.boxes {
                if let c = b as? CodeBlockBox { body(c) }
                if let bq = b as? BlockQuoteBox { walk(bq.children) }
                if let d = b as? DetailsBox { walk(d.children) }
                if let t = b as? TableBlockBox {
                    for cell in t.cells.flatMap({ $0 }) { walk(cell) }
                }
            }
        }
        walk(root)
    }

    /// Schedule a debounced highlight pass. Called from every content edit and from `setBlocks`, never
    /// from a selection change: the caret moving through code changes no spec, and scheduling there would
    /// re-run the walk on every arrow key.
    func scheduleSyntaxHighlightPass() {
        guard syntaxHighlighter != nil else { return }
        pendingSyntaxHighlightWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.pendingSyntaxHighlightWork = nil
            self?.runSyntaxHighlightPass()
        }
        pendingSyntaxHighlightWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + syntaxHighlightDebounceInterval, execute: work)
    }

    /// Collect the document's specs, request the ones not already answered, and drop answers for specs the
    /// document no longer contains (so a long editing session does not accumulate every intermediate
    /// string the user typed).
    func runSyntaxHighlightPass() {
        guard let provider = syntaxHighlighter else { return }

        var live: Set<CodeHighlightSpec> = []
        forEachCodeBox { box in
            guard let language = richTextNormalizedCodeLanguage(box.languageLayout.attributedString.string) else { return }
            let text = box.layout.attributedString.string
            guard !text.isEmpty else { return }
            live.insert(CodeHighlightSpec(language: language, text: text))
        }

        syntaxHighlightCache = syntaxHighlightCache.filter { live.contains($0.key) }
        inFlightSyntaxHighlightSpecs = inFlightSyntaxHighlightSpecs.intersection(live)

        applySyntaxHighlightsToBoxes()

        for spec in live where syntaxHighlightCache[spec] == nil && !inFlightSyntaxHighlightSpecs.contains(spec) {
            inFlightSyntaxHighlightSpecs.insert(spec)
            provider(spec.language, spec.text) { [weak self] tokens in
                guard let self else { return }
                self.inFlightSyntaxHighlightSpecs.remove(spec)
                self.syntaxHighlightCache[spec] = tokens
                self.applySyntaxHighlightsToBoxes()
            }
        }
    }

    /// Hands each code box the tokens for its current (language, text), or none.
    ///
    /// **Repaints the BLOCK'S OWN backing view**, not the canvas. A code block renders into a pooled
    /// `BlockBackingView` (the node-view split), so `setNeedsDisplay()` on the canvas leaves the block's
    /// bitmap stale until some unrelated layout pass happens to run `syncBlockViews()` → `bindRealizedView`
    /// → `view.setNeedsDisplay()`. Moving the caret is such a pass, which is exactly why highlighting
    /// appeared only after the caret left the code block.
    func applySyntaxHighlightsToBoxes() {
        forEachCodeBox { box in
            let language = richTextNormalizedCodeLanguage(box.languageLayout.attributedString.string)
            let text = box.layout.attributedString.string
            let tokens = language.flatMap { syntaxHighlightCache[CodeHighlightSpec(language: $0, text: text)] } ?? []
            guard box.applySyntaxHighlight(tokens) else { return }
            // Colours only — never metrics (same text, same font) — so this repaints and deliberately does
            // NOT call `notifyContentSizeChanged()`, which would ask the host to re-run its whole layout
            // on every highlight arrival for a height that cannot have moved.
            blockViews[box.id]?.setNeedsDisplay()
            codeHighlightRepaintCount += 1
        }
    }

    /// Re-apply cached highlights to boxes that were just rebuilt from the model, synchronously.
    ///
    /// A rebuild — a theme change, a quote/code style change, an undo restore — reconstructs every box from
    /// `Document`, which carries no colours by design. Leaving them for the debounced pass shows a PLAIN
    /// frame first, which is what "the text loses highlight when the device changes theme" was: the answer
    /// was in the cache the whole time. Called from `setBlocks`, before the first layout of the new boxes.
    func reapplyCachedSyntaxHighlights() {
        guard !syntaxHighlightCache.isEmpty else { return }
        applySyntaxHighlightsToBoxes()
    }

    /// Test seam: true when nothing is cached.
    var syntaxHighlightCacheIsEmptyForTesting: Bool { syntaxHighlightCache.isEmpty }
    /// Test seam: how many block views have been repainted for a colour change.
    var codeHighlightRepaintCountForTesting: Int { codeHighlightRepaintCount }
}
#endif
