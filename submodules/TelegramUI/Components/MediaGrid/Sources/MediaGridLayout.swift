import Foundation
import CoreGraphics

public struct MediaGridGeometry: Equatable {
    public var width: CGFloat
    public var sideInset: CGFloat
    public var topInset: CGFloat
    public var bottomInset: CGFloat
    public var spacing: CGFloat
    public var scale: CGFloat

    public init(width: CGFloat, sideInset: CGFloat, topInset: CGFloat, bottomInset: CGFloat, spacing: CGFloat, scale: CGFloat) {
        self.width = width
        self.sideInset = sideInset
        self.topInset = topInset
        self.bottomInset = bottomInset
        self.spacing = spacing
        self.scale = scale
    }
}

public protocol MediaGridLayout {
    var geometry: MediaGridGeometry { get }
    var count: Int { get }
    var contentHeight: CGFloat { get }
    func frame(at index: Int) -> CGRect
    func indexRange(intersecting rect: CGRect) -> Range<Int>
    func index(at point: CGPoint) -> Int?
    func pixelSize(at index: Int) -> CGSize
}

public struct MediaGridSlot: Hashable {
    public var row: Int
    public var column: Int

    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }
}
