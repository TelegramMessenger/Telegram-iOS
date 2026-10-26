import Foundation
import QuartzCore

final class MediaGridCellPool {
    private let factory: () -> MediaGridCellLayer
    private var cells: [MediaGridCellLayer] = []
    private var largestVisibleCount = 0

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
        cell.prepareForReuse()
        if self.cells.count >= 2 * self.largestVisibleCount {
            cell.removeFromSuperlayer()
            return
        }
        cell.isHidden = true
        self.cells.append(cell)
    }

    func noteVisibleCount(_ count: Int) {
        self.largestVisibleCount = max(self.largestVisibleCount, count)
    }
}
