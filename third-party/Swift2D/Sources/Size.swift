/// A representation of two-dimensional width and height values.
public struct Size: Hashable, Codable, Sendable, CustomStringConvertible {

    public static let zero: Size = Size(width: 0.0, height: 0.0)
    public static let nan: Size = Size(width: Double.nan, height: Double.nan)
    public static let infinite: Size = Size(width: Double.greatestFiniteMagnitude, height: Double.greatestFiniteMagnitude)

    public let width: Double
    public let height: Double

    public init(width: Double = 0.0, height: Double = 0.0) {
        self.width = width
        self.height = height
    }

    public init(width: Float, height: Float) {
        self.width = Double(width)
        self.height = Double(height)
    }

    public init(width: Int, height: Int) {
        self.width = Double(width)
        self.height = Double(height)
    }

    public var description: String { "Size(width: \(width), height: \(height))" }
    public var isZero: Bool { self == .zero }
    public var isNaN: Bool { self == .nan }
    public var isInfinite: Bool { self == .infinite }

    /// The radius defined by the `width` dimension.
    public var widthRadius: Double { abs(width) / 2.0 }

    /// The radius defined by the `height` dimension.
    public var heightRadius: Double { abs(height) / 2.0 }

    /// The largest of the width and height radii.
    public var maxRadius: Double { max(widthRadius, heightRadius) }

    /// The smallest of the width and height radii.
    public var minRadius: Double { min(widthRadius, heightRadius) }

    /// The `Point` at which the `widthRadius` & `heightRadius` intersect.
    public var center: Point { Point(x: widthRadius, y: heightRadius) }

    /// Create a new instance maintaining the `height` value while using the provided `width` value.
    public func width(_ value: Double) -> Size {
        Size(width: value, height: height)
    }

    /// Create a new instance maintaining the `width` value while using the provided `height` value.
    public func height(_ value: Double) -> Size {
        Size(width: width, height: value)
    }

    public static func == (lhs: Size, rhs: Size) -> Bool {
        if lhs.width.isNaN, rhs.width.isNaN, lhs.height.isNaN, rhs.height.isNaN {
            return true
        }

        return lhs.width == rhs.width && lhs.height == rhs.height
    }
}

public extension Size {
    @available(*, deprecated, renamed: "widthRadius")
    var xRadius: Double { abs(width) / 2.0 }

    @available(*, deprecated, renamed: "heightRadius")
    var yRadius: Double { abs(height) / 2.0 }

    @available(*, deprecated, renamed: "widthRadius")
    var horizontalRadius: Double { xRadius }

    @available(*, deprecated, renamed: "heightRadius")
    var verticalRadius: Double { yRadius }

    @available(*, deprecated, renamed: "width(_:)")
    func with(width value: Double) -> Size {
        width(value)
    }

    @available(*, deprecated, renamed: "height(_:)")
    func with(height value: Double) -> Size {
        height(value)
    }
}
