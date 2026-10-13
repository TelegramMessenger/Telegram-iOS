import XCTest
import UIKit

struct SnapItem {
    let resolvedScreenY: CGFloat  // Visible Y in scrollView coords (transform-aware).
    /// ANALYTIC footprint height — collectGaps/coverage oracles measure THIS (the chain model the walk rides).
    let height: CGFloat
    /// VISIBLE height the view renders (`presentationVisualHeight ?? layer.bounds`). Diverges from `height`
    /// for a footprint-only collapsing tombstone (decoupled-model Stage 2c): the corpse fades at full visual
    /// height while its footprint collapses to 0. Defaults to `height` (a snapshot/viewless tomb's visual ==
    /// its height). VISUAL-behaviour tests read this; continuity/gap oracles must NOT.
    let visualHeight: CGFloat
    let alpha: CGFloat            // Combined: subview.opacity * snap.opacity

    init(resolvedScreenY: CGFloat, height: CGFloat, visualHeight: CGFloat? = nil, alpha: CGFloat) {
        self.resolvedScreenY = resolvedScreenY
        self.height = height
        self.visualHeight = visualHeight ?? height
        self.alpha = alpha
    }
}

struct Frame {
    let time: TimeInterval
    let containerOriginY: CGFloat
    let boundsOriginY: CGFloat
    /// The container LAYER's in-flight presentation translation at this frame (the per-pass additive
    /// "scrollToAnimation" slide on container.layer). `items`/`snapItems` resolvedScreenY are computed
    /// from the SETTLED container frame only and do NOT include this — every child view is a container
    /// subview that visually rides this slide in production, so a test that needs an item's
    /// production-faithful visible Y mid-animation must ADD this. Exposed as a separate field (rather
    /// than folded into resolvedScreenY) so the many top-anchored tests — where it is 0 — are
    /// unaffected, while window-origin-shifting tests can opt into the sound value.
    let containerTranslationY: CGFloat
    let snapshotOriginY: CGFloat?
    let snapItems: [SnapItem]
    let items: [Int: ItemSnapshot]
}

struct ItemSnapshot {
    let modelFrame: CGRect
    let resolvedScreenY: CGFloat       // VISIBLE Y (includes the `moveTravel:` glide) — for trajectory/glide tests.
    let structuralScreenY: CGFloat     // STRUCTURAL Y (EXCLUDES the cosmetic glide) — for flush/coverage measures.
    /// The ANALYTIC footprint height (the chain/walk model — `presentationBoundsHeight`). CONTINUITY and
    /// coverage oracles measure THIS: an insert's footprint tiles `0→h`, a removal's `h→0`, so adjacent
    /// rows stay flush every frame. NOT the visible height — Stage 2a decoupled the two (a full-height
    /// insert reveal overlaps its not-yet-slid neighbours VISUALLY, which is intended and must not read as
    /// a continuity violation).
    let height: CGFloat
    /// The VISIBLE height the view renders (`presentationVisualHeight ?? layer.bounds`) — diverges from
    /// `height` for a footprint-only channel (a 2a insert reveals full-height while its footprint grows).
    /// VISUAL-behaviour tests read this; continuity oracles must NOT.
    let visualHeight: CGFloat
    let alpha: CGFloat
}

typealias Trace = [Frame]

/// A gap detected in the visible coverage at a specific frame.
struct TraceGap {
    let time: TimeInterval
    let y: CGFloat       // top of the gap in viewport coordinates
    let height: CGFloat
}

enum VerticalDir {
    case up    // screenY decreases over time
    case down  // screenY increases over time
}

extension Trace {
    /// A copy of the trace in which the given item indices' `resolvedScreenY` includes the container
    /// LAYER's per-frame presentation translation (`containerTranslationY`) — the production-faithful
    /// visible Y for a child that RIDES a nonzero container slide. The default `sample()`/`screenY` are
    /// container-slide-blind (settled container frame + the child's OWN translation only); this opts the
    /// listed items into the sound value for coverage/continuity assertions.
    ///
    /// As of the 2026-05-24 container-slide-composition fix, CAUSER-model passes (resize/insert/delete/
    /// move) SUPPRESS the container slide (`containerSlideOffset = 0`), so for those `containerTranslationY`
    /// is 0 and this helper is a no-op (early-returns) — survivors/moves are then correct in the blind
    /// convention by construction. It remains meaningful for the passes that STILL fire a slide (the
    /// non-causer scrollTo/newSize paths), where a child's sound Y = blind Y + the slide it rides.
    func soundedForContainerSlide(indices: Set<Int>) -> Trace {
        map { frame in
            guard frame.containerTranslationY != 0 else { return frame }
            var newItems = frame.items
            for idx in indices {
                guard let snap = newItems[idx] else { continue }
                newItems[idx] = ItemSnapshot(modelFrame: snap.modelFrame,
                                             resolvedScreenY: snap.resolvedScreenY + frame.containerTranslationY,
                                             structuralScreenY: snap.structuralScreenY + frame.containerTranslationY,
                                             height: snap.height,
                                             visualHeight: snap.visualHeight,
                                             alpha: snap.alpha)
            }
            return Frame(time: frame.time,
                         containerOriginY: frame.containerOriginY,
                         boundsOriginY: frame.boundsOriginY,
                         containerTranslationY: frame.containerTranslationY,
                         snapshotOriginY: frame.snapshotOriginY,
                         snapItems: frame.snapItems,
                         items: newItems)
        }
    }

    func assertContiguousEveryFrame(file: StaticString = #file, line: UInt = #line) {
        for (i, frame) in enumerated() {
            // Sort by ANALYTIC screen-Y, breaking ties by INDEX (chain order). The tie-break matters at the
            // degenerate frames of the analytic model: a just-inserted row has footprint 0 at t=0 and
            // coincides with its not-yet-slid neighbour — sorting the chain-earlier (lower-index) zero-height
            // item first keeps the pairwise check chain-consistent (its bottom == the neighbour's top ⇒ flush),
            // instead of reading the coincidence as a spurious overlap. A REAL overlap (the lower-index item is
            // genuinely too tall) still fails. Continuity is an analytic property (see ItemSnapshot.height).
            let sorted = frame.items
                .sorted { $0.value.resolvedScreenY != $1.value.resolvedScreenY
                            ? $0.value.resolvedScreenY < $1.value.resolvedScreenY
                            : $0.key < $1.key }
                .map { $0.value }
            for j in 0..<sorted.count - 1 {
                let bottom = sorted[j].resolvedScreenY + sorted[j].height
                let top = sorted[j + 1].resolvedScreenY
                if abs(bottom - top) > 0.5 {
                    XCTFail("Frame \(i) at t=\(frame.time): items at \(sorted[j].resolvedScreenY) and \(top) not contiguous (gap \(top - bottom))",
                            file: file, line: line)
                    return
                }
            }
        }
    }

    func assertNoVisibleJump(maxPerFrameDeltaY: CGFloat,
                             file: StaticString = #file, line: UInt = #line) {
        for i in 1..<count {
            let prev = self[i - 1]
            let curr = self[i]
            for (index, snapshot) in curr.items {
                guard let prevSnapshot = prev.items[index] else { continue }
                let delta = abs(snapshot.resolvedScreenY - prevSnapshot.resolvedScreenY)
                if delta > maxPerFrameDeltaY {
                    XCTFail("Item \(index) jumped \(delta) pt between frame \(i - 1) (t=\(prev.time)) and frame \(i) (t=\(curr.time))",
                            file: file, line: line)
                    return
                }
            }
        }
    }

    func assertEndsAt(clockTime: TimeInterval, tolerance: TimeInterval,
                      file: StaticString = #file, line: UInt = #line) {
        guard let last = last else {
            XCTFail("Empty trace", file: file, line: line); return
        }
        if abs(last.time - clockTime) > tolerance {
            XCTFail("Trace ends at \(last.time), expected \(clockTime) ± \(tolerance)",
                    file: file, line: line)
        }
    }

    func assertItem(_ index: Int, settlesAt screenY: CGFloat, tolerance: CGFloat,
                    file: StaticString = #file, line: UInt = #line) {
        guard let last = last else {
            XCTFail("Empty trace", file: file, line: line); return
        }
        guard let snapshot = last.items[index] else {
            XCTFail("Item \(index) not present in final frame", file: file, line: line); return
        }
        if abs(snapshot.resolvedScreenY - screenY) > tolerance {
            XCTFail("Item \(index) settled at \(snapshot.resolvedScreenY), expected \(screenY) ± \(tolerance)",
                    file: file, line: line)
        }
    }

    func assertItem(_ index: Int, monotonicallyMoves direction: VerticalDir,
                    file: StaticString = #file, line: UInt = #line) {
        var lastValue: CGFloat?
        for frame in self {
            guard let snapshot = frame.items[index] else { continue }
            if let prev = lastValue {
                let delta = snapshot.resolvedScreenY - prev
                switch direction {
                case .up where delta > 0.5:
                    XCTFail("Item \(index) moved down at t=\(frame.time) (expected monotonic up)",
                            file: file, line: line); return
                case .down where delta < -0.5:
                    XCTFail("Item \(index) moved up at t=\(frame.time) (expected monotonic down)",
                            file: file, line: line); return
                default: break
                }
            }
            lastValue = snapshot.resolvedScreenY
        }
    }

    func assertContainerStaysWithin(yRange: ClosedRange<CGFloat>,
                                    file: StaticString = #file, line: UInt = #line) {
        for frame in self {
            if !yRange.contains(frame.containerOriginY) {
                XCTFail("Container y \(frame.containerOriginY) at t=\(frame.time) outside \(yRange)",
                        file: file, line: line); return
            }
        }
    }

    func assertNoOverlap(amongItems range: Range<Int>? = nil,
                         file: StaticString = #file, line: UInt = #line) {
        for f in self {
            let filtered: [ItemSnapshot]
            if let range {
                filtered = f.items.filter { range.contains($0.key) }.values.map { $0 }
            } else {
                filtered = Array<ItemSnapshot>(f.items.values)
            }
            let sorted = filtered.sorted { $0.resolvedScreenY < $1.resolvedScreenY }
            for j in 0..<sorted.count - 1 {
                let bottom = sorted[j].resolvedScreenY + sorted[j].height
                let top = sorted[j + 1].resolvedScreenY
                if bottom - top > 0.5 {
                    XCTFail("Items overlap by \(bottom - top) at t=\(f.time)",
                            file: file, line: line); return
                }
            }
        }
    }

    func assertItem(_ index: Int, fadesIn: Void = (),
                    file: StaticString = #file, line: UInt = #line) {
        guard count >= 2 else {
            XCTFail("Trace too short for fade-in check", file: file, line: line); return
        }
        guard let first = self.first?.items[index],
              let last = self.last?.items[index] else {
            XCTFail("Item \(index) missing in trace endpoints", file: file, line: line); return
        }
        if first.alpha > 0.5 {
            XCTFail("Item \(index) started at alpha \(first.alpha); expected < 0.5",
                    file: file, line: line); return
        }
        if last.alpha < 0.99 {
            XCTFail("Item \(index) ended at alpha \(last.alpha); expected ~1",
                    file: file, line: line); return
        }
    }

    func assertItem(_ index: Int, fadesOut: Void = (),
                    file: StaticString = #file, line: UInt = #line) {
        // The item may leave `activeWindow` partway through (into a snapshot), so we
        // assert that wherever it's last seen in the trace, alpha was decreasing.
        var lastAlpha: CGFloat?
        for frame in self {
            guard let snap = frame.items[index] else { continue }
            if let prev = lastAlpha, snap.alpha > prev + 0.01 {
                XCTFail("Item \(index) alpha increased at t=\(frame.time)",
                        file: file, line: line); return
            }
            lastAlpha = snap.alpha
        }
    }

    /// Asserts the item is rendered fully opaque (alpha ≥ `minAlpha`) at EVERY frame it appears — the
    /// visual signature of a SWAP/glide (one recycled view rides across at alpha 1) as opposed to an
    /// INSERT reveal (alpha 0→1). The inverse of `assertItem(_:fadesIn:)`. This is the move-visual oracle
    /// the position-only invariants miss: a reorder that slips into an insert-look (the moved row blinks
    /// out + fades in at the correct structural slot) passes flush/no-gap/no-jump but FAILS this.
    func assertItem(_ index: Int, staysOpaque: Void = (), minAlpha: CGFloat = 0.9,
                    file: StaticString = #file, line: UInt = #line) {
        var sawFrame = false
        for frame in self {
            guard let snap = frame.items[index] else { continue }
            sawFrame = true
            if snap.alpha < minAlpha {
                XCTFail("Item \(index) dropped to alpha \(snap.alpha) at t=\(frame.time); a swap/glide "
                        + "must stay opaque (≥ \(minAlpha)) — it must not fade in like an insert",
                        file: file, line: line); return
            }
        }
        if !sawFrame {
            XCTFail("Item \(index) never present in trace (staysOpaque)", file: file, line: line)
        }
    }

    /// Returns all gaps detected throughout the trace. A gap is a region of the viewport
    /// where neither an active-window item nor a snap subview (with alpha > threshold)
    /// covers the y-range. Gaps shorter than `minGapHeight` are ignored as sub-pixel noise.
    func collectGaps(alphaThreshold: CGFloat = 0.01,
                     minGapHeight: CGFloat = 2.0) -> [TraceGap] {
        var result: [TraceGap] = []
        for frame in self {
            var rects: [(y: CGFloat, h: CGFloat)] = []
            for item in frame.items.values where item.alpha > alphaThreshold {
                // STRUCTURAL position — coverage/flush must NOT count the cosmetic `moveTravel:` glide (a
                // gliding row's STRUCTURAL slot is covered; its visible glide is a presentation-only overlay).
                rects.append((y: item.structuralScreenY, h: item.height))
            }
            for snap in frame.snapItems where snap.alpha > alphaThreshold {
                rects.append((y: snap.resolvedScreenY, h: snap.height))
            }
            let sorted = rects.sorted { $0.y < $1.y }
            guard sorted.count >= 2 else { continue }
            var coveredMax = sorted[0].y + sorted[0].h
            for j in 1..<sorted.count {
                let nextStart = sorted[j].y
                let gapH = nextStart - coveredMax
                if gapH >= minGapHeight {
                    result.append(TraceGap(time: frame.time, y: coveredMax, height: gapH))
                }
                coveredMax = Swift.max(coveredMax, sorted[j].y + sorted[j].h)
            }
        }
        return result
    }

    /// Asserts the trace has no gaps in its visible coverage at any frame.
    /// Use this for animations where every visible position should be covered throughout.
    func assertNoGaps(alphaThreshold: CGFloat = 0.01,
                      minGapHeight: CGFloat = 2.0,
                      file: StaticString = #file, line: UInt = #line) {
        let gaps = collectGaps(alphaThreshold: alphaThreshold, minGapHeight: minGapHeight)
        if let first = gaps.first {
            XCTFail("Unexpected gap at t=\(first.time): y=\(first.y), height=\(first.height) (\(gaps.count) gaps total)",
                    file: file, line: line)
        }
    }

    /// GT-M (live-member anchoring — Phase C Stage 2). For a band of live members, every frame each
    /// member k must sit at the SOLID BLOCK position:
    ///
    ///     visibleTop(k) == visibleTop(member 0) + Σ fullHeights[0..<k]
    ///
    /// THE ANTI-VACUITY ANCHOR: `fullHeights` are the INDEPENDENT item heights (captured ledger-free —
    /// the caller passes the real row heights, NOT a ledger-derived or position-derived expectation). The
    /// expected offset is the independent full-height prefix sum, so a corrupted member position fails and
    /// a vacuous "members exempt" rule cannot be written here (the Seam-Ledger lesson: tie the oracle to an
    /// independently-pinned route). A wrong `fullHeights` (see the mutation self-test) makes this REJECT.
    ///
    /// `bandMemberIndices` are the window indices of the members in chain order (parallel to `fullHeights`,
    /// which has one entry per member). `visibleTop` reads `ItemSnapshot.resolvedScreenY` (members carry no
    /// `moveTravel:` glide, so structural == visible). A frame missing member 0 is skipped (window-exit).
    func assertBandMembersSolidBlock(bandMemberIndices: [Int],
                                     fullHeights: [CGFloat],
                                     accuracy: CGFloat = 1.0,
                                     file: StaticString = #file, line: UInt = #line) {
        precondition(bandMemberIndices.count == fullHeights.count,
                     "GT-M: bandMemberIndices and fullHeights must be parallel")
        guard let first = bandMemberIndices.first else { return }
        for frame in self {
            guard let top0 = frame.items[first]?.resolvedScreenY else { continue }
            var prefix: CGFloat = 0
            for (j, idx) in bandMemberIndices.enumerated() {
                if let snap = frame.items[idx] {
                    // Position: the solid-block prefix sum (the primary anchor).
                    XCTAssertEqual(snap.resolvedScreenY, top0 + prefix, accuracy: accuracy,
                                   "GT-M member \(idx) off the solid block at t=\(frame.time): top " +
                                   "\(snap.resolvedScreenY) vs member0 \(top0) + Σfull \(prefix)",
                                   file: file, line: line)
                    // The declared full height must match the member's INDEPENDENTLY rendered visual height.
                    // This makes EVERY `fullHeights` entry load-bearing (incl. the last member, whose entry
                    // the prefix sum never consumes) — so a wrong height at ANY position is rejected.
                    XCTAssertEqual(fullHeights[j], snap.visualHeight, accuracy: accuracy,
                                   "GT-M member \(idx) declared full height \(fullHeights[j]) != rendered " +
                                   "visualHeight \(snap.visualHeight) at t=\(frame.time)", file: file, line: line)
                }
                prefix += fullHeights[j]   // INDEPENDENT full-height prefix sum (the anti-vacuity anchor)
            }
        }
    }

    /// GT-C (visible-coverage — Phase C Stage 2, design §2.6). The re-pin gap closer: the solid-block
    /// members sit FULL-height apart while their ANALYTIC footprints are 0 (an analytic seam that is NOT a
    /// visible hole — the member VIEWS are full-height and fade in). `collectGaps()` measures the analytic
    /// footprint and so reports that bounded transient seam; THIS clause measures the VISIBLE rects instead.
    ///
    /// At every frame the union of the members' VISIBLE (`alpha > alphaThreshold`) FULL-HEIGHT rects
    /// (`[resolvedScreenY, resolvedScreenY + visualHeight]`) must cover the block span
    /// `[blockTop, blockTop + Σ visualHeights]` with no uncovered run > `maxHole`. Ledger-INDEPENDENT:
    /// anchored to the rendered full item heights (`ItemSnapshot.visualHeight`) + alpha, never the footprint.
    ///
    /// A frame in which NO member is yet visible (all `alpha ≤ alphaThreshold`, e.g. the very first fade
    /// frame) is skipped — there is nothing on screen to be hole-free. Once any member is visible, the
    /// covered span is taken from the visible members' own top/extent so the clause never asserts coverage
    /// of a region no member is meant to occupy (non-vacuous: a real hole BETWEEN two visible members fails).
    func assertBandMembersVisiblyCover(bandMemberIndices: [Int],
                                       alphaThreshold: CGFloat = 0.01,
                                       maxHole: CGFloat = 1.0,
                                       file: StaticString = #file, line: UInt = #line) {
        for frame in self {
            // VISIBLE full-height rects of the band members, in screen order.
            var rects: [(y: CGFloat, h: CGFloat)] = []
            for idx in bandMemberIndices {
                guard let snap = frame.items[idx], snap.alpha > alphaThreshold else { continue }
                rects.append((y: snap.resolvedScreenY, h: snap.visualHeight))
            }
            guard rects.count >= 2 else { continue }   // <2 visible members ⇒ no internal seam to check
            let sorted = rects.sorted { $0.y < $1.y }
            var coveredMax = sorted[0].y + sorted[0].h
            for j in 1..<sorted.count {
                let hole = sorted[j].y - coveredMax
                if hole > maxHole {
                    XCTFail("GT-C visible hole of \(hole)pt at t=\(frame.time): y=\(coveredMax) " +
                            "(band members \(bandMemberIndices))", file: file, line: line)
                    return
                }
                coveredMax = Swift.max(coveredMax, sorted[j].y + sorted[j].h)
            }
        }
    }

    /// GT-M (corpse anchoring — Phase C Stage 3, requirement B-removal). The inverse of
    /// `assertBandMembersSolidBlock`: for a REMOVAL block, each visible corpse k sits at the SOLID BLOCK
    /// position
    ///
    ///     corpseTop(k) == corpseTop(0) + Σ fullHeights[0..<k]   (+ joinGlide(t), envelope-bounded — Task 3)
    ///
    /// THE ANTI-VACUITY ANCHOR: `fullHeights` are the INDEPENDENT item heights (the caller passes the real
    /// row heights, NOT a ledger- or position-derived expectation). Corpses are read from `snapItems`
    /// (tombstones — they are NOT live window `items`), and `visualHeight` is the rendered full height. A
    /// frame with fewer than 2 VISIBLE corpses (alpha > 0.01) is skipped (nothing on the block to check). A
    /// wrong `fullHeights` (see the mutation self-test) makes this REJECT.
    ///
    /// `maxGlide` bounds an optional per-frame join glide. A joining corpse died ABOVE its full offset (it had
    /// ridden up as its predecessor collapsed) and glides DOWN to the offset (FullModel `glide_envelope`:
    /// `memberPosGlide ≤ E·occMemberPos` — never PAST the full offset — and `≥ occMemberPos + g.amp·E` — never
    /// further than the armed deficit). In SCREEN-Y a SMALLER Y is HIGHER, so the corpse sits in
    /// `[offset − maxGlide, offset]` (at or ABOVE the offset, at most `maxGlide` above, monotone → offset). In
    /// Task 2's same-pass EXACT case `maxGlide == 0`, so each corpse sits at the offset exactly (± `accuracy`).
    func assertBandCorpsesSolidBlock(fullHeights: [CGFloat],
                                     maxGlide: CGFloat = 0,
                                     accuracy: CGFloat = 1.0,
                                     file: StaticString = #file, line: UInt = #line) {
        for frame in self {
            // Visible corpses in screen order (alpha-gated — a faded corpse is not "on the block").
            let visible = frame.snapItems.filter { $0.alpha > 0.01 }
                .sorted { $0.resolvedScreenY < $1.resolvedScreenY }
            guard visible.count >= 2 else { continue }
            // Use only as many corpses as the caller declared full heights for (a removal block of N).
            let n = Swift.min(visible.count, fullHeights.count)
            let top0 = visible[0].resolvedScreenY
            var prefix: CGFloat = 0
            for j in 0..<n {
                let snap = visible[j]
                // Solid-block prefix sum (+ a bounded glide envelope: the corpse is at most `maxGlide` ABOVE
                // its full offset — smaller screen-Y — never below it (glide_envelope, the corpse glides DOWN
                // toward the offset from where it died above).
                XCTAssertGreaterThanOrEqual(snap.resolvedScreenY, top0 + prefix - maxGlide - accuracy,
                    "GT-M corpse \(j) past the glide envelope (too far above) at t=\(frame.time): top " +
                    "\(snap.resolvedScreenY) vs corpse0 \(top0) + Σfull \(prefix) − maxGlide \(maxGlide)",
                    file: file, line: line)
                XCTAssertLessThanOrEqual(snap.resolvedScreenY, top0 + prefix + accuracy,
                    "GT-M corpse \(j) below its full offset at t=\(frame.time): top \(snap.resolvedScreenY) " +
                    "vs corpse0 \(top0) + Σfull \(prefix)", file: file, line: line)
                // The declared full height must match the rendered visualHeight (every entry load-bearing —
                // a wrong height at ANY position is rejected, incl. the last, whose prefix is never consumed).
                XCTAssertEqual(fullHeights[j], snap.visualHeight, accuracy: accuracy,
                    "GT-M corpse \(j) declared full height \(fullHeights[j]) != rendered visualHeight " +
                    "\(snap.visualHeight) at t=\(frame.time)", file: file, line: line)
                prefix += fullHeights[j]   // INDEPENDENT full-height prefix sum (the anti-vacuity anchor)
            }
        }
    }

    /// GT-C (corpse VISIBLE coverage — Phase C Stage 3, requirement B-removal, OQ#2). The inverse of
    /// `assertBandMembersVisiblyCover`: a removal block tiles VISUALLY — the full-height corpse VIEWS hold
    /// stacked offsets while their ANALYTIC footprints collapse to 0 (an analytic seam `collectGaps` reports
    /// but which is NOT a visible hole). THIS clause measures the visible rects instead.
    ///
    /// At every frame the union of the visible (`alpha > alphaThreshold`) FULL-HEIGHT corpse rects — read
    /// from `snapItems` (tombstones), `[resolvedScreenY, resolvedScreenY + visualHeight]` — must have no
    /// uncovered run > `maxHole` inside the corpse block's own span. Ledger-INDEPENDENT: anchored to the
    /// rendered full corpse heights (`SnapItem.visualHeight`) + alpha, never the footprint.
    ///
    /// A frame with fewer than 2 visible corpses (`alpha ≤ alphaThreshold`) is skipped — there is no
    /// internal seam to check (one or zero corpses on the block cannot leave a hole BETWEEN corpses). The
    /// covered span is taken from the visible corpses' own tops/extents so the clause never asserts coverage
    /// of a region no corpse is meant to occupy (non-vacuous: a real hole BETWEEN two visible corpses fails
    /// — see the mutation self-test).
    func assertBandCorpsesVisiblyCover(alphaThreshold: CGFloat = 0.01,
                                       maxHole: CGFloat = 1.0,
                                       file: StaticString = #file, line: UInt = #line) {
        for frame in self {
            // VISIBLE full-height corpse rects (from snapItems — corpses are tombstones), in screen order.
            var rects: [(y: CGFloat, h: CGFloat)] = []
            for snap in frame.snapItems where snap.alpha > alphaThreshold {
                rects.append((y: snap.resolvedScreenY, h: snap.visualHeight))
            }
            guard rects.count >= 2 else { continue }   // <2 visible corpses ⇒ no internal seam to check
            let sorted = rects.sorted { $0.y < $1.y }
            var coveredMax = sorted[0].y + sorted[0].h
            for j in 1..<sorted.count {
                let hole = sorted[j].y - coveredMax
                if hole > maxHole {
                    XCTFail("GT-C corpse visible hole of \(hole)pt at t=\(frame.time): y=\(coveredMax)",
                            file: file, line: line)
                    return
                }
                coveredMax = Swift.max(coveredMax, sorted[j].y + sorted[j].h)
            }
        }
    }

    /// The worst ALPHA-GATED VISIBLE coverage hole across every frame (Phase C Stage 3, OQ#2 — the shared
    /// primitive behind both `assertVisibleSpanCovered` and the fuzz's I1 visible supplement). At each frame it
    /// unions ALL VISIBLE rects — live window items (STRUCTURAL screen-Y: the cosmetic `moveTravel:` glide is a
    /// presentation overlay, the structural slot is what tiles) AND corpse snaps — each `[top, top + visualHeight]`,
    /// alpha-gated (`alpha > alphaThreshold`), and reports the largest uncovered run over the span the rows
    /// occupy. The alpha-gated VISIBLE inverse of `collectGaps` (which reads the ANALYTIC footprint `height`): a
    /// removal block tiles VISUALLY, so an analytic seam is not a visible hole, but a corpse that has FADED to
    /// alpha ≤ threshold WHILE the band is still closing IS a real visible hole this sees.
    ///
    /// `viewportH`: when non-nil, each hole is CLIPPED to `[0, viewportH]` (an off-screen run does not count) —
    /// the fuzz uses this. When nil, the raw (unclipped) hole is returned — `assertVisibleSpanCovered` uses this.
    /// Ledger-INDEPENDENT: anchored to rendered VISUAL heights + alpha, never the footprint. Frames with < 2
    /// visible rects contribute nothing. Returns nil if no frame has any uncovered run.
    func worstVisibleHole(viewportH: CGFloat? = nil,
                          alphaThreshold: CGFloat = 0.01) -> (hole: CGFloat, time: TimeInterval)? {
        var worst: CGFloat = 0
        var worstTime: TimeInterval?
        for frame in self {
            var rects: [(y: CGFloat, h: CGFloat)] = []
            for item in frame.items.values where item.alpha > alphaThreshold && item.visualHeight > 1e-9 {
                rects.append((y: item.structuralScreenY, h: item.visualHeight))
            }
            for snap in frame.snapItems where snap.alpha > alphaThreshold && snap.visualHeight > 1e-9 {
                rects.append((y: snap.resolvedScreenY, h: snap.visualHeight))
            }
            guard rects.count >= 2 else { continue }
            let sorted = rects.sorted { $0.y < $1.y }
            var coveredMax = sorted[0].y + sorted[0].h
            for j in 1..<sorted.count {
                let raw = sorted[j].y - coveredMax
                if raw > 0 {
                    let hole: CGFloat
                    if let viewportH {   // clip the uncovered run to the viewport
                        hole = Swift.min(sorted[j].y, viewportH) - Swift.max(coveredMax, 0)
                    } else {
                        hole = raw
                    }
                    if hole > worst { worst = hole; worstTime = frame.time }
                }
                coveredMax = Swift.max(coveredMax, sorted[j].y + sorted[j].h)
            }
        }
        return worstTime.map { (worst, $0) }
    }

    /// GT-C FULL-SPAN visible coverage (Phase C Stage 3, OQ#2 — the corpse-fade-to-band-deadline oracle).
    /// The production analog of the lab's `walk_sim.alpha_gated_uncovered`: at every frame the union of ALL
    /// VISIBLE rects — live window items AND corpse snaps, each `[top, top + visualHeight]`, alpha-gated —
    /// must have no uncovered run > `maxHole` over the span the rows occupy (see `worstVisibleHole`, the shared
    /// primitive). This is the alpha-gated VISIBLE inverse of `collectGaps` (which reads ANALYTIC footprint
    /// `height`): a removal block tiles VISUALLY, so the analytic seam `collectGaps` reports is NOT a visible
    /// hole, but a corpse that has FADED to alpha ≤ threshold WHILE the band is still closing (its slot not yet
    /// risen-into by the rows below) IS a real visible hole this clause SEES — exactly the OQ#2 staggered-fade
    /// hole the fade-extension closes. Unlike `assertBandCorpsesVisiblyCover` (corpse-rects only — blind once
    /// corpse #1 fully fades and only one corpse is visible), THIS clause includes the live rows, so the faded
    /// corpse's empty slot reads as an uncovered run between the live row above and the live/corpse rows below.
    /// Unclipped (no `viewportH`) — the full span the rows occupy.
    func assertVisibleSpanCovered(alphaThreshold: CGFloat = 0.01,
                                  maxHole: CGFloat = 1.0,
                                  file: StaticString = #file, line: UInt = #line) {
        if let (hole, time) = worstVisibleHole(alphaThreshold: alphaThreshold), hole > maxHole {
            XCTFail("GT-C full-span visible hole of \(hole)pt at t=\(time) (alpha-gated union of visible rects)",
                    file: file, line: line)
        }
    }

    /// The worst FRAME-TO-FRAME jump of any visible corpse (Phase C Stage 3, OQ#1). A corpse GLIDING to its
    /// stacked offset moves continuously (per-frame steps ≪ the total deficit, eased); a corpse SNAPPING from
    /// its death position to the offset shows up as a single large frame-to-frame discontinuity. Identity is
    /// keyed by SCREEN-RANK among the visible corpses (`alpha > 0.01`, sorted by `resolvedScreenY`) — corpses
    /// hold their screen order across a removal block's settle (a snap is a step in ONE row's position, not a
    /// reorder), so rank is a stable surrogate for the missing per-snap id. Frames whose visible-corpse count
    /// changes (a fade crossing the alpha gate) are SKIPPED for the appearing/disappearing rank (the count
    /// boundary is not a position jump). Returns 0 for a trace with <2 frames or no corpses.
    func worstTombPosJump() -> CGFloat {
        var worst: CGFloat = 0
        var prev: [CGFloat]? = nil
        for frame in self {
            let ys = frame.snapItems.filter { $0.alpha > 0.01 }
                .map(\.resolvedScreenY).sorted()
            // Compare rank-by-rank ONLY when the visible-corpse count is unchanged. A count change means a
            // corpse crossed the alpha gate (appeared/faded), which reorders the rank set — comparing across
            // it would alias an unrelated row's position as a "jump" (the fade boundary is not a motion). The
            // glide/freeze position continuity within a stable count is what this measures.
            if let p = prev, p.count == ys.count {
                for k in 0..<ys.count { worst = Swift.max(worst, abs(ys[k] - p[k])) }
            }
            prev = ys
        }
        return worst
    }

    /// Asserts the trace's gaps follow a tracked, bounded pattern:
    /// - No gaps at the first frame (t=0 should match the OLD layout).
    /// - No gaps at the last frame (settled state should match the NEW layout).
    /// - Mid-animation: each gap is at most `maxHeight` tall, and no more than
    ///   `maxConcurrent` gaps exist simultaneously in any frame.
    /// Returns the gaps it observed, so individual tests can make further assertions
    /// about location, lifetime, or count.
    @discardableResult
    func assertTrackedGaps(maxHeight: CGFloat,
                            maxConcurrent: Int = .max,
                            alphaThreshold: CGFloat = 0.01,
                            minGapHeight: CGFloat = 2.0,
                            file: StaticString = #file, line: UInt = #line) -> [TraceGap] {
        let gaps = collectGaps(alphaThreshold: alphaThreshold, minGapHeight: minGapHeight)
        if isEmpty { return gaps }

        // Group gaps by their frame time for "concurrent" check.
        var byTime: [TimeInterval: [TraceGap]] = [:]
        for g in gaps { byTime[g.time, default: []].append(g) }

        let firstTime = self.first!.time
        let lastTime = self.last!.time

        for g in gaps {
            if g.time == firstTime {
                XCTFail("Unexpected gap at start frame t=\(g.time): y=\(g.y), height=\(g.height)",
                        file: file, line: line)
                return gaps
            }
            if g.time == lastTime {
                XCTFail("Unexpected gap at end frame t=\(g.time): y=\(g.y), height=\(g.height)",
                        file: file, line: line)
                return gaps
            }
            if g.height > maxHeight {
                XCTFail("Gap height \(g.height) at t=\(g.time) exceeds maxHeight=\(maxHeight): y=\(g.y)",
                        file: file, line: line)
                return gaps
            }
        }

        for (time, frameGaps) in byTime where frameGaps.count > maxConcurrent {
            XCTFail("Frame t=\(time) has \(frameGaps.count) concurrent gaps, exceeds maxConcurrent=\(maxConcurrent)",
                    file: file, line: line)
            return gaps
        }

        return gaps
    }
}
