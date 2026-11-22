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
    private let columnOriginPixels: Int
    private let columnSpanPixels: Int
    private let spacingPixels: Int
    private let maxColumnPixelWidth: Int

    public init(geometry: MediaGridGeometry, columns: Int, cellAspect: CGFloat, reservedSlots: Set<MediaGridSlot>, count: Int) {
        self.geometry = geometry
        self.columns = columns
        self.count = count

        let contentWidth = geometry.contentWidth
        let width = floor((contentWidth - geometry.spacing * CGFloat(columns - 1)) / CGFloat(columns) * geometry.scale) / geometry.scale
        let height = floor(width * cellAspect * geometry.scale) / geometry.scale
        self.itemSize = CGSize(width: width, height: height)

        let originPixels = Int((geometry.leftInset * geometry.scale).rounded())
        let spanPixels = max(0, Int(((contentWidth + geometry.spacing) * geometry.scale).rounded()))
        let spacingPixels = Int((geometry.spacing * geometry.scale).rounded())
        self.columnOriginPixels = originPixels
        self.columnSpanPixels = spanPixels
        self.spacingPixels = spacingPixels
        var maxColumnPixelWidth = 0
        for column in 0 ..< max(0, columns) {
            maxColumnPixelWidth = max(maxColumnPixelWidth, MediaGridUniformLayout.columnStart(column + 1, span: spanPixels, columns: columns) - MediaGridUniformLayout.columnStart(column, span: spanPixels, columns: columns) - spacingPixels)
        }
        self.maxColumnPixelWidth = maxColumnPixelWidth

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

    private static func columnStart(_ column: Int, span: Int, columns: Int) -> Int {
        guard columns > 0 else {
            return 0
        }
        return (column * span + columns / 2) / columns
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
        let start = MediaGridUniformLayout.columnStart(column, span: self.columnSpanPixels, columns: self.columns)
        let end = MediaGridUniformLayout.columnStart(column + 1, span: self.columnSpanPixels, columns: self.columns)
        let x = CGFloat(self.columnOriginPixels + start) / geometry.scale
        let width = CGFloat(max(0, end - start - self.spacingPixels)) / geometry.scale
        let y = geometry.topInset + CGFloat(row) * (self.itemSize.height + geometry.spacing)
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
        if self.count == 0 || self.rowCount == 0 || rect.height <= 0 || !rect.minY.isFinite || !rect.maxY.isFinite {
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
        return CGSize(width: CGFloat(self.maxColumnPixelWidth), height: ceil(self.itemSize.height * self.geometry.scale))
    }

    public func index(at point: CGPoint) -> Int? {
        guard point.x.isFinite, point.y.isFinite, self.columns > 0, self.columnSpanPixels > 0 else {
            return nil
        }
        let dx = point.x - self.geometry.leftInset
        let dy = point.y - self.geometry.topInset
        if dx < 0 || dy < 0 || self.rowCount == 0 {
            return nil
        }
        let rowValue = floor(dy / (self.itemSize.height + self.geometry.spacing))
        if rowValue >= CGFloat(self.rowCount) {
            return nil
        }
        let row = Int(rowValue)
        let estimate = min(self.columns - 1, Int(floor(dx * self.geometry.scale * CGFloat(self.columns) / CGFloat(self.columnSpanPixels))))
        guard let column = (max(0, estimate - 1) ... min(self.columns - 1, estimate + 1)).first(where: { self.slotFrame(row: row, column: $0).contains(point) }) else {
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
