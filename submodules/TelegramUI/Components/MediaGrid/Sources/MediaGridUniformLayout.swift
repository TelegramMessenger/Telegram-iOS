import Foundation
import CoreGraphics

public struct MediaGridUniformLayout: MediaGridLayout {
    public let geometry: MediaGridGeometry
    public let columns: Int
    public let count: Int
    public let itemSize: CGSize
    public let contentHeight: CGFloat

    private let reservedNumbers: [Int]
    private let rowCount: Int

    public init(geometry: MediaGridGeometry, columns: Int, cellAspect: CGFloat, reservedSlots: Set<MediaGridSlot>, count: Int) {
        self.geometry = geometry
        self.columns = columns
        self.count = count

        let contentWidth = geometry.width - 2.0 * geometry.sideInset
        let width = floor((contentWidth - geometry.spacing * CGFloat(columns - 1)) / CGFloat(columns) * geometry.scale) / geometry.scale
        let height = floor(width * cellAspect * geometry.scale) / geometry.scale
        self.itemSize = CGSize(width: width, height: height)

        let numbers = reservedSlots.map { $0.row * columns + $0.column }.sorted()
        self.reservedNumbers = numbers

        var slotCount = 0
        if count > 0 {
            slotCount = MediaGridUniformLayout.slotNumber(forIndex: count - 1, reserved: numbers) + 1
        }
        if let last = numbers.last {
            slotCount = max(slotCount, last + 1)
        }
        let rows = (slotCount + columns - 1) / columns
        self.rowCount = rows
        var total = geometry.topInset + geometry.bottomInset
        if rows > 0 {
            total += CGFloat(rows) * height + CGFloat(rows - 1) * geometry.spacing
        }
        self.contentHeight = total
    }

    private static func slotNumber(forIndex index: Int, reserved: [Int]) -> Int {
        var slot = index
        for number in reserved {
            if number <= slot {
                slot += 1
            } else {
                break
            }
        }
        return slot
    }

    private func reservedCount(below slot: Int) -> Int {
        var low = 0
        var high = self.reservedNumbers.count
        while low < high {
            let mid = (low + high) / 2
            if self.reservedNumbers[mid] < slot {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }

    private func slotFrame(row: Int, column: Int) -> CGRect {
        let geometry = self.geometry
        let x = geometry.sideInset + CGFloat(column) * (self.itemSize.width + geometry.spacing)
        let y = geometry.topInset + CGFloat(row) * (self.itemSize.height + geometry.spacing)
        var width = self.itemSize.width
        if column == self.columns - 1 {
            width = geometry.width - geometry.sideInset - x
        }
        return CGRect(x: x, y: y, width: width, height: self.itemSize.height)
    }

    public func reservedFrame(_ slots: Set<MediaGridSlot>) -> CGRect? {
        var result: CGRect?
        for slot in slots {
            let frame = self.slotFrame(row: slot.row, column: slot.column)
            result = result.map { $0.union(frame) } ?? frame
        }
        return result
    }

    public func frame(at index: Int) -> CGRect {
        let slot = MediaGridUniformLayout.slotNumber(forIndex: index, reserved: self.reservedNumbers)
        return self.slotFrame(row: slot / self.columns, column: slot % self.columns)
    }

    public func indexRange(intersecting rect: CGRect) -> Range<Int> {
        if self.count == 0 || self.rowCount == 0 || rect.height <= 0 {
            return 0 ..< 0
        }
        let pitch = self.itemSize.height + self.geometry.spacing
        let firstRow = max(0, Int(floor((rect.minY - self.geometry.topInset - self.itemSize.height) / pitch)) + 1)
        let lastRow = min(self.rowCount - 1, Int(ceil((rect.maxY - self.geometry.topInset) / pitch)) - 1)
        if firstRow > lastRow {
            return 0 ..< 0
        }
        let firstSlot = firstRow * self.columns
        let endSlot = (lastRow + 1) * self.columns
        let lower = min(self.count, max(0, firstSlot - self.reservedCount(below: firstSlot)))
        let upper = min(self.count, max(0, endSlot - self.reservedCount(below: endSlot)))
        return lower ..< max(lower, upper)
    }

    public func pixelSize(at index: Int) -> CGSize {
        return CGSize(width: ceil(self.itemSize.width * self.geometry.scale), height: ceil(self.itemSize.height * self.geometry.scale))
    }

    public func index(at point: CGPoint) -> Int? {
        let dx = point.x - self.geometry.sideInset
        let dy = point.y - self.geometry.topInset
        if dx < 0 || dy < 0 || self.rowCount == 0 {
            return nil
        }
        let row = Int(floor(dy / (self.itemSize.height + self.geometry.spacing)))
        let column = min(self.columns - 1, Int(floor(dx / (self.itemSize.width + self.geometry.spacing))))
        if row >= self.rowCount {
            return nil
        }
        if !self.slotFrame(row: row, column: column).contains(point) {
            return nil
        }
        let slot = row * self.columns + column
        if self.reservedNumbers.contains(slot) {
            return nil
        }
        let index = slot - self.reservedCount(below: slot)
        return index < self.count ? index : nil
    }
}
