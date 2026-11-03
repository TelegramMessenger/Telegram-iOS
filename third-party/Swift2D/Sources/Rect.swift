/// The location and dimensions of a rectangle.
public struct Rect: Hashable, Codable, Sendable, CustomStringConvertible {

    public static let zero: Rect = Rect(origin: .zero, size: .zero)
    public static let nan: Rect = Rect(origin: .nan, size: .nan)
    public static let infinite: Rect = Rect(origin: .infinite, size: .infinite)
    public static let null: Rect = Rect(origin: .null, size: .zero)

    /// A point that specifies the coordinates of the rectangle’s origin.
    public let origin: Point
    /// A size that specifies the height and width of the rectangle.
    public let size: Size

    public init(origin: Point = .zero, size: Size = .zero) {
        self.origin = origin
        self.size = size
    }

    public init(x: Double, y: Double, width: Double, height: Double) {
        origin = Point(x: x, y: y)
        size = Size(width: width, height: height)
    }

    public init(x: Float, y: Float, width: Float, height: Float) {
        origin = Point(x: x, y: y)
        size = Size(width: width, height: height)
    }

    public init(x: Int, y: Int, width: Int, height: Int) {
        origin = Point(x: x, y: y)
        size = Size(width: width, height: height)
    }

    public var description: String { "Rect(origin: \(origin), size: \(size))" }
    public var isZero: Bool { self == .zero }
    public var isNaN: Bool { self == .nan }
    public var isInfinite: Bool { self == .infinite }
    public var isNull: Bool { origin == .infinite || origin == .null }
    public var isEmpty: Bool { isNull || width == 0.0 || height == 0.0 }

    /// The x-coordinate of the rectangle origin
    public var x: Double { origin.x }

    /// The y-coordinate of the rectangle origin
    public var y: Double { origin.y }

    /// The width of the rectangle.
    public var width: Double { size.width }

    /// The height of the rectangle.
    public var height: Double { size.height }

    /// The middle of the `Rect` both horizontally and vertically.
    public var center: Point { Point(x: midX, y: midY) }

    /// The smallest value for the x-coordinate of the rectangle.
    public var minX: Double {
        if size.width < 0.0 {
            return origin.x - abs(size.width)
        }

        return origin.x
    }

    /// The x-coordinate that establishes the center of a rectangle.
    public var midX: Double { minX + size.widthRadius }

    /// The largest value of the x-coordinate for the rectangle.
    public var maxX: Double {
        if size.width < 0.0 {
            return origin.x
        }

        return origin.x + size.width
    }

    /// The smallest value for the y-coordinate of the rectangle.
    public var minY: Double {
        if size.height < 0.0 {
            return origin.y - abs(size.height)
        }

        return origin.y
    }

    /// The y-coordinate that establishes the center of the rectangle.
    public var midY: Double { minY + size.heightRadius }

    /// The largest value for the y-coordinate of the rectangle.
    public var maxY: Double {
        if size.height < 0.0 {
            return origin.y
        }

        return origin.y + size.height
    }

    /// Returns a rectangle with a positive width and height.
    public var standardized: Rect {
        guard !isNull else {
            return .null
        }

        return Rect(x: minX, y: minY, width: abs(width), height: abs(height))
    }

    public func origin(_ value: Point) -> Rect {
        Rect(origin: value, size: size)
    }

    public func size(_ value: Size) -> Rect {
        Rect(origin: origin, size: value)
    }

    public func contains(_ point: Point) -> Bool {
        guard !isNull else {
            return false
        }

        guard !isEmpty else {
            return false
        }

        return (minX ..< maxX).contains(point.x) && (minY ..< maxY).contains(point.y)
    }

    public func contains(_ rect: Rect) -> Bool {
        union(rect) == self
    }

    public func intersects(_ rect: Rect) -> Bool {
        !intersection(rect).isNull
    }

    public func intersection(_ rect: Rect) -> Rect {
        guard !isNull else {
            return .null
        }

        guard !rect.isNull else {
            return .null
        }

        let r1 = standardized
        let r1spanH = r1.minX ... r1.maxX
        let r1spanV = r1.minY ... r1.maxY

        let r2 = rect.standardized
        let r2spanH = r2.minX ... r2.maxX
        let r2spanV = r2.minY ... r2.maxY

        guard r1spanH.overlaps(r2spanH), r2spanV.overlaps(r2spanV) else {
            return .null
        }

        let overlapH = r1spanH.clamped(to: r2spanH)
        let width: Double = if overlapH == r1spanH {
            r1.width
        } else if overlapH == r2spanH {
            r2.width
        } else {
            overlapH.upperBound - overlapH.lowerBound
        }

        let overlapV = r1spanV.clamped(to: r2spanV)
        let height: Double = if overlapV == r1spanV {
            r1.height
        } else if overlapV == r2spanV {
            r2.height
        } else {
            overlapV.upperBound - overlapV.lowerBound
        }

        return Rect(x: overlapH.lowerBound, y: overlapV.lowerBound, width: width, height: height)
    }

    public func union(_ rect: Rect) -> Rect {
        guard !isNull else {
            return rect
        }

        guard !rect.isNull else {
            return self
        }

        let r1 = standardized
        let r2 = rect.standardized

        let minX = min(r1.minX, r2.minX)
        let maxX = max(r1.maxX, r2.maxX)
        let minY = min(r1.minY, r2.minY)
        let maxY = max(r1.maxY, r2.maxY)

        return Rect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    public func offsetBy(dx: Double, dy: Double) -> Rect {
        guard !isNull else {
            return self
        }

        let rect = standardized
        return Rect(
            origin: Point(
                x: rect.origin.x + dx,
                y: rect.origin.y + dy
            ),
            size: rect.size
        )
    }

    public func insetBy(dx: Double, dy: Double) -> Rect {
        guard !isNull else {
            return self
        }

        let normalized = standardized
        let rect = Rect(
            origin: Point(
                x: normalized.x + dx,
                y: normalized.y + dy
            ),
            size: Size(
                width: normalized.width - (dx * 2),
                height: normalized.height - (dy * 2)
            )
        )

        guard rect.size.width >= 0, rect.size.height >= 0 else {
            return .null
        }

        return rect
    }

    public func expandedBy(dx: Double, dy: Double) -> Rect {
        insetBy(dx: -dx, dy: -dy)
    }
}

public extension Rect {
    @available(*, deprecated, renamed: "origin(_:)")
    func with(origin value: Point) -> Rect {
        Rect(origin: value, size: size)
    }

    @available(*, deprecated, renamed: "size(_:)")
    func with(size value: Size) -> Rect {
        Rect(origin: origin, size: value)
    }
}
