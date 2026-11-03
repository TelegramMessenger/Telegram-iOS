import Foundation

/// Stable identity for a block. Encodes as a bare JSON string.
public struct BlockID: Codable, Equatable, Hashable, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) { self.rawValue = rawValue }

    public init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }

    public static func generate() -> BlockID { BlockID(UUID().uuidString) }

    public var description: String { rawValue }
}
