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
    private var visibleRange: Range<Int> = 0 ..< 0

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
            self.removeAllCells()
            return
        }
        for (index, cell) in self.visibleCells {
            if index < layout.count {
                cell.frame = layout.frame(at: index)
            } else {
                self.visibleCells.removeValue(forKey: index)
                self.pool.enqueue(cell)
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

    func reloadCells() {
        self.removeAllCells()
    }

    func removeAllCells() {
        for (_, cell) in self.visibleCells {
            self.pool.enqueue(cell)
        }
        self.visibleCells.removeAll()
        self.visibleRange = 0 ..< 0
    }

    func updateVisibleRange(_ range: Range<Int>) {
        guard let layout = self.layout else {
            return
        }
        let range = range.clamped(to: 0 ..< layout.count)
        if range == self.visibleRange && self.visibleCells.count == range.count {
            return
        }
        for (index, cell) in self.visibleCells where !range.contains(index) {
            self.visibleCells.removeValue(forKey: index)
            self.pool.enqueue(cell)
        }
        for index in range where self.visibleCells[index] == nil {
            let cell = self.pool.dequeue()
            if cell.superlayer !== self {
                self.addSublayer(cell)
            }
            self.bind(cell, index: index, layout: layout)
            self.visibleCells[index] = cell
        }
        self.visibleRange = range
        self.pool.noteVisibleCount(self.visibleCells.count)
    }

    private func bind(_ cell: MediaGridCellLayer, index: Int, layout: MediaGridLayout) {
        cell.bind(index: index, detail: self.detail)
        cell.setSelected(self.detail == .full ? (self.isItemSelected?(index) ?? false) : false)
        cell.frame = layout.frame(at: index)
        cell.bindingToken += 1
        cell.hasFinalImage = false
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
            if !isDegraded {
                cell.hasFinalImage = true
            }
            cell.setImage(image)
        }
        let request = self.dataSource.requestImage(at: index, pixelSize: self.pixelSize, completion: { [weak cell] image, isDegraded in
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
