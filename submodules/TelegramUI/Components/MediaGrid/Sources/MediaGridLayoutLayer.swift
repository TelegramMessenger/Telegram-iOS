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
    var compactRequestsSharpImages = false
    weak var donor: MediaGridLayoutLayer?
    private(set) var visibleRange: Range<Int> = 0 ..< 0
    private var needsRebind = false
    private var staleIndices = Set<Int>()
    private var changedIndices = Set<Int>()
    private var spareCells: [MediaGridCellLayer] = []
    private var bindingDonor: MediaGridLayoutLayer?
    static let thumbnailSufficiency: CGFloat = 1.25
    static let donorOversize: CGFloat = 2.0

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

    func invalidateImages(_ indices: IndexSet) {
        var invalidated = false
        for index in indices where self.visibleCells[index] != nil {
            self.staleIndices.insert(index)
            self.changedIndices.insert(index)
            invalidated = true
        }
        if invalidated {
            self.dataSource.performBatch {
                self.updateVisibleRange(self.visibleRange)
            }
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
                self.spareCells.append(cell)
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
        let cell: MediaGridCellLayer
        if let spare = self.spareCells.popLast() {
            cell = spare
            cell.resetBinding()
            cell.prepareForReuse()
            self.bind(cell, index: index, layout: layout, reassigned: true)
        } else {
            cell = self.pool.dequeue()
            if cell.superlayer !== self {
                self.addSublayer(cell)
            }
            self.bind(cell, index: index, layout: layout)
        }
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
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.bindingDonor = self.donor
        defer {
            for cell in self.spareCells {
                self.pool.enqueue(cell)
            }
            self.spareCells.removeAll(keepingCapacity: true)
            self.bindingDonor = nil
            CATransaction.commit()
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
        let pending = self.visibleCells.filter { $0.value.isAwaitingSharpImage }
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
        CATransaction.begin()
        CATransaction.setDisableActions(true)
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
        CATransaction.commit()
    }

    private func refreshThumbnail(_ cell: MediaGridCellLayer, index: Int, layout: MediaGridLayout) {
        guard index < layout.count else {
            return
        }
        let frame = layout.frame(at: index)
        if let launchImage = self.launchImage(at: index, pixelSize: layout.pixelSize(at: index)), cell.isImageStale || CGFloat(launchImage.pixelWidth) > cell.shownPixelWidth(in: frame.size) {
            cell.setLaunchImage(launchImage)
        } else {
            guard !cell.hasImage || cell.isShowingThumbnail || cell.isImageStale, let thumbnail = self.dataSource.thumbnail(at: index) else {
                return
            }
            let aspect = MediaGridLayoutLayer.aspect(of: frame)
            if cell.isShowingThumbnail && thumbnail.contentsRect(fillingAspect: aspect).width * CGFloat(thumbnail.image.width) < cell.thumbnailPixelWidth {
                return
            }
            cell.setThumbnail(thumbnail, cellAspect: aspect)
        }
        if !cell.hasFinalImage, !self.wantsSharpImage(cell, size: frame.size, pixelSize: layout.pixelSize(at: index)) {
            cell.isAwaitingSharpImage = false
            if let request = cell.imageRequest {
                cell.imageRequest = nil
                cell.bindingToken += 1
                request.cancel()
            }
        }
    }

    static let launchAspectTolerance: CGFloat = 0.02

    private func launchImage(at index: Int, pixelSize: CGSize) -> MediaGridLaunchImage? {
        guard pixelSize.width > 0.0, pixelSize.height > 0.0, abs(pixelSize.width / pixelSize.height - 1.0) <= MediaGridLayoutLayer.launchAspectTolerance else {
            return nil
        }
        guard let launchImage = self.dataSource.launchImage(at: index), CGFloat(launchImage.pixelWidth) <= MediaGridLayoutLayer.donorOversize * pixelSize.width else {
            return nil
        }
        return launchImage
    }

    private static func aspect(of frame: CGRect) -> CGFloat {
        return frame.height > 0.0 ? frame.width / frame.height : 1.0
    }

    private func wantsSharpImage(_ cell: MediaGridCellLayer, size: CGSize, pixelSize: CGSize) -> Bool {
        if cell.isShowingThumbnail {
            if self.detail == .compact && !self.compactRequestsSharpImages {
                return false
            }
            return max(pixelSize.width, pixelSize.height) > MediaGridLayoutLayer.thumbnailSufficiency * cell.thumbnailPixelSize
        }
        guard cell.sharpImage != nil, !cell.isImageStale else {
            return true
        }
        let shown = cell.shownPixelWidth(in: size)
        return max(shown, cell.launchCoverage) < pixelSize.width || shown > MediaGridLayoutLayer.donorOversize * pixelSize.width
    }

    private func bind(_ cell: MediaGridCellLayer, index: Int, layout: MediaGridLayout, keepsImage: Bool = false, reassigned: Bool = false) {
        let frame = layout.frame(at: index)
        let pixelSize = layout.pixelSize(at: index)
        cell.isBinding = true
        defer {
            cell.isBinding = false
        }
        cell.bind(index: index, detail: self.detail)
        cell.setSelected(self.detail == .full ? (self.isItemSelected?(index) ?? false) : false)
        cell.frame = frame
        cell.isAwaitingSharpImage = false
        cell.bindingToken += 1
        var keeps = false
        if keepsImage, cell.sharpImage != nil {
            keeps = self.detail == .full || cell.shownPixelWidth(in: frame.size) <= MediaGridLayoutLayer.donorOversize * pixelSize.width
        }
        if !keeps {
            cell.hasFinalImage = false
            if let launchImage = self.launchImage(at: index, pixelSize: pixelSize) {
                cell.setLaunchImage(launchImage)
            } else if let thumbnail = self.dataSource.thumbnail(at: index) {
                cell.setThumbnail(thumbnail, cellAspect: MediaGridLayoutLayer.aspect(of: frame))
            } else if reassigned {
                cell.setImage(nil)
            } else if cell.sharpImage != nil && !keepsImage {
                cell.markImageStale()
            }
        }
        if let donorCell = self.bindingDonor?.visibleCells[index], donorCell !== cell, let image = donorCell.sharpImage, MediaGridCellLayer.visiblePixelWidth(of: image, in: frame.size) <= MediaGridLayoutLayer.donorOversize * pixelSize.width, cell.accepts(image, isDegraded: true, in: frame.size, targetPixelWidth: pixelSize.width) {
            cell.setImage(image)
            cell.hasFinalImage = false
        }
        guard self.wantsSharpImage(cell, size: frame.size, pixelSize: pixelSize) else {
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
        cell.imageRequestTime = CACurrentMediaTime()
        let token = cell.bindingToken
        let frame = layout.frame(at: index)
        let targetPixelWidth = layout.pixelSize(at: index).width
        let apply: (MediaGridCellLayer?, UIImage?, Bool) -> Void = { cell, image, isDegraded in
            guard let cell, cell.bindingToken == token, let image else {
                return
            }
            if !isDegraded {
                cell.hasFinalImage = true
            }
            if cell.accepts(image, isDegraded: isDegraded, in: frame.size, targetPixelWidth: targetPixelWidth) {
                cell.setImage(image)
            }
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
