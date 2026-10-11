#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit

/// Where a table's cells go. The engine stacks blocks; a table's cells are PLACED instead, on a
/// grid the host solves (`EngineTableGrid`) and pushes as `blockFrames`, relative to the run's
/// anchor. Two synchronous passes: the document set solves columns and pushes widths, so the
/// engine lays each cell out at its width; `layoutSubviews` reads the used heights, solves rows,
/// and pushes final frames only if they differ.
/// Where one table's grid sits inside its engine RUN, and how far in the run's content is indented.
///
/// Adjacent placed blocks share ONE run anchor, so `dy` is the reservation above the table PLUS
/// everything before it in the run. Both the cells and the chrome are placed from this one value: the
/// chrome used to derive its own, which was the same number until adjacent tables gained a run offset
/// — and then the cells moved and the grid did not, which is a table drawn on top of the one above it
/// (device, K3 2026-09-08).
@available(iOS 18.4, *)
internal struct TablePlacement: Equatable {
    let dy: CGFloat
    /// Where the TABLE sits in the run: the container's indent plus the chrome's own gutter.
    let indent: CGFloat
    /// Where the CONTAINER's interior starts, which is where the table is clipped on the LEFT. Equal
    /// to `indent` today; kept separate because they answer different questions (see `syncTableFrames`).
    let containerIndent: CGFloat
    /// How far short of the column the container's interior ENDS, which is where the table is clipped
    /// on the right. A quote keeps its content back on both sides, so a table inside one is narrowed
    /// and cut by this as well as by `containerIndent`.
    let containerTrailingInset: CGFloat
    /// The grid's own size, carried so a consumer needs no second lookup to place the chrome.
    let size: CGSize
}

@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    /// The width a table may occupy: the engine's text width, which is how `id_reconcileDerivedState`
    /// derives the layout width.
    internal var availableTableWidth: CGFloat {
        max(engine.bounds.width - engine.textContainerInset.left - engine.textContainerInset.right, 1)
    }

    /// Re-solved until the cells' used heights are the ones the rows were solved with, at most three
    /// times. A cell's used height is measured at the width it is CURRENTLY placed at, so a pass after
    /// a WIDTH change solves the new columns with the previous width's heights; pushing its frames
    /// re-lays the cells out at the new widths, and nothing else re-solved the rows — the rows below
    /// a wrapping cell kept the previous width's height, overlapping it or leaving a gap (composer
    /// harness p15, fuzz seed 40, `HarnessTableWidthChangeRowHeightTests`). An unchanged document
    /// takes one pass, as before: the heights it read are the heights its push leaves.
    /// TEST ONLY: a test that forces the role-count mismatch on purpose (`EngineDocumentBridge.testHookRenderedBlocks`)
    /// turns the debug assertion below off, to exercise the release path. Always false in the app.
    internal static var testHookExpectsRoleCountMismatch = false

    internal func syncTableFrames() {
        var passes = 0
        while syncTableFramesOnce(), passes < 2 {
            passes += 1
        }
    }

    /// One pass; true when a cell's used height after the push differs from the one it was solved with.
    private func syncTableFramesOnce() -> Bool {
        let identifiers = engine.tgid_blockIdentifiers
        if identifiers.count != currentRoles.count {
            // A broken invariant (`adoptRolePlan` asserts on it too), so it is loud in debug. In RELEASE
            // it used to return here and recover nothing: the roles stayed shifted against the engine's
            // blocks, the model read every block after the split through the wrong role, and the
            // message lost its LAST block — the engine's extra block had no role, so nothing read it
            // (composer harness p23, `HarnessNewlineInOneLineFieldCrashTests`, measured with the
            // assertion disabled). Now the roles are REBUILT from the engine's own identities, as
            // `adoptRolePlan` rebuilds a plan that does not fit: every engine block gets a role (a block
            // the table has never seen arrives as a body paragraph), so whatever structure is lost, no
            // text the engine holds is dropped from what is sent.
            if !Self.testHookExpectsRoleCountMismatch {
                assertionFailure("RichTextEngineEditor: \(identifiers.count) engine blocks against \(currentRoles.count) roles — roles rebuilt by identity")
            }
            NSLog("RichTextEngineEditor: %ld engine blocks against %ld roles — roles rebuilt by identity",
                  identifiers.count, currentRoles.count)
            recoverRolesFromEngineIdentities(identifiers)
        }
        var solvedHeights: [(index: Int, height: CGFloat)] = []

        // PASS 1 — every grid, before any placement. The insets that decide how much of the RUN each
        // table occupies are computed FROM the grids, so they cannot be read while the grids are
        // still being built.
        var grids: [BlockID: EngineTableGrid] = [:]
        var runs: [(range: Range<Int>, table: TableShape, indent: CGFloat, containerIndent: CGFloat,
                    containerTrailingInset: CGFloat)] = []
        var index = 0
        while index < currentRoles.count {
            guard let table = currentRoles[index].owningTable else { index += 1; continue }
            var end = index
            while end < currentRoles.count, currentRoles[end].containerID == table.id { end += 1 }
            var usedHeights: [BlockID: CGFloat] = [:]
            for cellIndex in index..<end {
                let height = engine.id_usedSizeForBlock(at: UInt(cellIndex)).height
                usedHeights[currentRoles[cellIndex].blockID] = height
                solvedHeights.append((cellIndex, height))
            }
            // Frames are relative to the run's anchor at the column edge (probe P2, measured: the
            // run's content view sits at the engine's text origin and carries no indent of its own),
            // so the indent is the host's to add; cells' TEXT is not indented again on top of it
            // (nesting design §4.2).
            //
            // FLUSH with the container's interior — a nested table lines up with the quote's other
            // children, and its grips hang into the container's OWN indent rather than into room the
            // table reserves for them. It briefly reserved a `gripGutter` on each side here; that
            // read as a table pushed in from everything around it (user report, 2026-09-11), and the
            // space was already there. What the grips need instead is a wider WINDOW, which is the
            // chrome's to ask for: `tableClipX`. The vertical reservation stays — the column grip's
            // band is deposited on the last row in `EngineBlockSpacing`, because below a nested table
            // sits the container's own next line and there is no rhythm gap to hang in.
            let containerIndent = currentRoles[index].contentIndent(styleSheet: bridge.styleSheet)
            // Equal today, and kept as two names because they answer different questions: where the
            // TABLE starts, and where its container's interior is (which is what the cells' clip is
            // measured from, and stays right if a table is ever offset inside its container again).
            let indent = containerIndent
            // …and stops the container's trailing inset short of the column, like its text: a quote
            // narrows its content on BOTH sides (legacy's `BlockQuoteBox`), so a table that ran out
            // to the column edge while the paragraphs above it stopped 22pt short read as hanging
            // out of the quote.
            let trailing = currentRoles[index].contentTrailingInset(styleSheet: bridge.styleSheet)
            grids[table.id] = EngineTableGrid.solve(table: table.emptyTable,
                                                    availableWidth: max(1, availableTableWidth - indent - trailing),
                                                    usedHeights: usedHeights)
            runs.append((index..<end, table, indent, containerIndent, trailing))
            index = end
        }
        let layout = EngineBlockSpacing.blockLayout(for: currentRoles, styleSheet: bridge.styleSheet,
                                                    quoteStyle: deferredConfiguration.quoteStyle,
                                                    pullQuoteStyle: deferredConfiguration.pullQuoteStyle,
                                                    grids: grids,
                                                    standaloneFormulas: standaloneFormulaRoleIndices(),
                                                    lineAttributes: spacingLineAttributes())

        // PASS 2 — placement. **EVERY TABLE IS ITS OWN RUN**, declared through `placedRunStarts`, and
        // that is what makes each table a scrolling surface of its own: adjacent placed blocks are
        // ONE run by default, so two tables with nothing stacked between them shared one scroll view
        // (a drag on either scrolled both) and one clip, which the engine keys by the run's FIRST
        // block — so a quoted table following a top-level one was cut at the canvas edge instead of
        // at the quote's interior (user report, K3 2026-09-11). Both were the same missing boundary.
        //
        // A table's grid rects are therefore relative to ITS OWN anchor, which the engine puts at the
        // stacking cursor the previous run's extent left behind. Before the boundary existed the host
        // carried "everything before me in the run" in a `runOffset` instead — the grid plus the
        // bottom insets deposited on its last row — and getting that sum wrong is what once drew a
        // table on top of the one above it (K3, 2026-09-08). The engine's own extent is that sum, so
        // the accumulation is gone rather than kept beside it.
        var frames: [UUID: NSValue] = [:]
        var placements: [BlockID: TablePlacement] = [:]
        var runStarts: Set<UUID> = []
        for run in runs {
            guard let grid = grids[run.table.id] else { continue }
            if run.range.lowerBound < identifiers.count {
                runStarts.insert(identifiers[run.range.lowerBound])
            }
            // Read from the walk that DECIDED it, not re-derived: `layOut` diverts here exactly what
            // it could not put into a placed block's own inset.
            let gapAbove = layout.placedReservations[run.range.lowerBound] ?? 0
            let dy = gapAbove
            for cellIndex in run.range {
                guard let geometry = grid.cell(withID: currentRoles[cellIndex].blockID) else { continue }
                var frame = geometry.rect.offsetBy(dx: run.indent, dy: dy)
                // A last-column cell's frame reaches the grid's right edge, so the run holds the
                // table's right border; its right inset grows by the same amount (the spacing walk
                // reads the same rule), so its text column does not.
                frame.size.width += grid.trailingBorderExtension(for: geometry)
                frames[identifiers[cellIndex]] = NSValue(cgRect: frame)
            }
            placements[run.table.id] = TablePlacement(dy: dy, indent: run.indent,
                                                      containerIndent: run.containerIndent,
                                                      containerTrailingInset: run.containerTrailingInset,
                                                      size: grid.size)
        }
        tableGrids = grids
        tablePlacements = placements
        // Where each run is CLIPPED, from the same rule the chrome window is framed by: the engine
        // cuts the cells there, the chrome view cuts the grips and the outline there, and neither
        // derives the number for itself.
        var clips: [UUID: NSValue] = [:]
        var columns: [UUID: NSValue] = [:]
        for run in runs {
            guard run.range.lowerBound < identifiers.count else { continue }
            let outsets = tableClipOutsets(forTableAt: run.range.lowerBound)
            if outsets != .zero { clips[identifiers[run.range.lowerBound]] = NSValue(uiEdgeInsets: outsets) }
            // …and where the table RESTS, which the clip deliberately no longer answers: the window
            // reaches a grip's width past the container's interior so the handles hanging off the
            // table's edges are drawn, and the table itself must still come to rest ON that interior.
            let column = tableColumnOutsets(forTableAt: run.range.lowerBound)
            if column != .zero { columns[identifiers[run.range.lowerBound]] = NSValue(uiEdgeInsets: column) }
        }
        let clipValue: [UUID: NSValue]? = clips.isEmpty ? nil : clips
        if engine.placedRunClipOutsets != clipValue { engine.placedRunClipOutsets = clipValue }
        let columnValue: [UUID: NSValue]? = columns.isEmpty ? nil : columns
        if engine.placedRunColumnOutsets != columnValue { engine.placedRunColumnOutsets = columnValue }
        // …and where each run BEGINS, so the engine never joins two tables into one. Pushed before
        // the frames: the frames are relative to each table's own anchor, and a pass that took them
        // while the boundary was still missing would place the second table on top of the first.
        let startsValue: Set<UUID>? = runStarts.isEmpty ? nil : runStarts
        if engine.placedRunStarts != startsValue { engine.placedRunStarts = startsValue }
        let value: [UUID: NSValue]? = frames.isEmpty ? nil : frames
        let current = engine.blockFrames
        guard current != value else { return false }
        engine.blockFrames = value
        return solvedHeights.contains { engine.id_usedSizeForBlock(at: UInt($0.index)).height != $0.height }
    }
}
#endif
