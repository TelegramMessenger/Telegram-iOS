import Foundation
import QuartzCore

final class MediaGridCellPool {
    private let factory: () -> MediaGridCellLayer
    private var cells: [MediaGridCellLayer] = []
    private var visibleCount = 0

    init(factory: @escaping () -> MediaGridCellLayer) {
        self.factory = factory
    }

    var count: Int {
        return self.cells.count
    }

    func dequeue() -> MediaGridCellLayer {
        if let cell = self.cells.popLast() {
            cell.isHidden = false
            return cell
        }
        return self.factory()
    }

    func enqueue(_ cell: MediaGridCellLayer) {
        cell.resetBinding()
        cell.prepareForReuse()
        cell.clearImage()
        if self.cells.count >= 2 * self.visibleCount {
            cell.removeFromSuperlayer()
            return
        }
        cell.isHidden = true
        self.cells.append(cell)
    }

    func setVisibleCount(_ count: Int) {
        self.visibleCount = count
        let limit = 2 * count
        while self.cells.count > limit {
            self.cells.removeLast().removeFromSuperlayer()
        }
    }
}
