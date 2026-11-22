#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// Identity of one contiguous spoiler run, anchored to its owning text REGION (the layout-engine instance,
/// which is 1:1 with a paragraph / caption / table cell) + the run's index within that region — NOT the
/// spoiler's absolute document offset. So editing content ABOVE the spoiler (which shifts its `globalStart`
/// but leaves its region's layout instance untouched) keeps the key stable and the pooled dust view keeps
/// animating instead of dissolving-and-recreating. The key only changes when the region's own box is rebuilt
/// (a structural edit to that paragraph, or a full reload), which legitimately restarts the dust.
@available(iOS 13.0, *)
struct SpoilerKey: Hashable { let region: ObjectIdentifier; let runIndex: Int }

/// One spoiler run found in the laid-out document (recomputed each `syncSpoilers`).
@available(iOS 13.0, *)
struct SpoilerRun {
    let key: SpoilerKey
    let regionStart: Int            // owning region's globalStart (for table-content hosting lookup)
    let globalRange: Range<Int>     // absolute [start, end)
    let canvasLineRects: [CGRect]   // UNSCROLLED canvas rects (hosting / cull / size)
    let canvasWordRects: [CGRect]   // UNSCROLLED canvas rects (emitter)
    var hidden: Bool
}

/// A pooled dust view + its unscrolled canvas frame (for culling).
@available(iOS 13.0, *)
final class HostedSpoilerDust {
    let view: SpoilerDustView
    var canvasFrame: CGRect
    var lastUpdatedFrame: CGRect = .null   // skip re-configuring the emitter when geometry+color are unchanged
    var lastColor: UIColor?
    init(view: SpoilerDustView, canvasFrame: CGRect) { self.view = view; self.canvasFrame = canvasFrame }
}

@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// Recompute spoiler runs, push hidden/revealed into each layout (display-only hide), and reconcile the
    /// dust pool. Selection-driven: a run is revealed iff the selection touches it (collapsed caret inside
    /// the closed run; a range overlapping it). Idempotent; called from `layoutSubviews` + `refreshSelectionUI`.
    func syncSpoilers() {
        // Spoiler-free fast path: nothing to compute AND no residual hide/dust to clear → O(1) on caret moves.
        guard documentHasSpoilers || !spoilerRuns.isEmpty || !spoilerDustViews.isEmpty else { return }
        let runs = computeSpoilerRuns()
        spoilerRuns = runs
        let hideChanged = applySpoilerHiding(runs)
        reconcileSpoilerDust(runs)
        spoilerRevealHint = nil
        // A reveal removes a clear-foreground rendering attribute (and a new hide adds one), bumping the
        // owning paragraph's renderVersion — but a selection-only reveal (caret-move/tap) doesn't otherwise
        // trigger a layout, so the backing view would keep its stale (text-hidden) bitmap and the dust would
        // dissolve to reveal nothing. Request a layout so `reconcileBlockViews` repaints the changed paragraph
        // (its renderSignature changed) and the text shows under the dissolving dust. Cheap: only on a real
        // hide-state change, never on an ordinary caret move.
        if hideChanged { setNeedsLayout() }
    }

    /// Recompute `documentHasSpoilers` by scanning storage for any `.rtSpoiler` run. Call ONLY from
    /// model-mutating paths (already O(N)) — never from the selection-change path.
    func recomputeDocumentHasSpoilers() {
        documentHasSpoilers = allLeafRegions().contains { region in
            let attr = region.layout.attributedString
            var found = false
            attr.enumerateAttribute(.rtSpoiler, in: NSRange(location: 0, length: attr.length), options: []) { v, _, stop in
                if (v as? Bool) == true { found = true; stop.pointee = true }
            }
            return found
        }
    }

    private func computeSpoilerRuns() -> [SpoilerRun] {
        var result: [SpoilerRun] = []
        for region in allLeafRegions() {
            let attr = region.layout.attributedString
            let full = NSRange(location: 0, length: attr.length)
            var runIndex = 0
            attr.enumerateAttribute(.rtSpoiler, in: full, options: []) { value, range, _ in
                guard (value as? Bool) == true, range.length > 0 else { return }
                let gStart = region.globalStart + range.location
                let gEnd = gStart + range.length
                let line = region.layout.selectionRects(start: range.location, end: range.location + range.length)
                    .map { $0.offsetBy(dx: region.canvasOrigin.x, dy: region.canvasOrigin.y).insetBy(dx: 1, dy: 1) }
                let words = spoilerWordRects(in: region, localRange: range)
                result.append(SpoilerRun(
                    key: SpoilerKey(region: ObjectIdentifier(region.layout), runIndex: runIndex),
                    regionStart: region.globalStart,
                    globalRange: gStart..<gEnd,
                    canvasLineRects: line,
                    canvasWordRects: words,
                    hidden: !isSpoilerRevealed(gStart: gStart, gEnd: gEnd)))
                runIndex += 1
            }
        }
        return result
    }

    /// Revealed iff the live selection touches the run: a collapsed caret anywhere in the CLOSED range
    /// `[gStart, gEnd]` (so a length-1 spoiler and a boundary tap both reveal), or a range that strictly
    /// overlaps. A range merely abutting an edge does NOT reveal.
    private func isSpoilerRevealed(gStart: Int, gEnd: Int) -> Bool {
        if selFrom == selTo { return selFrom >= gStart && selFrom <= gEnd }
        return selFrom < gEnd && selTo > gStart
    }

    /// Per-word rects within the run (Telegram's `spoilerWords`) so particles sit where ink is. Falls back to
    /// the line rects for a whitespace-only spoiler. Unscrolled canvas coords.
    private func spoilerWordRects(in region: LeafTextRegion, localRange: NSRange) -> [CGRect] {
        let s = region.layout.attributedString.string as NSString
        var rects: [CGRect] = []
        s.enumerateSubstrings(in: localRange, options: [.byWords, .substringNotRequired]) { _, r, _, _ in
            for rect in region.layout.selectionRects(start: r.location, end: r.location + r.length) {
                rects.append(rect.offsetBy(dx: region.canvasOrigin.x, dy: region.canvasOrigin.y).insetBy(dx: 1, dy: 1))
            }
        }
        if rects.isEmpty {
            rects = region.layout.selectionRects(start: localRange.location,
                                                 end: localRange.location + localRange.length)
                .map { $0.offsetBy(dx: region.canvasOrigin.x, dy: region.canvasOrigin.y) }
        }
        return rects
    }

    /// Pushes the per-region hidden LOCAL ranges into each layout's display-only clear-foreground. Every
    /// region is set each pass (empty list = revealed) so a just-revealed run clears. Returns `true` iff any
    /// region's hide actually changed (so `syncSpoilers` can repaint the affected paragraph).
    @discardableResult
    private func applySpoilerHiding(_ runs: [SpoilerRun]) -> Bool {
        var hiddenByRegion: [Int: [NSRange]] = [:]
        for r in runs where r.hidden {
            hiddenByRegion[r.regionStart, default: []].append(
                NSRange(location: r.globalRange.lowerBound - r.regionStart, length: r.globalRange.count))
        }
        var changed = false
        for region in allLeafRegions() {
            if region.layout.setSpoilerHidden(hiddenByRegion[region.globalStart] ?? []) { changed = true }
        }
        return changed
    }

    private func reconcileSpoilerDust(_ runs: [SpoilerRun]) {
        var present = Set<SpoilerKey>()
        for run in runs where run.hidden {
            guard let bounding = run.canvasLineRects.first.map({ first in
                run.canvasLineRects.dropFirst().reduce(first) { $0.union($1) }
            }) else { continue }
            present.insert(run.key)
            let dust = spoilerDustViews[run.key] ?? {
                let h = HostedSpoilerDust(view: SpoilerDustView(), canvasFrame: bounding)
                spoilerDustViews[run.key] = h
                return h
            }()
            dust.canvasFrame = bounding
            let color = spoilerDustColor(forGlobal: run.globalRange.lowerBound)
            if bounding != dust.lastUpdatedFrame || color != dust.lastColor {
                let localLine = run.canvasLineRects.map { $0.offsetBy(dx: -bounding.minX, dy: -bounding.minY) }
                let localWords = run.canvasWordRects.map { $0.offsetBy(dx: -bounding.minX, dy: -bounding.minY) }
                dust.view.update(size: bounding.size, color: color, lineRects: localLine, wordRects: localWords)
                dust.lastUpdatedFrame = bounding
                dust.lastColor = color
            }
            placeSpoilerDust(dust, canvasFrame: bounding, regionStart: run.regionStart)
        }
        // Any pooled view no longer hidden = revealed/removed → dissolve (explosion if it was just tapped).
        for (key, dust) in spoilerDustViews where !present.contains(key) {
            let local = spoilerRevealHint.flatMap { $0.key == key ? $0.canvasPoint
                .applying(CGAffineTransform(translationX: -dust.canvasFrame.minX, y: -dust.canvasFrame.minY)) : nil }
            dust.view.dissolve(explodingAt: local) {}
            spoilerDustViews[key] = nil
        }
        cullSpoilerDust()
    }

    /// Parents + frames one dust view. Cell dust → the table's scrolling content view (content-local, rides
    /// horizontal scroll); everything else → the canvas `spoilerOverlay`. Mirrors `placeEmoji`.
    private func placeSpoilerDust(_ dust: HostedSpoilerDust, canvasFrame: CGRect, regionStart: Int) {
        if let table = tableBox(containingGlobal: regionStart),
           let tv = blockViews[table.id] as? TableBackingView {
            tv.hostEmoji(dust.view, at: canvasFrame.offsetBy(dx: -table.frame.minX, dy: -table.frame.minY)) // dust deliberately shares the emoji content-view hosting seam (rides the table's horizontal scroll; wash stays on top)
        } else {
            if dust.view.superview !== spoilerOverlay { spoilerOverlay.addSubview(dust.view) }
            dust.view.frame = canvasFrame
        }
    }

    /// The dust tint. Telegram colours the dust with the theme's SECONDARY text colour, not the primary text
    /// colour (`spoilerEffectColor: messageTheme.secondaryTextColor` in `ChatMessageTextBubbleContentNode`) —
    /// a muted grey, which is why the dust reads as soft shimmer rather than heavy ink. `.secondaryLabel` is
    /// the system equivalent.
    private func spoilerDustColor(forGlobal pos: Int) -> UIColor {
        return mapper.theme.spoilerDust
    }

    /// No-arg cull: compute the viewport like `cullEmojiViews`.
    func cullSpoilerDust() {
        let visible: CGRect
        if let sv = superview as? UIScrollView { visible = CGRect(origin: sv.contentOffset, size: sv.bounds.size) }
        else { visible = bounds }
        cullSpoilerDust(visibleRect: visible)
    }

    func cullSpoilerDust(visibleRect: CGRect) {
        let expanded = visibleRect.insetBy(dx: -spoilerCullMargin, dy: -spoilerCullMargin)
        for (_, dust) in spoilerDustViews {
            if dust.view.superview is TableContentView { dust.view.isHidden = false; continue }
            dust.view.isHidden = !expanded.intersects(dust.canvasFrame)
        }
    }

    /// The hidden spoiler run under a canvas point (on-screen rects, folding table H-scroll), or nil. Drives
    /// tap-to-reveal (Task 7).
    func hiddenSpoilerRun(at point: CGPoint) -> SpoilerRun? {
        for run in spoilerRuns where run.hidden {
            let rects = selectionRects(globalFrom: run.globalRange.lowerBound, globalTo: run.globalRange.upperBound)
            if rects.contains(where: { $0.insetBy(dx: -2, dy: -2).contains(point) }) { return run }
        }
        return nil
    }

    // MARK: Test accessors
    var spoilerRunsForTesting: [SpoilerRun] { spoilerRuns }
    var spoilerDustCountForTesting: Int { spoilerDustViews.count }
    var firstSpoilerDustForTesting: UIView? { spoilerDustViews.values.first?.view }

    /// Drives a real tap on the first currently-hidden spoiler (caret-inside + explosion), for demo/tests.
    func tapFirstSpoilerForTesting() {
        syncSpoilers()
        guard let run = spoilerRuns.first(where: { $0.hidden }),
              let rect = run.canvasLineRects.first else { return }
        handleTap(at: CGPoint(x: rect.midX, y: rect.midY), time: Date().timeIntervalSinceReferenceDate)
    }
}
#endif
