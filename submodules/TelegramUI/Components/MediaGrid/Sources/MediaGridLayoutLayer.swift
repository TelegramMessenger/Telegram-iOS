import Foundation
import UIKit
import QuartzCore

final class MediaGridLayoutLayer: CALayer {
    private let dataSource: MediaGridDataSource
    private let pool: MediaGridCellPool

    private(set) var layout: MediaGridLayout?
    private(set) var detail: MediaGridCellDetail = .full
    private(set) var visibleCells: [Int: MediaGridCellLayer] = [:]
    var isItemSelected: ((Int) -> Bool)?
    var suspendsSharpRequests = false
    weak var donor: MediaGridLayoutLayer?
    private(set) var visibleRange: Range<Int> = 0 ..< 0
    private var needsRebind = false
    private var staleIndices = Set<Int>()
    private var changedIndices = Set<Int>()
    static let thumbnailSufficiency: CGFloat = 1.25

    init(dataSource: MediaGridDataSource, pool: MediaGridCellPool) {
        self.dataSource = dataSource
        self.pool = pool
        super.init()
    }

    override init(layer: Any) {
        let other = layer as! MediaGridLayoutLayer
        self.dataSource = other.dataSource
        self.pool = other.pool
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func action(forKey event: String) -> CAAction? {
        return NSNull()
    }

    func setLayout(_ layout: MediaGridLayout, detail: MediaGridCellDetail) {
        if detail != self.detail {
            self.needsRebind = true
        } else if !self.needsRebind, let previous = self.layout {
            for index in self.visibleCells.keys where index < layout.count && index < previous.count {
                if previous.pixelSize(at: index) != layout.pixelSize(at: index) {
                    self.staleIndices.insert(index)
                }
            }
        }
        self.layout = layout
        self.detail = detail
        let kept = self.visibleRange.clamped(to: 0 ..< layout.count)
        if kept != self.visibleRange {
            for index in self.visibleCells.keys where !kept.contains(index) {
                if let cell = self.visibleCells.removeValue(forKey: index) {
                    self.pool.enqueue(cell)
                }
            }
            self.visibleRange = kept.isEmpty ? 0 ..< 0 : kept
        }
        for (index, cell) in self.visibleCells {
            cell.frame = layout.frame(at: index)
        }
    }

    func apply(_ changes: MediaGridChanges, layout: MediaGridLayout) {
        let previous = self.layout
        var cells: [Int: MediaGridCellLayer] = [:]
        var stale = Set<Int>()
        var changed = Set<Int>()
        for (index, cell) in self.visibleCells {
            guard let newIndex = changes.newIndex(forOld: index), newIndex < layout.count else {
                self.pool.enqueue(cell)
                continue
            }
            cells[newIndex] = cell
            let resized = previous.map { index < $0.count && $0.pixelSize(at: index) != layout.pixelSize(at: newIndex) } ?? true
            if changes.changed.contains(newIndex) || resized || self.staleIndices.contains(index) {
                stale.insert(newIndex)
                if changes.changed.contains(newIndex) || self.changedIndices.contains(index) {
                    changed.insert(newIndex)
                }
            } else if newIndex != index {
                cell.bind(index: newIndex, detail: self.detail)
                cell.setSelected(self.detail == .full ? (self.isItemSelected?(newIndex) ?? false) : false)
            }
        }
        self.layout = layout
        self.visibleCells = cells
        if let lower = cells.keys.min(), let upper = cells.keys.max() {
            self.visibleRange = lower ..< upper + 1
            for index in self.visibleRange where cells[index] == nil {
                stale.insert(index)
            }
        } else {
            self.visibleRange = 0 ..< 0
        }
        self.staleIndices = stale
        self.changedIndices = changed
        for (index, cell) in cells {
            cell.frame = layout.frame(at: index)
        }
    }

    func refreshSelection() {
        guard self.detail == .full else {
            return
        }
        for (index, cell) in self.visibleCells {
            cell.setSelected(self.isItemSelected?(index) ?? false)
        }
    }

    func removeAllCells() {
        for (_, cell) in self.visibleCells {
            self.pool.enqueue(cell)
        }
        self.visibleCells.removeAll()
        self.visibleRange = 0 ..< 0
        self.needsRebind = false
        self.staleIndices.removeAll()
        self.changedIndices.removeAll()
    }

    private func remove(_ lower: Int, _ upper: Int) {
        guard lower < upper else {
            return
        }
        for index in lower ..< upper {
            if let cell = self.visibleCells.removeValue(forKey: index) {
                self.pool.enqueue(cell)
            }
        }
    }

    private func add(_ lower: Int, _ upper: Int, layout: MediaGridLayout, priority: Range<Int>) {
        guard lower < upper else {
            return
        }
        let range = lower ..< upper
        let first = range.clamped(to: priority)
        if first.isEmpty {
            for index in range {
                self.add(index, layout: layout)
            }
            return
        }
        for index in lower ..< first.lowerBound {
            self.add(index, layout: layout)
        }
        for index in (first.upperBound ..< upper).reversed() {
            self.add(index, layout: layout)
        }
        for index in first.reversed() {
            self.add(index, layout: layout)
        }
    }

    private func add(_ index: Int, layout: MediaGridLayout) {
        let cell = self.pool.dequeue()
        if cell.superlayer !== self {
            self.addSublayer(cell)
        }
        self.bind(cell, index: index, layout: layout)
        self.visibleCells[index] = cell
    }

    func updateVisibleRange(_ range: Range<Int>, priority: Range<Int> = 0 ..< 0) {
        guard let layout = self.layout else {
            return
        }
        let range = range.clamped(to: 0 ..< layout.count)
        let old = self.visibleRange
        if range == old && !self.needsRebind && self.staleIndices.isEmpty {
            return
        }
        if old.overlaps(range) {
            self.remove(old.lowerBound, range.lowerBound)
            self.remove(range.upperBound, old.upperBound)
            if self.needsRebind || !self.staleIndices.isEmpty {
                for index in range.clamped(to: old) where self.needsRebind || self.staleIndices.contains(index) {
                    if let cell = self.visibleCells[index] {
                        cell.imageRequest?.cancel()
                        cell.imageRequest = nil
                        self.bind(cell, index: index, layout: layout, keepsImage: !self.changedIndices.contains(index))
                    } else {
                        self.add(index, layout: layout)
                    }
                }
            }
            self.add(range.lowerBound, old.lowerBound, layout: layout, priority: priority)
            self.add(old.upperBound, range.upperBound, layout: layout, priority: priority)
        } else {
            self.remove(old.lowerBound, old.upperBound)
            self.add(range.lowerBound, range.upperBound, layout: layout, priority: priority)
        }
        self.needsRebind = false
        self.staleIndices.removeAll()
        self.changedIndices.removeAll()
        self.visibleRange = range
    }

    func requestSharpImages(prioritizing priority: Range<Int>) {
        guard let layout = self.layout else {
            return
        }
        let pending = self.visibleCells.filter { $0.value.isAwaitingSharpImage && !$0.value.hasFinalImage }
        let ordered = pending.keys.sorted { lhs, rhs in
            let lhsPriority = priority.contains(lhs)
            let rhsPriority = priority.contains(rhs)
            if lhsPriority != rhsPriority {
                return !lhsPriority
            }
            return lhsPriority ? lhs > rhs : lhs < rhs
        }
        for index in ordered {
            guard let cell = pending[index], index < layout.count else {
                continue
            }
            cell.isAwaitingSharpImage = false
            self.requestImage(for: cell, index: index)
        }
    }

    func refreshThumbnails(indices: IndexSet?) {
        guard let layout = self.layout, !self.visibleCells.isEmpty else {
            return
        }
        if let indices {
            for range in indices.rangeView {
                for index in range.clamped(to: self.visibleRange) {
                    if let cell = self.visibleCells[index] {
                        self.refreshThumbnail(cell, index: index, layout: layout)
                    }
                }
            }
        } else {
            for (index, cell) in self.visibleCells {
                self.refreshThumbnail(cell, index: index, layout: layout)
            }
        }
    }

    private func refreshThumbnail(_ cell: MediaGridCellLayer, index: Int, layout: MediaGridLayout) {
        guard index < layout.count, cell.contents == nil || cell.isShowingThumbnail, let thumbnail = self.dataSource.thumbnail(at: index) else {
            return
        }
        let aspect = MediaGridLayoutLayer.aspect(of: cell.frame)
        if cell.contents != nil && thumbnail.contentsRect(fillingAspect: aspect).width * CGFloat(thumbnail.image.width) < cell.shownPixelWidth {
            return
        }
        cell.setThumbnail(thumbnail, cellAspect: aspect)
        if !cell.hasFinalImage, !self.wantsSharpImage(cell, index: index, layout: layout) {
            cell.isAwaitingSharpImage = false
            if let request = cell.imageRequest {
                cell.imageRequest = nil
                cell.bindingToken += 1
                request.cancel()
            }
        }
    }

    private static func aspect(of frame: CGRect) -> CGFloat {
        return frame.height > 0.0 ? frame.width / frame.height : 1.0
    }

    private func wantsSharpImage(_ cell: MediaGridCellLayer, index: Int, layout: MediaGridLayout) -> Bool {
        guard cell.contents != nil else {
            return true
        }
        let pixelSize = layout.pixelSize(at: index)
        if cell.isShowingThumbnail {
            if self.detail == .compact {
                return false
            }
            return max(pixelSize.width, pixelSize.height) > MediaGridLayoutLayer.thumbnailSufficiency * cell.thumbnailPixelSize
        }
        return cell.shownPixelWidth < pixelSize.width
    }

    private func bind(_ cell: MediaGridCellLayer, index: Int, layout: MediaGridLayout, keepsImage: Bool = false) {
        cell.bind(index: index, detail: self.detail)
        cell.setSelected(self.detail == .full ? (self.isItemSelected?(index) ?? false) : false)
        cell.frame = layout.frame(at: index)
        cell.hasFinalImage = false
        cell.isAwaitingSharpImage = false
        cell.bindingToken += 1
        let showsSharpImage = cell.sharpImage != nil
        var showsStaleImage = false
        if !(keepsImage && showsSharpImage) {
            if let thumbnail = self.dataSource.thumbnail(at: index) {
                cell.setThumbnail(thumbnail, cellAspect: MediaGridLayoutLayer.aspect(of: cell.frame))
            } else {
                showsStaleImage = showsSharpImage
            }
        }
        if let donorCell = self.donor?.visibleCells[index], donorCell !== cell, let image = donorCell.sharpImage {
            cell.setImage(image)
        }
        guard showsStaleImage || self.wantsSharpImage(cell, index: index, layout: layout) else {
            return
        }
        if self.suspendsSharpRequests {
            cell.isAwaitingSharpImage = true
        } else {
            self.requestImage(for: cell, index: index)
        }
    }

    private func requestImage(for cell: MediaGridCellLayer, index: Int) {
        guard let layout = self.layout else {
            return
        }
        cell.bindingToken += 1
        let token = cell.bindingToken
        let apply: (MediaGridCellLayer?, UIImage?, Bool) -> Void = { cell, image, isDegraded in
            guard let cell, cell.bindingToken == token else {
                return
            }
            if isDegraded && cell.hasFinalImage {
                return
            }
            if image == nil && !isDegraded {
                return
            }
            if image == nil && cell.contents != nil {
                return
            }
            if !isDegraded {
                cell.hasFinalImage = true
            }
            cell.setImage(image)
        }
        let request = self.dataSource.requestImage(at: index, pixelSize: layout.pixelSize(at: index), completion: { [weak cell] image, isDegraded in
            if Thread.isMainThread {
                apply(cell, image, isDegraded)
            } else {
                DispatchQueue.main.async {
                    apply(cell, image, isDegraded)
                }
            }
        })
        if cell.bindingToken == token {
            cell.imageRequest = request
        } else {
            request?.cancel()
        }
    }
}
