import Foundation
import UIKit
import QuartzCore

final class MediaGridLayoutLayer: CALayer {
    private let dataSource: MediaGridDataSource
    private let pool: MediaGridCellPool

    private(set) var layout: MediaGridLayout?
    private(set) var pixelSize: CGSize = .zero
    private(set) var detail: MediaGridCellDetail = .full
    private(set) var visibleCells: [Int: MediaGridCellLayer] = [:]
    var isItemSelected: ((Int) -> Bool)?
    var quality: MediaGridImageQuality = .full
    private(set) var visibleRange: Range<Int> = 0 ..< 0
    private var needsRebind = false

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

    func setLayout(_ layout: MediaGridLayout, pixelSize: CGSize, detail: MediaGridCellDetail) {
        let rebind = pixelSize != self.pixelSize || detail != self.detail
        self.layout = layout
        self.pixelSize = pixelSize
        self.detail = detail
        if rebind {
            self.needsRebind = true
        }
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

    func refreshSelection() {
        guard self.detail == .full else {
            return
        }
        for (index, cell) in self.visibleCells {
            cell.setSelected(self.isItemSelected?(index) ?? false)
        }
    }

    func reloadCells() {
        self.removeAllCells()
    }

    func removeAllCells() {
        for (_, cell) in self.visibleCells {
            self.pool.enqueue(cell)
        }
        self.visibleCells.removeAll()
        self.visibleRange = 0 ..< 0
        self.needsRebind = false
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
        if range == old && !self.needsRebind {
            return
        }
        if old.overlaps(range) {
            self.remove(old.lowerBound, range.lowerBound)
            self.remove(range.upperBound, old.upperBound)
            if self.needsRebind {
                for index in range.clamped(to: old) {
                    if let cell = self.visibleCells[index] {
                        cell.imageRequest?.cancel()
                        cell.imageRequest = nil
                        self.bind(cell, index: index, layout: layout)
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
        self.visibleRange = range
    }

    func upgradeFastCells(prioritizing priority: Range<Int>) {
        let pending = self.visibleCells.filter { $0.value.requestedQuality == .fast && !$0.value.hasFinalImage }
        let ordered = pending.keys.sorted { lhs, rhs in
            let lhsPriority = priority.contains(lhs)
            let rhsPriority = priority.contains(rhs)
            if lhsPriority != rhsPriority {
                return !lhsPriority
            }
            return lhs < rhs
        }
        for index in ordered {
            guard let cell = pending[index] else {
                continue
            }
            cell.imageRequest?.cancel()
            cell.imageRequest = nil
            self.requestImage(for: cell, index: index, quality: .full)
        }
    }

    private func bind(_ cell: MediaGridCellLayer, index: Int, layout: MediaGridLayout) {
        cell.bind(index: index, detail: self.detail)
        cell.setSelected(self.detail == .full ? (self.isItemSelected?(index) ?? false) : false)
        cell.frame = layout.frame(at: index)
        cell.hasFinalImage = false
        self.requestImage(for: cell, index: index, quality: self.quality)
    }

    private func requestImage(for cell: MediaGridCellLayer, index: Int, quality: MediaGridImageQuality) {
        cell.bindingToken += 1
        cell.requestedQuality = quality
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
        let request = self.dataSource.requestImage(at: index, pixelSize: self.pixelSize, quality: quality, completion: { [weak cell] image, isDegraded in
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
