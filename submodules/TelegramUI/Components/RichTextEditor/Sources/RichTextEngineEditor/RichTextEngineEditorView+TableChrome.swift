#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit

/// What a table looks like around its cells: the rounded outer frame, the grid when `bordered`,
/// header and cell fills. Drawn from the solver's rects — the same numbers the cells were placed
/// with — so chrome and text cannot disagree. `TableBlockBox.draw(in:)` is the reference.
@available(iOS 18.4, *)
internal final class TableChromeView: UIView {
    /// The fills, clipped to the table's rounded outer edge — one view per filled cell, in a
    /// container that IS the clip. `clipsToBounds` + `cornerRadius` is the same shape the drawn
    /// version added as a path and then clipped to.
    private let fillClip = UIView()
    /// The outer frame, ON TOP of the fills and the interior lines, as a layer border: a border is
    /// painted inside the layer's own rounded edge, which is exactly a stroke whose outer edge sits
    /// on the table's outer rect.
    private let outerBorder = UIView()
    private var fillViews: [UIView] = []
    private var lineViews: [UIView] = []

    private var grid: EngineTableGrid?
    private var table: TableBlock?
    private var borderColor: UIColor = .separator
    private var headerColor: UIColor = .clear

    /// Test seams: what the chrome SHOWS — the grid segments (the outer frame first, then the
    /// interior lines) and the cell fills, in this view's own coordinates. Derived from the views
    /// themselves, so they cannot describe anything the screen does not.
    internal private(set) var gridLineRects: [CGRect] = []
    internal private(set) var fillRects: [CGRect] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        fillClip.isUserInteractionEnabled = false
        fillClip.clipsToBounds = true
        addSubview(fillClip)
        outerBorder.isUserInteractionEnabled = false
        outerBorder.backgroundColor = .clear
        addSubview(outerBorder)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("not supported") }

    internal func update(grid: EngineTableGrid, table: TableBlock, theme: RichTextEditorTheme) {
        self.grid = grid
        self.table = table
        borderColor = theme.tableBorder
        headerColor = theme.tableHeaderBackground
        reconcile()
    }

    /// Every piece of the grid, as a frame and a colour. NOTHING here draws: a pass that only moved
    /// the table — a scroll, a resize — assigns frames, and the layer tree redraws no pixels.
    private func reconcile() {
        guard let grid, let table else { return }
        let border = grid.borderWidth
        let half = border / 2

        // The clip: the outer path the drawn version built, as a view. Its corner radius is the
        // outer radius pulled in by the same half border, so a corner cell's fill stops on the same
        // curve.
        fillClip.frame = CGRect(x: half, y: half,
                                width: grid.size.width - border, height: grid.size.height - border)
        fillClip.layer.cornerRadius = max(EngineTableGrid.outerCornerRadius - half, 0)

        var fills: [(rect: CGRect, colour: UIColor)] = []
        for geometry in grid.cells {
            let cell = table.rows[geometry.row].cells.first { $0.id == geometry.cellID }
            var fill: UIColor?
            if cell?.isHeader == true { fill = headerColor }
            if let background = cell?.background {
                fill = UIColor(red: background.red, green: background.green,
                               blue: background.blue, alpha: background.alpha)
            }
            guard let fill else { continue }
            fills.append((geometry.rect, fill))
        }
        fillViews = reuse(fillViews, count: fills.count, into: fillClip)
        for (view, fill) in zip(fillViews, fills) {
            view.frame = fill.rect.offsetBy(dx: -half, dy: -half)
            view.backgroundColor = fill.colour
        }
        fillRects = fills.map(\.rect)

        let bordered = table.bordered && border > 0
        outerBorder.isHidden = !bordered
        outerBorder.frame = bounds
        outerBorder.layer.borderWidth = bordered ? border : 0
        outerBorder.layer.borderColor = borderColor.cgColor
        outerBorder.layer.cornerRadius = EngineTableGrid.outerCornerRadius

        let lines = bordered ? interiorLines(grid) : []
        lineViews = reuse(lineViews, count: lines.count, into: self)
        for (view, line) in zip(lineViews, lines) {
            view.frame = line
            view.backgroundColor = borderColor
        }
        // The border last, so it sits above the lines and the fills — the order the drawn version
        // painted them in.
        bringSubviewToFront(outerBorder)
        gridLineRects = (bordered ? [CGRect(origin: .zero, size: grid.size)] : []) + lines
    }

    /// The interior grid, as SEGMENTS that stop at a merged cell rather than one line per gap with
    /// the merged cells painted back over it. The drawn version needed that second pass — and a
    /// `.copy` blend, to erase a line under a merged cell with no fill of its own — because a line
    /// it had already painted could only be taken back by painting over it. A segment that is never
    /// added needs no eraser, and a fill that happens to be `clear` no longer has to double as one.
    private func interiorLines(_ grid: EngineTableGrid) -> [CGRect] {
        let border = grid.borderWidth
        var result: [CGRect] = []

        /// The bands one axis is divided into, as (start, end) pairs of the cell runs themselves.
        func bands(_ extents: [CGFloat], from origin: CGFloat) -> [(min: CGFloat, max: CGFloat)] {
            var out: [(CGFloat, CGFloat)] = []
            var position = origin
            for extent in extents {
                out.append((position, position + extent))
                position += extent + border
            }
            return out
        }
        let columnBands = bands(grid.columnWidths, from: border)
        let rowBands = bands(grid.rowHeights, from: border)

        /// Runs of consecutive bands with no cell spanning `gap`, as index ranges.
        func keptRuns(_ count: Int, spans: (Int) -> Bool) -> [ClosedRange<Int>] {
            var runs: [ClosedRange<Int>] = []
            var start: Int?
            for index in 0..<count {
                if spans(index) {
                    if let begun = start { runs.append(begun...(index - 1)); start = nil }
                } else if start == nil {
                    start = index
                }
            }
            if let begun = start, count > 0 { runs.append(begun...(count - 1)) }
            return runs
        }

        for (index, band) in columnBands.enumerated() where index < columnBands.count - 1 {
            let x = band.max
            let crossed = { (row: Int) in
                grid.cells.contains { cell in
                    cell.rect.minX < x + 0.5 && cell.rect.maxX > x + border - 0.5
                        && cell.rect.minY < rowBands[row].max - 0.5 && cell.rect.maxY > rowBands[row].min + 0.5
                }
            }
            for run in keptRuns(rowBands.count, spans: crossed) {
                let top = run.lowerBound == 0 ? border : rowBands[run.lowerBound].min - border
                let bottom = run.upperBound == rowBands.count - 1
                    ? grid.size.height - border : rowBands[run.upperBound].max + border
                result.append(CGRect(x: x, y: top, width: border, height: bottom - top))
            }
        }
        for (index, band) in rowBands.enumerated() where index < rowBands.count - 1 {
            let y = band.max
            let crossed = { (column: Int) in
                grid.cells.contains { cell in
                    cell.rect.minY < y + 0.5 && cell.rect.maxY > y + border - 0.5
                        && cell.rect.minX < columnBands[column].max - 0.5
                        && cell.rect.maxX > columnBands[column].min + 0.5
                }
            }
            for run in keptRuns(columnBands.count, spans: crossed) {
                let left = run.lowerBound == 0 ? border : columnBands[run.lowerBound].min - border
                let right = run.upperBound == columnBands.count - 1
                    ? grid.size.width - border : columnBands[run.upperBound].max + border
                result.append(CGRect(x: left, y: y, width: right - left, height: border))
            }
        }
        return result
    }

    /// Pooled plain views: a table's grid changes shape on every structural edit, and creating a
    /// fresh layer per line per pass is the cost this refactor exists to avoid.
    private func reuse(_ views: [UIView], count: Int, into parent: UIView) -> [UIView] {
        var result = views
        while result.count > count { result.removeLast().removeFromSuperview() }
        while result.count < count {
            let view = UIView()
            view.isUserInteractionEnabled = false
            parent.addSubview(view)
            result.append(view)
        }
        return result
    }
}

@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    /// The table's full frame in engine coordinates, recovered from where the engine put its first
    /// cell: that cell's text origin minus its insets minus the cell's own offset in the grid.
    internal func tableFrame(forTableAt firstCellIndex: Int) -> CGRect? {
        guard firstCellIndex < currentRoles.count,
              let table = currentRoles[firstCellIndex].owningTable,
              let grid = tableGrids[table.id],
              let geometry = grid.cell(withID: currentRoles[firstCellIndex].blockID) else { return nil }
        let text = engine.id_frameForBlock(at: UInt(firstCellIndex))
        guard !text.isNull else { return nil }
        let origin = CGPoint(x: text.minX - geometry.textInsets.left - geometry.rect.minX,
                             y: text.minY - geometry.textInsets.top - geometry.rect.minY)
        return CGRect(origin: origin, size: grid.size)
    }

    internal func syncTableChrome() {
        var live: Set<BlockID> = []
        var index = 0
        while index < currentRoles.count {
            guard let table = currentRoles[index].owningTable else { index += 1; continue }
            defer {
                while index < currentRoles.count, currentRoles[index].containerID == table.id { index += 1 }
            }
            // A table in the ROLES with no grid draws NOTHING — no chrome, no cells, no word about
            // it. That silence is what made the K3 "the table is not inserted" report take a whole
            // session to localise: the document was right every time and the screen was empty. It is
            // a programming error, not a state to tolerate, so say so.
            guard let grid = tableGrids[table.id], let frame = tableFrame(forTableAt: index) else {
                assertionFailure("RichTextEngineEditor: table \(table.id.rawValue) has a role but no grid — it will not be drawn")
                NSLog("RichTextEngineEditor: table %@ has a role but no grid (roles %ld, engine blocks %ld) — not drawn",
                      table.id.rawValue, currentRoles.count, engine.tgid_blockIdentifiers.count)
                continue
            }
            live.insert(table.id)
            let chrome: TableChromeView
            if let existing = tableChromeViews[table.id] {
                chrome = existing
            } else {
                chrome = TableChromeView()
                tableChromeViews[table.id] = chrome
            }
            // One scrolling surface, as legacy: the chrome lives INSIDE the run's content view,
            // behind the cells, so grid and text scroll together and clip together.
            if let content = engine.id_placedRunContentViewForBlock(at: UInt(index)) {
                if chrome.superview !== content { chrome.removeFromSuperview(); content.insertSubview(chrome, at: 0) }
                // The chrome is placed by the SAME NUMBER the cells were, read from where that
                // number is computed rather than derived again here. It used to recompute
                // `tableGapAbove` for itself, which was the same value until adjacent tables gained a
                // run offset — and then the cells moved and the grid did not, so a table drew on top
                // of the one above it while its text sat correctly below (device, K3 2026-09-08).
                // Two places deriving one number is what this comment used to promise against.
                // NO fallback. A missing offset means the table was not placed, and guessing a
                // plausible number is what let a grid draw in the wrong place while looking
                // reasonable. Fail loudly, as `syncTableFrames`' count-mismatch guard does.
                guard let placement = tablePlacements[table.id] else {
                    assertionFailure("RichTextEngineEditor: table \(table.id.rawValue) has a grid but no placement — its chrome cannot be positioned")
                    NSLog("RichTextEngineEditor: table %@ has a grid but no placement", table.id.rawValue)
                    continue
                }
                let chromeFrame = CGRect(origin: CGPoint(x: placement.indent, y: placement.dy), size: placement.size)
                if chrome.frame != chromeFrame { chrome.frame = chromeFrame }
            } else {
                if chrome.superview !== engine { chrome.removeFromSuperview(); engine.insertSubview(chrome, at: 0) }
                if chrome.frame != frame { chrome.frame = frame }
            }
            chrome.update(grid: grid, table: table.emptyTable, theme: composerHostState.theme)
        }
        for (id, view) in tableChromeViews where !live.contains(id) {
            view.removeFromSuperview()
            tableChromeViews[id] = nil
        }
    }
}
#endif
