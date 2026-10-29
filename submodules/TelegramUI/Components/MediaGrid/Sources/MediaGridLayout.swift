import Foundation
import CoreGraphics

public struct MediaGridGeometry: Equatable {
    public var width: CGFloat
    // The two sides differ on iPhone Duo, whose side strip is on one side only.
    public var leftInset: CGFloat
    public var rightInset: CGFloat
    public var topInset: CGFloat
    public var bottomInset: CGFloat
    public var spacing: CGFloat
    public var scale: CGFloat

    public init(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, topInset: CGFloat, bottomInset: CGFloat, spacing: CGFloat, scale: CGFloat) {
        self.width = width
        self.leftInset = leftInset
        self.rightInset = rightInset
        self.topInset = topInset
        self.bottomInset = bottomInset
        self.spacing = spacing
        self.scale = scale
    }

    public init(width: CGFloat, sideInset: CGFloat, topInset: CGFloat, bottomInset: CGFloat, spacing: CGFloat, scale: CGFloat) {
        self.init(width: width, leftInset: sideInset, rightInset: sideInset, topInset: topInset, bottomInset: bottomInset, spacing: spacing, scale: scale)
    }

    public var contentWidth: CGFloat {
        return self.width - (self.leftInset + self.rightInset)
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
