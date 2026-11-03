//
//  ButtonStyle.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes style of a button
public indirect enum ButtonStyle: Codable, Equatable, Hashable {

    /// The button has default style
    case buttonStyleDefault

    /// The button has dark blue color
    case buttonStylePrimary

    /// The button has red color
    case buttonStyleDanger

    /// The button has green color
    case buttonStyleSuccess

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case buttonStyleDefault
        case buttonStylePrimary
        case buttonStyleDanger
        case buttonStyleSuccess
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .buttonStyleDefault:
            self = .buttonStyleDefault
        case .buttonStylePrimary:
            self = .buttonStylePrimary
        case .buttonStyleDanger:
            self = .buttonStyleDanger
        case .buttonStyleSuccess:
            self = .buttonStyleSuccess
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .buttonStyleDefault:
            try container.encode(Kind.buttonStyleDefault, forKey: .type)
        case .buttonStylePrimary:
            try container.encode(Kind.buttonStylePrimary, forKey: .type)
        case .buttonStyleDanger:
            try container.encode(Kind.buttonStyleDanger, forKey: .type)
        case .buttonStyleSuccess:
            try container.encode(Kind.buttonStyleSuccess, forKey: .type)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

