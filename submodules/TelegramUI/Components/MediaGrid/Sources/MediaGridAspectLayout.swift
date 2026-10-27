import Foundation
import CoreGraphics

public final class MediaGridAspectTable {
    public struct Key: Hashable {
        public var contentWidth: CGFloat
        public var scale: CGFloat
        public var spacing: CGFloat

        public init(geometry: MediaGridGeometry) {
            self.contentWidth = max(0.0, geometry.width - 2.0 * geometry.sideInset)
            self.scale = max(1.0, geometry.scale)
            self.spacing = geometry.spacing
        }

        var widthPixels: CGFloat {
            return self.contentWidth * self.scale
        }

        var spacingPixels: Int {
            return Int((self.spacing * self.scale).rounded())
        }

        func heightPixels(aspect: CGFloat) -> Int {
            return max(1, Int(floor(self.contentWidth / aspect * self.scale)))
        }
    }

    public let key: Key
    public let count: Int
    let pixelOffsets: [Int]

    public init(key: Key, aspects: [Float]) {
        self.key = key
        self.count = aspects.count
        let spacing = key.spacingPixels
        var offsets = [Int](repeating: 0, count: aspects.count + 1)
        var pixels = 0
        for index in 0 ..< aspects.count {
            offsets[index] = pixels
            pixels += key.heightPixels(aspect: MediaGridAspectIndex.clamp(CGFloat(aspects[index]))) + spacing
        }
        offsets[aspects.count] = pixels
        self.pixelOffsets = offsets
    }
}

public struct MediaGridAspectLayout: MediaGridLayout {
    public let geometry: MediaGridGeometry
    public let count: Int
    public let contentHeight: CGFloat
    public let estimatedAspect: CGFloat
    public let isExact: Bool

    private let key: MediaGridAspectTable.Key
    private let table: MediaGridAspectTable?
    private let ratio: Double
    private let estimatedHeightPixels: Int
    private let spacingPixels: Int

    public init(geometry: MediaGridGeometry, count: Int, aspects: [Float]?, estimatedAspect: CGFloat = 0.75) {
        self.init(geometry: geometry, count: count, table: aspects.map { MediaGridAspectTable(key: MediaGridAspectTable.Key(geometry: geometry), aspects: $0) }, estimatedAspect: estimatedAspect)
    }

    public init(geometry: MediaGridGeometry, count: Int, table: MediaGridAspectTable?, estimatedAspect: CGFloat = 0.75) {
        self.geometry = geometry
        self.count = max(0, count)
        self.estimatedAspect = MediaGridAspectIndex.clamp(estimatedAspect)
        let key = MediaGridAspectTable.Key(geometry: geometry)
        self.key = key
        self.estimatedHeightPixels = key.heightPixels(aspect: self.estimatedAspect)
        self.spacingPixels = key.spacingPixels
        if let table, table.key.scale == key.scale, table.key.spacing == key.spacing, table.key.widthPixels > 0.0 {
            self.table = table
            self.ratio = table.key == key ? 1.0 : Double(key.widthPixels / table.key.widthPixels)
            self.isExact = table.key == key
        } else {
            self.table = nil
            self.ratio = 1.0
            self.isExact = false
        }
        var contentHeight = geometry.topInset + geometry.bottomInset
        if self.count > 0 {
            contentHeight += CGFloat(MediaGridAspectLayout.pixels(self.count, table: self.table, ratio: self.ratio, spacing: self.spacingPixels, estimated: self.estimatedHeightPixels) - self.spacingPixels) / key.scale
        }
        self.contentHeight = contentHeight
    }

    private static func pixels(_ index: Int, table: MediaGridAspectTable?, ratio: Double, spacing: Int, estimated: Int) -> Int {
        guard let table else {
            return index * (estimated + spacing)
        }
        let rows = min(index, table.count)
        var result = table.pixelOffsets[rows]
        if ratio != 1.0 {
            result = Int((Double(result - rows * spacing) * ratio).rounded()) + rows * spacing
        }
        if index > rows {
            result += (index - rows) * (estimated + spacing)
        }
        return result
    }

    private func pixels(_ index: Int) -> Int {
        return MediaGridAspectLayout.pixels(index, table: self.table, ratio: self.ratio, spacing: self.spacingPixels, estimated: self.estimatedHeightPixels)
    }

    private func heightPixels(at index: Int) -> Int {
        return max(1, self.pixels(index + 1) - self.pixels(index) - self.spacingPixels)
    }

    private func minY(at index: Int) -> CGFloat {
        return self.geometry.topInset + CGFloat(self.pixels(index)) / self.key.scale
    }

    private func maxY(at index: Int) -> CGFloat {
        return self.minY(at: index) + CGFloat(self.heightPixels(at: index)) / self.key.scale
    }

    public func frame(at index: Int) -> CGRect {
        return CGRect(x: self.geometry.sideInset, y: self.minY(at: index), width: self.key.contentWidth, height: CGFloat(self.heightPixels(at: index)) / self.key.scale)
    }

    private func firstIndex(where predicate: (Int) -> Bool) -> Int {
        var low = 0
        var high = self.count
        while low < high {
            let mid = (low + high) / 2
            if predicate(mid) {
                high = mid
            } else {
                low = mid + 1
            }
        }
        return low
    }

    public func indexRange(intersecting rect: CGRect) -> Range<Int> {
        if self.count == 0 || rect.height <= 0.0 || !rect.minY.isFinite || !rect.maxY.isFinite {
            return 0 ..< 0
        }
        let lower = self.firstIndex(where: { self.maxY(at: $0) > rect.minY })
        let upper = self.firstIndex(where: { self.minY(at: $0) >= rect.maxY })
        return lower ..< max(lower, upper)
    }

    public func index(at point: CGPoint) -> Int? {
        guard self.count > 0, point.y.isFinite else {
            return nil
        }
        let index = self.firstIndex(where: { self.maxY(at: $0) > point.y })
        guard index < self.count, self.frame(at: index).contains(point) else {
            return nil
        }
        return index
    }

    public func pixelSize(at index: Int) -> CGSize {
        return CGSize(width: ceil(self.key.widthPixels), height: CGFloat(self.heightPixels(at: index)))
    }

    var tableKey: MediaGridAspectTable.Key {
        return self.key
    }
}
