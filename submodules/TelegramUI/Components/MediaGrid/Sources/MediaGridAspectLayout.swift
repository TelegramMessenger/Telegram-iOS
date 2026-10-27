import Foundation
import CoreGraphics

public struct MediaGridAspectLayout: MediaGridLayout {
    public let geometry: MediaGridGeometry
    public let count: Int
    public let contentHeight: CGFloat
    public let estimatedAspect: CGFloat
    public let hasExactAspects: Bool

    private let contentWidth: CGFloat
    private let aspects: [Float]
    private let estimatedHeightPixels: Int
    private let spacingPixels: Int
    private let offsets: [Double]?

    public init(geometry: MediaGridGeometry, count: Int, aspects: [Float]?, estimatedAspect: CGFloat = 0.75) {
        self.geometry = geometry
        self.count = max(0, count)
        self.estimatedAspect = MediaGridAspectIndex.clamp(estimatedAspect)
        self.hasExactAspects = aspects != nil
        self.aspects = aspects ?? []
        let contentWidth = max(0.0, geometry.width - 2.0 * geometry.sideInset)
        self.contentWidth = contentWidth
        let scale = max(1.0, geometry.scale)
        self.estimatedHeightPixels = MediaGridAspectLayout.heightPixels(width: contentWidth, aspect: self.estimatedAspect, scale: scale)
        self.spacingPixels = Int((geometry.spacing * scale).rounded())

        var totalPixels = 0
        if let aspects, self.count > 0 {
            var offsets = [Double](repeating: 0.0, count: self.count + 1)
            var pixels = 0
            for index in 0 ..< self.count {
                offsets[index] = Double(geometry.topInset) + Double(pixels) / Double(scale)
                let aspect = index < aspects.count ? MediaGridAspectIndex.clamp(CGFloat(aspects[index])) : self.estimatedAspect
                pixels += MediaGridAspectLayout.heightPixels(width: contentWidth, aspect: aspect, scale: scale) + self.spacingPixels
            }
            offsets[self.count] = Double(geometry.topInset) + Double(pixels) / Double(scale)
            self.offsets = offsets
            totalPixels = pixels - self.spacingPixels
        } else {
            self.offsets = nil
            if self.count > 0 {
                totalPixels = self.count * (self.estimatedHeightPixels + self.spacingPixels) - self.spacingPixels
            }
        }
        self.contentHeight = geometry.topInset + geometry.bottomInset + CGFloat(totalPixels) / scale
    }

    private static func heightPixels(width: CGFloat, aspect: CGFloat, scale: CGFloat) -> Int {
        return max(1, Int(floor(width / aspect * scale)))
    }

    private var scale: CGFloat {
        return max(1.0, self.geometry.scale)
    }

    private func heightPixels(at index: Int) -> Int {
        guard index < self.aspects.count else {
            return self.estimatedHeightPixels
        }
        return MediaGridAspectLayout.heightPixels(width: self.contentWidth, aspect: MediaGridAspectIndex.clamp(CGFloat(self.aspects[index])), scale: self.scale)
    }

    private func minY(at index: Int) -> CGFloat {
        if let offsets = self.offsets {
            return CGFloat(offsets[index])
        }
        return self.geometry.topInset + CGFloat(index * (self.estimatedHeightPixels + self.spacingPixels)) / self.scale
    }

    private func maxY(at index: Int) -> CGFloat {
        return self.minY(at: index) + CGFloat(self.heightPixels(at: index)) / self.scale
    }

    public func frame(at index: Int) -> CGRect {
        return CGRect(x: self.geometry.sideInset, y: self.minY(at: index), width: self.contentWidth, height: CGFloat(self.heightPixels(at: index)) / self.scale)
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
        return CGSize(width: ceil(self.contentWidth * self.scale), height: CGFloat(self.heightPixels(at: index)))
    }
}
