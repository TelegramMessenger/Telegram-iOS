#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
import RichTextInputDecUpstream

/// The visible half of a spoiler: a particle cloud over each hidden run.
///
/// DUST IS NOT DECORATION, and the difference is forced by the composer being TRANSPARENT over the
/// chat wallpaper. An opaque cover would paint a solid rectangle across a translucent field, so the
/// content underneath has to be hidden and the dust drawn over it — two mechanisms, not one.
///
/// Hiding the content is therefore its own problem, and it is NOT solved by the foreground colour
/// alone: that only affects glyphs. An attachment — a custom emoji — is a hosted view and stays fully
/// visible behind the dust. See `hideAttachmentViews(in:)`.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    /// Reconciles the dust views against the currently hidden spoiler runs. Idempotent; called after
    /// layout and after selection changes.
    internal func syncSpoilerDust() {
        let runs = hiddenSpoilerRuns()
        guard !runs.isEmpty || !spoilerDustViews.isEmpty else { return }

        var live: Set<NSRange> = []
        for run in runs {
            live.insert(run)
            let lineRects = engine.id_rects(forCanonicalRange: run).map(\.cgRectValue)
            guard !lineRects.isEmpty else { continue }
            let bounding = lineRects.reduce(CGRect.null) { $0.union($1) }
            guard !bounding.isNull, bounding.width > 0, bounding.height > 0 else { continue }

            let dust: SpoilerDustView
            if let existing = spoilerDustViews[run] {
                dust = existing
            } else {
                dust = SpoilerDustView(frame: bounding)
                dust.isUserInteractionEnabled = false
                // Into the ENGINE's content space, for the same reason the hosted emoji is: its
                // rects come from `id_rects`, which is content-space, so an editor-parented view
                // would stop covering the words it hides as soon as the field scrolled.
                engine.addSubview(dust)
                spoilerDustViews[run] = dust
            }
            // Dust over a cell rides the run's scrolling content, like the chrome and the emoji.
            let host = roleIndex(atFlatOffset: run.location)
                .flatMap { engine.id_placedRunContentViewForBlock(at: UInt($0)) } ?? engine
            if dust.superview !== host { dust.removeFromSuperview(); host.addSubview(dust) }
            dust.frame = host === engine ? bounding : engine.convert(bounding, to: host)
            // Word rects confine the particles to where ink actually is, so the cloud follows the
            // text rather than filling a rectangle. Local to the dust view, as its API expects.
            let words = spoilerWordRects(in: run).map { $0.offsetBy(dx: -bounding.minX, dy: -bounding.minY) }
            let lines = lineRects.map { $0.offsetBy(dx: -bounding.minX, dy: -bounding.minY) }
            dust.update(size: bounding.size,
                        color: composerHostState.theme.primaryText,
                        lineRects: lines,
                        wordRects: words.isEmpty ? lines : words)
        }

        for (range, dust) in spoilerDustViews where !live.contains(range) {
            spoilerDustViews[range] = nil
            dust.dissolve(explodingAt: nil) { [weak dust] in dust?.removeFromSuperview() }
        }
    }

    /// Canonical ranges of spoiler runs that are currently HIDDEN — the same reveal rule the text
    /// hide uses, so dust and hidden text can never disagree about which run is open.
    private func hiddenSpoilerRuns() -> [NSRange] {
        var result: [NSRange] = []
        var blockStart = 0
        for block in engine.attributedBlocks {
            let whole = NSRange(location: 0, length: block.length)
            block.enumerateAttribute(Self.spoilerAttributeKey, in: whole, options: []) { value, range, _ in
                guard (value as? Bool) == true else { return }
                let canonical = NSRange(location: blockStart + range.location, length: range.length)
                if !selectionRevealsCanonicalRange(canonical) { result.append(canonical) }
            }
            blockStart += block.length + 1
        }
        return result
    }

    /// Per-word geometry inside a run, so the emitter fills ink rather than the whole box.
    ///
    /// ATTACHMENTS COUNT AS INK. `enumerateSubstrings(.byWords)` does not treat `U+FFFC` as a word, so
    /// an emoji inside a spoiler produced no word rect and therefore no particles — it was hidden with
    /// a bare gap where the dust should be, which is exactly as revealing as not hiding it. Their own
    /// attachment frames are added explicitly.
    internal func spoilerWordRects(in run: NSRange) -> [CGRect] {
        var rects = wordRects(in: run)
        var blockStart = 0
        for block in engine.attributedBlocks {
            let whole = NSRange(location: 0, length: block.length)
            block.enumerateAttribute(.attachment, in: whole, options: []) { value, range, _ in
                guard value != nil else { return }
                let canonical = NSRange(location: blockStart + range.location, length: range.length)
                guard NSIntersectionRange(canonical, run).length > 0 else { return }
                let frame = engine.id_attachmentFrame(forCanonicalOffset: UInt(canonical.location))
                if !frame.isNull, frame.width > 0, frame.height > 0 { rects.append(frame) }
            }
            blockStart += block.length + 1
        }
        return rects
    }

    private func wordRects(in run: NSRange) -> [CGRect] {
        guard let text = engine.attributedBlocks.first.map({ _ in engine.text }) else { return [] }
        let ns = text as NSString
        guard run.location + run.length <= ns.length else { return [] }
        var rects: [CGRect] = []
        ns.enumerateSubstrings(in: run, options: [.byWords, .localized]) { _, wordRange, _, _ in
            rects.append(contentsOf: self.engine.id_rects(forCanonicalRange: wordRange).map(\.cgRectValue))
        }
        return rects
    }
}
#endif
