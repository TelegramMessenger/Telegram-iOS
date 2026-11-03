//
//  OptionValue.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Represents the value of an option
public indirect enum OptionValue: Codable, Equatable, Hashable {

    /// Represents a boolean option
    case optionValueBoolean(OptionValueBoolean)

    /// Represents an unknown option or an option which has a default value
    case optionValueEmpty

    /// Represents an integer option
    case optionValueInteger(OptionValueInteger)

    /// Represents a string option
    case optionValueString(OptionValueString)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case optionValueBoolean
        case optionValueEmpty
        case optionValueInteger
        case optionValueString
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .optionValueBoolean:
            let value = try OptionValueBoolean(from: decoder)
            self = .optionValueBoolean(value)
        case .optionValueEmpty:
            self = .optionValueEmpty
        case .optionValueInteger:
            let value = try OptionValueInteger(from: decoder)
            self = .optionValueInteger(value)
        case .optionValueString:
            let value = try OptionValueString(from: decoder)
            self = .optionValueString(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .optionValueBoolean(let value):
            try container.encode(Kind.optionValueBoolean, forKey: .type)
            try value.encode(to: encoder)
        case .optionValueEmpty:
            try container.encode(Kind.optionValueEmpty, forKey: .type)
        case .optionValueInteger(let value):
            try container.encode(Kind.optionValueInteger, forKey: .type)
            try value.encode(to: encoder)
        case .optionValueString(let value):
            try container.encode(Kind.optionValueString, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// Represents a boolean option
public struct OptionValueBoolean: Codable, Equatable, Hashable {

    /// The value of the option
    public let value: Bool


    public init(value: Bool) {
        self.value = value
    }
}

/// Represents an integer option
public struct OptionValueInteger: Codable, Equatable, Hashable {

    /// The value of the option
    public let value: TdInt64


    public init(value: TdInt64) {
        self.value = value
    }
}

/// Represents a string option
public struct OptionValueString: Codable, Equatable, Hashable {

    /// The value of the option
    public let value: String


    public init(value: String) {
        self.value = value
    }
}

