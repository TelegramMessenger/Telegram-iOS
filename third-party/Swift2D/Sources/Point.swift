/// The representation of a single point in a two-dimensional plane.
public struct Point: Hashable, Codable, Sendable, CustomStringConvertible {

    public static let zero: Point = Point(x: 0, y: 0)
    public static let nan: Point = Point(x: Double.nan, y: Double.nan)
    public static let infinite: Point = Point(x: -Double.greatestFiniteMagnitude / 2, y: -Double.greatestFiniteMagnitude / 2)
    public static let null: Point = Point(x: Double.infinity, y: Double.infinity)

    public let x: Double
    public let y: Double

    public init(x: Double = 0.0, y: Double = 0.0) {
        self.x = x
        self.y = y
    }

    public init(x: Float, y: Float) {
        self.x = Double(x)
        self.y = Double(y)
    }

    public init(x: Int, y: Int) {
        self.x = Double(x)
        self.y = Double(y)
    }

    public var description: String { "Point(x: \(x), y: \(y))" }
    public var isZero: Bool { self == .zero }
    public var isNaN: Bool { self == .nan }
    public var isInfinite: Bool { self == .infinite }
    public var isNull: Bool { self == .null }

    /// Create a new instance maintaining the `y` value while using the provided `x` value.
    public func x(_ value: Double) -> Point {
        Point(x: value, y: y)
    }

    /// Create a new instance maintaining the `x` value while using the provided `y` value.
    public func y(_ value: Double) -> Point {
        Point(x: x, y: value)
    }

    /// The _mirror_ of the instance, rotated 180° around the provided `point`
    /// in a two-dimensional plane.
    ///
    /// - parameters:
    ///   - point: The anchor to use in calculating the reflection.
    public func reflecting(around point: Point) -> Point {
        let x = (2 * point.x) - x
        let y = (2 * point.y) - y
        return Point(x: x, y: y)
    }

    public static func == (lhs: Point, rhs: Point) -> Bool {
        if lhs.x.isNaN, rhs.x.isNaN, lhs.y.isNaN, rhs.y.isNaN {
            return true
        }

        if lhs.x.isInfinite, rhs.x.isInfinite, lhs.y.isInfinite, rhs.y.isInfinite {
            return true
        }

        return lhs.x == rhs.x && lhs.y == rhs.y
    }
}

public extension Point {
    @available(*, deprecated, renamed: "x(_:)")
    func with(x value: Double) -> Point {
        x(value)
    }

    @available(*, deprecated, renamed: "y(_:)")
    func with(y value: Double) -> Point {
        y(value)
    }

    @available(*, deprecated, renamed: "reflecting(around:)")
    func reflection(using point: Point) -> Point {
        reflecting(around: point)
    }
}
