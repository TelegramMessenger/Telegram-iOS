import Foundation
import UIKit
import QuartzCore

/// Opaque per-layout reveal-cost description. Public surface is just `total` (the running
/// length used to drive `TextRevealController`); internals are coupled to `applyReveal`'s
/// view-tree walk (same module, same file).
public struct InstantPageV2RevealCostMap {
    public let total: Int
    fileprivate let topLevelEntries: [Entry]
}

extension InstantPageV2RevealCostMap {
    fileprivate enum Entry {
        case text(start: Int, end: Int)
        case nonText(start: Int, end: Int)
        case thinking(start: Int)
        case details(start: Int, end: Int, body: InstantPageV2RevealCostMap?)
        case codeBlock(start: Int, end: Int)
        case table(start: Int, end: Int, rows: [TableRow], title: InstantPageV2RevealCostMap?)
    }

    fileprivate struct TableRow {
        let startCount: Int
        let cells: [InstantPageV2RevealCostMap?]
    }
}

// Reveal cost is in width units (points along the reading direction). The unit is uniform
// across all item kinds, so the streaming reveal pace ("points per second") is visually
// consistent — wide tables and media take proportionally longer than narrow inline text.
//
// For text items, the cost is the sum of glyph ink widths across all lines (the total ink
// extent in reading direction). For non-text items, the cost is `item.frame.width`. Zero-width
// items (e.g. anchors) contribute 0 and are revealed instantly when the cursor reaches them.

private func textInkWidth(_ textItem: InstantPageTextItem) -> Int {
    var total: CGFloat = 0.0
    for line in textItem.lines {
        if let chars = line.characterRects {
            for r in chars where !r.isEmpty {
                total += r.width
            }
        } else {
            total += line.frame.width
        }
    }
    return max(0, Int(total.rounded()))
}

private func itemWidthCost(_ item: InstantPageV2LaidOutItem) -> Int {
    return max(0, Int(item.frame.width.rounded()))
}

/// Convert a width-budget (cost in points) into a character count for a text item.
/// Walks the item's lines and per-glyph rects accumulating widths until the budget runs out;
/// returns the character index of the first glyph not yet fully covered. Used to bridge the
/// width-based cost map to the per-character mask API on `InstantPageV2TextView`.
private func charCountForWidthBudget(textItem: InstantPageTextItem, widthBudget: Int) -> Int {
    var remaining = CGFloat(widthBudget)
    var count = 0
    for line in textItem.lines {
        if remaining <= 0 { break }
        guard let chars = line.characterRects else {
            let lineWidth = line.frame.width
            if remaining >= lineWidth {
                count += line.range.length
                remaining -= lineWidth
            } else {
                let frac = remaining / max(lineWidth, 0.001)
                count += Int((CGFloat(line.range.length) * frac).rounded(.down))
                remaining = 0
            }
            continue
        }
        var lineDone = false
        for r in chars {
            let w = max(0, r.width)
            if remaining >= w {
                remaining -= w
                count += 1
            } else {
                lineDone = true
                break
            }
        }
        if lineDone {
            break
        }
    }
    return count
}

public extension InstantPageV2Layout {
    func computeRevealCostMap() -> InstantPageV2RevealCostMap {
        var cursor = 0
        let entries = computeEntries(items: self.items, cursor: &cursor)
        return InstantPageV2RevealCostMap(total: cursor, topLevelEntries: entries)
    }
}

public extension InstantPageV2RevealCostMap {
    /// Size that the layout would occupy if only the items revealed up to `revealedCount`
    /// were visible. Width is the layout's full content width (we don't shrink horizontally,
    /// since text wraps to the layout-decided width and shrinking would cause visual jitter).
    /// Height is the bottom y of the revealed prefix:
    ///
    /// * Fully-revealed items contribute their full frame.maxY.
    /// * Partially-revealed text items contribute the bottom y of their last revealed line.
    /// * Partially-revealed tables contribute up to the last revealed row's bottom y.
    /// * Non-text items (formula, media, etc.) contribute only once revealedCount >= entry.endCount.
    /// * `details` / `codeBlock`: the whole container appears as soon as revealedCount > entry.start
    ///   (background and chrome pop in atomically, then inner text reveals char-by-char).
    ///
    /// Used by the rich-data bubble to size itself to the revealed prefix during AI streaming,
    /// mirroring TextBubble's `clippedGlyphCountLayout = textLayout.layoutForCharacterCount(...)`.
    func revealedContentSize(revealedCount: Int, layout: InstantPageV2Layout) -> CGSize {
        let bounds = computeRevealedBounds(items: layout.items, entries: self.topLevelEntries, revealedCount: revealedCount)
        if bounds.maxY <= 0.0 {
            return CGSize(width: layout.contentSize.width, height: 0.0)
        }
        // The full layout reserves a closing spacing after the last top-level block (see
        // `closingSpacing` in layoutBlockSequence). Mirror that so a partially-revealed
        // bubble has the same bottom padding as a fully-revealed one — otherwise the last
        // revealed line sits flush against the bubble's bottom edge.
        let lastItemMaxY = layout.items.map { $0.frame.maxY }.max() ?? 0.0
        let closingPad = max(0.0, layout.contentSize.height - lastItemMaxY)
        return CGSize(width: layout.contentSize.width, height: bounds.maxY + closingPad)
    }

    /// Returns the maxY of revealed items in `layout` coords (no closing pad). Use this to
    /// size the InstantPageV2View itself so its content never overflows past the revealed
    /// extent — the bubble's closing pad sits in containerNode space *outside* the pageView,
    /// not inside it (where unrevealed items would otherwise draw).
    func revealedItemsMaxY(revealedCount: Int, layout: InstantPageV2Layout) -> CGFloat {
        let bounds = computeRevealedBounds(items: layout.items, entries: self.topLevelEntries, revealedCount: revealedCount)
        return max(0.0, bounds.maxY)
    }
}

private func computeRevealedBounds(items: [InstantPageV2LaidOutItem], entries: [InstantPageV2RevealCostMap.Entry], revealedCount: Int) -> CGRect {
    var bounds: CGRect = .zero
    var initialized = false
    let n = min(items.count, entries.count)
    for i in 0 ..< n {
        guard let extent = revealedExtent(entry: entries[i], item: items[i], revealedCount: revealedCount) else {
            continue
        }
        if initialized {
            bounds = bounds.union(extent)
        } else {
            bounds = extent
            initialized = true
        }
    }
    return bounds
}

private func revealedExtent(entry: InstantPageV2RevealCostMap.Entry, item: InstantPageV2LaidOutItem, revealedCount: Int) -> CGRect? {
    switch entry {
    case let .text(start, end):
        if revealedCount <= start { return nil }
        if revealedCount >= end { return item.frame }
        if case let .text(textItem) = item {
            return revealedTextExtent(textItem: textItem.textItem, itemFrame: item.frame, localRevealedCount: revealedCount - start)
        }
        return item.frame
    case let .nonText(start, end):
        let _ = start
        if revealedCount < end { return nil }
        return item.frame
    case let .thinking(start):
        // Revealed (and contributes its full height) once the cursor reaches its index position.
        // A top thinking block (start == 0) is revealed from the first frame.
        if revealedCount < start { return nil }
        return item.frame
    case let .codeBlock(start, _):
        if revealedCount <= start { return nil }
        // Block backdrop appears atomically once revealing reaches the block; inner text
        // is char-revealed inside. Bubble height grows by the full block height in one
        // step rather than mid-block.
        return item.frame
    case let .details(start, _, body):
        if revealedCount <= start { return nil }
        if case let .details(detailsItem) = item {
            // Title region appears as soon as the details block is reached.
            var bounds = CGRect(
                x: detailsItem.frame.minX,
                y: detailsItem.frame.minY,
                width: detailsItem.frame.width,
                height: detailsItem.titleFrame.maxY
            )
            if let body, let innerLayout = detailsItem.innerLayout, detailsItem.isExpanded {
                let bodyBounds = computeRevealedBounds(items: innerLayout.items, entries: body.topLevelEntries, revealedCount: revealedCount)
                if !bodyBounds.isEmpty {
                    let bodyAbs = bodyBounds.offsetBy(dx: detailsItem.frame.minX, dy: detailsItem.frame.minY + detailsItem.titleFrame.maxY)
                    bounds = bounds.union(bodyAbs)
                }
            }
            return bounds
        }
        return item.frame
    case let .table(start, end, rows, _):
        if revealedCount <= start { return nil }
        if revealedCount >= end { return item.frame }
        if case let .table(tableItem) = item {
            let gridOffsetY = tableItem.titleFrame?.height ?? 0.0
            var lastRevealedRowIndex: Int? = nil
            for (rowIdx, row) in rows.enumerated() {
                if revealedCount >= row.startCount {
                    lastRevealedRowIndex = rowIdx
                } else {
                    break
                }
            }
            let groupedByY = Dictionary(grouping: tableItem.cells, by: { $0.frame.minY })
            let sortedRowYs = groupedByY.keys.sorted()
            let heightInTable: CGFloat
            if let idx = lastRevealedRowIndex, idx < sortedRowYs.count {
                let rowY = sortedRowYs[idx]
                let cellsInRow = groupedByY[rowY] ?? []
                let rowMaxY = cellsInRow.map { $0.frame.maxY }.max() ?? 0.0
                heightInTable = gridOffsetY + rowMaxY
            } else {
                heightInTable = gridOffsetY
            }
            return CGRect(
                x: tableItem.frame.minX,
                y: tableItem.frame.minY,
                width: tableItem.frame.width,
                height: heightInTable
            )
        }
        return item.frame
    }
}

/// Returns the y-extent (= bottom of the last revealed line) of a text item given a
/// width-based local cursor. Walks lines summing per-line ink widths; the last line whose
/// preceding-line-widths-sum is < cursor is the last revealed line.
private func revealedTextExtent(textItem: InstantPageTextItem, itemFrame: CGRect, localRevealedCount: Int) -> CGRect {
    var remaining = CGFloat(localRevealedCount)
    var lastRevealedLineMaxY: CGFloat = 0.0
    for line in textItem.lines {
        if remaining <= 0 { break }
        lastRevealedLineMaxY = max(lastRevealedLineMaxY, line.frame.maxY)
        let lineWidth: CGFloat
        if let chars = line.characterRects {
            var sum: CGFloat = 0
            for r in chars where !r.isEmpty {
                sum += r.width
            }
            lineWidth = sum
        } else {
            lineWidth = line.frame.width
        }
        remaining -= lineWidth
    }
    return CGRect(x: itemFrame.minX, y: itemFrame.minY, width: itemFrame.width, height: lastRevealedLineMaxY)
}

private func computeEntries(items: [InstantPageV2LaidOutItem], cursor: inout Int) -> [InstantPageV2RevealCostMap.Entry] {
    var entries: [InstantPageV2RevealCostMap.Entry] = []
    for item in items {
        switch item {
        case let .text(text):
            let start = cursor
            cursor += textInkWidth(text.textItem)
            entries.append(.text(start: start, end: cursor))
        case let .codeBlock(block):
            let start = cursor
            cursor += textInkWidth(block.textItem)
            entries.append(.codeBlock(start: start, end: cursor))
        case let .details(details):
            let start = cursor
            cursor += textInkWidth(details.titleTextItem)
            var body: InstantPageV2RevealCostMap? = nil
            if details.isExpanded, let inner = details.innerLayout {
                var innerCursor = cursor
                let innerEntries = computeEntries(items: inner.items, cursor: &innerCursor)
                let innerTotal = innerCursor - cursor
                cursor = innerCursor
                body = InstantPageV2RevealCostMap(total: innerTotal, topLevelEntries: innerEntries)
            }
            entries.append(.details(start: start, end: cursor, body: body))
        case let .table(table):
            let start = cursor

            var titleMap: InstantPageV2RevealCostMap? = nil
            if let titleLayout = table.titleSubLayout {
                var titleCursor = cursor
                let titleEntries = computeEntries(items: titleLayout.items, cursor: &titleCursor)
                let titleTotal = titleCursor - cursor
                cursor = titleCursor
                titleMap = InstantPageV2RevealCostMap(total: titleTotal, topLevelEntries: titleEntries)
            }

            // Group cells by frame.minY (rows in top-to-bottom order); within each row, left-to-right.
            let groupedByY = Dictionary(grouping: table.cells, by: { $0.frame.minY })
            let sortedRowYs = groupedByY.keys.sorted()

            var rows: [InstantPageV2RevealCostMap.TableRow] = []
            for rowY in sortedRowYs {
                let cellsInRow = (groupedByY[rowY] ?? []).sorted(by: { $0.frame.minX < $1.frame.minX })
                let rowStart = cursor
                var cellMaps: [InstantPageV2RevealCostMap?] = []
                for cell in cellsInRow {
                    // Each cell consumes at least its frame.width worth of cursor advance,
                    // even if its inner text ink width is smaller (or it has no subLayout
                    // at all). Without this floor, narrow- or empty-cell tables ran through
                    // the cursor much faster than their visual width warrants — a 3-column
                    // table of "1"/"2"/"3" costs ~30pt while occupying ~200pt visually.
                    // Text inside a cell still char-reveals against its own ink widths; the
                    // "extra" cost (cell width − inner ink) is filler time during which the
                    // cell's text is fully revealed and the cursor is moving through padding
                    // before reaching the next cell.
                    let cellWidthFloor = max(0, Int(cell.frame.width.rounded()))
                    if let subLayout = cell.subLayout {
                        var cellCursor = cursor
                        let cellEntries = computeEntries(items: subLayout.items, cursor: &cellCursor)
                        let cellInnerCost = cellCursor - cursor
                        cursor += max(cellInnerCost, cellWidthFloor)
                        cellMaps.append(InstantPageV2RevealCostMap(total: cellInnerCost, topLevelEntries: cellEntries))
                    } else {
                        cellMaps.append(nil)
                        cursor += cellWidthFloor
                    }
                }
                rows.append(InstantPageV2RevealCostMap.TableRow(startCount: rowStart, cells: cellMaps))
            }
            entries.append(.table(start: start, end: cursor, rows: rows, title: titleMap))
        case .thinking:
            // Zero cost: do NOT advance the cursor. This is the linchpin — answer-content cursor
            // positions are identical whether or not thinking blocks are present, so adding/
            // removing a thinking block never jumps the answer's reveal position.
            entries.append(.thinking(start: cursor))
        case .formula, .inlineButton, .buttonRow, .document, .mediaImage, .mediaVideo, .mediaMap, .mediaCoverImage, .mediaAudio, .mediaPlaceholder, .slideshow,
             .divider, .listMarker, .blockQuoteBar, .shape, .imageOrnament, .anchor, .quoteFrame, .unsupportedContent:
            let start = cursor
            cursor += itemWidthCost(item)
            entries.append(.nonText(start: start, end: cursor))
        }
    }
    return entries
}

public extension InstantPageV2View {
    /// Push reveal state into the V2 view tree.
    ///
    /// - `revealedCount == nil` (and `costMap == nil`): clear all reveal state, removing
    ///   masks and showing every item fully.
    /// - Otherwise: walk `self.itemViews` alongside the cost map's `topLevelEntries`, updating
    ///   text views' per-character reveal, non-text views' visibility, table row masks, and
    ///   recursing into nested V2 views (details body, table cells, table title).
    ///
    /// `animated` controls non-text visibility cross-fades and table-row-mask growth; per-text-view
    /// glyph counts are written directly (smoothness comes from the display-link tick frequency).
    func applyReveal(revealedCount: Int?, costMap: InstantPageV2RevealCostMap?, animated: Bool) {
        guard let costMap, let revealedCount else {
            // Clear path
            for view in self.itemViews {
                clearRevealOn(view: view, animated: animated)
            }
            self.updateEmojiReveal(animated: animated)
            self.updateImageReveal(animated: animated)
            return
        }

        // Walk views + entries in lockstep. The orderings of itemViews and topLevelEntries
        // match because both are produced by walking layout.items in array order.
        let entries = costMap.topLevelEntries
        let entryCount = min(entries.count, self.itemViews.count)
        for i in 0 ..< entryCount {
            let view = self.itemViews[i]
            let entry = entries[i]
            applyRevealEntry(view: view, entry: entry, revealedCount: revealedCount, animated: animated)
        }
        // If counts mismatch (shouldn't in a clean apply right after update(layout:)), clear extras.
        if self.itemViews.count > entryCount {
            for i in entryCount ..< self.itemViews.count {
                clearRevealOn(view: self.itemViews[i], animated: animated)
            }
        }
        self.updateEmojiReveal(animated: animated)
        self.updateImageReveal(animated: animated)
    }
}

private func applyRevealEntry(view: InstantPageItemView, entry: InstantPageV2RevealCostMap.Entry,
                              revealedCount: Int, animated: Bool) {
    switch entry {
    case let .text(start, end):
        if let textView = view as? InstantPageV2TextView {
            let localWidth = max(0, min(revealedCount - start, end - start))
            let charCount = (localWidth >= (end - start))
                ? textView.item.textItem.attributedString.length
                : charCountForWidthBudget(textItem: textView.item.textItem, widthBudget: localWidth)
            textView.updateRevealCharacterCount(value: charCount, animated: animated)
        }
    case let .codeBlock(start, end):
        if let codeView = view as? InstantPageV2CodeBlockView {
            let localWidth = max(0, min(revealedCount - start, end - start))
            let charCount = (localWidth >= (end - start))
                ? codeView.textView.item.textItem.attributedString.length
                : charCountForWidthBudget(textItem: codeView.textView.item.textItem, widthBudget: localWidth)
            codeView.textView.updateRevealCharacterCount(value: charCount, animated: animated)
            let visible = revealedCount >= start
            applyVisibility(view: codeView, visible: visible, animated: animated)
        }
    case let .details(start, end, body):
        if let detailsView = view as? InstantPageV2DetailsView {
            let titleTextItem = detailsView.titleTextView.item.textItem
            let titleWidth = textInkWidth(titleTextItem)
            let titleLocal = max(0, min(revealedCount - start, titleWidth))
            let charCount = (titleLocal >= titleWidth)
                ? titleTextItem.attributedString.length
                : charCountForWidthBudget(textItem: titleTextItem, widthBudget: titleLocal)
            detailsView.titleTextView.updateRevealCharacterCount(value: charCount, animated: animated)
            if let body, let bodyView = detailsView.bodyView {
                bodyView.applyReveal(revealedCount: revealedCount, costMap: body, animated: animated)
            }
            let _ = end
        }
    case let .table(start, end, rows, title):
        if let tableView = view as? InstantPageV2TableView {
            applyTableReveal(tableView: tableView, start: start, end: end, rows: rows, title: title,
                             revealedCount: revealedCount, animated: animated)
        }
    case let .nonText(start, end):
        let visible = revealedCount >= end
        applyVisibility(view: view, visible: visible, animated: animated)
        let _ = start
    case let .thinking(start):
        // Whole-block 0.12s alpha fade-in at the index position; inner text is drawn fully
        // (never char-reveal-masked) — the shimmer is the only ongoing animation.
        let visible = revealedCount >= start
        applyVisibility(view: view, visible: visible, animated: animated)
    }
}

private func applyVisibility(view: UIView, visible: Bool, animated: Bool) {
    let targetAlpha: CGFloat = visible ? 1.0 : 0.0
    if !animated {
        view.alpha = targetAlpha
        view.isHidden = !visible
        return
    }
    if visible {
        if view.alpha == 1.0 && !view.isHidden { return }
        view.isHidden = false
        let from = view.alpha
        view.alpha = 1.0
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = from
        anim.toValue = 1.0
        anim.duration = 0.12
        view.layer.add(anim, forKey: "opacity")
    } else {
        if view.alpha == 0.0 || view.isHidden { return }
        let from = view.alpha
        view.alpha = 0.0
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = from
        anim.toValue = 0.0
        anim.duration = 0.12
        view.layer.add(anim, forKey: "opacity")
        // Don't set isHidden so the animation can run; UIKit treats alpha==0 + hitTest as non-blocking.
    }
}

private func applyTableReveal(tableView: InstantPageV2TableView, start: Int, end: Int,
                              rows: [InstantPageV2RevealCostMap.TableRow],
                              title: InstantPageV2RevealCostMap?,
                              revealedCount: Int, animated: Bool) {
    let _ = start
    let _ = end

    // Title sub-view, if present, recurses with the title's own sub-map.
    if let title, let titleSub = tableView.titleSubView {
        titleSub.applyReveal(revealedCount: revealedCount, costMap: title, animated: animated)
    }

    // Determine which row index the cursor is currently in (or past).
    // A row is "revealed" once revealedCount >= rowStartCount.
    var lastRevealedRowIndex: Int? = nil
    for (idx, row) in rows.enumerated() {
        if revealedCount >= row.startCount {
            lastRevealedRowIndex = idx
        } else {
            break
        }
    }

    // Recurse into each cell sub-view (each non-nil cell map corresponds to a cellSubView,
    // in the order they were registered when InstantPageV2TableView was constructed:
    // cell-sub-views are added in iteration order of `item.cells` for cells with subLayout).
    var cellSubViewIndex = 0
    for row in rows {
        for cellMap in row.cells {
            if let cellMap, cellSubViewIndex < tableView.cellSubViews.count {
                let cellSubView = tableView.cellSubViews[cellSubViewIndex]
                cellSubView.applyReveal(revealedCount: revealedCount, costMap: cellMap, animated: animated)
                cellSubViewIndex += 1
            }
        }
    }

    // Apply the row-mask on contentView. The mask exposes rows [0 ... lastRevealedRowIndex].
    // Compute the y-bound by taking the max maxY across cells in those rows.
    let gridOffsetY = tableView.item.titleFrame?.height ?? 0.0
    let maskHeight: CGFloat
    if let lastRevealedRowIndex {
        // Find the maxY among cells in rows [0 ... lastRevealedRowIndex]. Use the actual table item's
        // cells (the layout-time data, not the cost-map's logical row groupings).
        let groupedByY = Dictionary(grouping: tableView.item.cells, by: { $0.frame.minY })
        let sortedRowYs = groupedByY.keys.sorted()
        let safeIndex = min(lastRevealedRowIndex, sortedRowYs.count - 1)
        let rowY = sortedRowYs[safeIndex]
        let cellsInRow = groupedByY[rowY] ?? []
        let rowMaxY = cellsInRow.map { $0.frame.maxY }.max() ?? 0.0
        maskHeight = gridOffsetY + rowMaxY
    } else {
        // No rows revealed yet — but the title (if any) is still visible above the grid.
        maskHeight = (title != nil) ? gridOffsetY : 0.0
    }

    let maskFrame = CGRect(x: 0.0, y: 0.0, width: tableView.contentView.bounds.width, height: maskHeight)

    let maskLayer: CALayer
    if let existing = tableView.contentView.layer.mask {
        maskLayer = existing
    } else {
        let new = CALayer()
        new.backgroundColor = UIColor.white.cgColor
        tableView.contentView.layer.mask = new
        maskLayer = new
    }

    if animated && maskLayer.frame != maskFrame {
        let anim = CABasicAnimation(keyPath: "bounds")
        anim.fromValue = maskLayer.bounds
        anim.toValue = CGRect(origin: .zero, size: maskFrame.size)
        anim.duration = 0.12
        maskLayer.add(anim, forKey: "bounds")
    }
    maskLayer.frame = maskFrame
}

private func clearRevealOn(view: InstantPageItemView, animated: Bool) {
    if let textView = view as? InstantPageV2TextView {
        textView.updateRevealCharacterCount(value: nil, animated: animated)
    }
    if let codeView = view as? InstantPageV2CodeBlockView {
        codeView.textView.updateRevealCharacterCount(value: nil, animated: animated)
        applyVisibility(view: codeView, visible: true, animated: animated)
    }
    if let detailsView = view as? InstantPageV2DetailsView {
        detailsView.titleTextView.updateRevealCharacterCount(value: nil, animated: animated)
        detailsView.bodyView?.applyReveal(revealedCount: nil, costMap: nil, animated: animated)
    }
    if let tableView = view as? InstantPageV2TableView {
        tableView.titleSubView?.applyReveal(revealedCount: nil, costMap: nil, animated: animated)
        for cell in tableView.cellSubViews {
            cell.applyReveal(revealedCount: nil, costMap: nil, animated: animated)
        }
        tableView.contentView.layer.mask = nil
    }
    // Non-text item: ensure visible.
    applyVisibility(view: view, visible: true, animated: animated)
}
