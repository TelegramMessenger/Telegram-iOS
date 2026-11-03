//
//  TdInt64.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


public struct TdInt64: RawRepresentable, ExpressibleByIntegerLiteral, Hashable {

    public typealias RawValue = Int64

    // MARK: - Properties

    public var rawValue: Int64

    public static var max: TdInt64 { return TdInt64(Int64.max) }

    public static var min: TdInt64 { return TdInt64(Int64.min) }


    // MARK: - Init

    public init(_ int64: Int64) {
        self.rawValue = int64
    }

    public init?(rawValue: Int64) {
        self.rawValue = rawValue
    }

    public init(integerLiteral value: Int) {
        self.rawValue = Int64(value)
    }
}


extension TdInt64: Codable {

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let strValue = try container.decode(String.self)
        guard let value = Int64(strValue) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Can't convert String value \(strValue) to Int64."))
        }
        self.rawValue = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode("\(rawValue)")
    }

}


extension TdInt64: Comparable {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}
