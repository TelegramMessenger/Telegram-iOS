//
//  MaskPoint.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Part of the face, relative to which a mask is placed
public indirect enum MaskPoint: Codable, Equatable, Hashable {

    /// The mask is placed relatively to the forehead
    case maskPointForehead

    /// The mask is placed relatively to the eyes
    case maskPointEyes

    /// The mask is placed relatively to the mouth
    case maskPointMouth

    /// The mask is placed relatively to the chin
    case maskPointChin

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case maskPointForehead
        case maskPointEyes
        case maskPointMouth
        case maskPointChin
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .maskPointForehead:
            self = .maskPointForehead
        case .maskPointEyes:
            self = .maskPointEyes
        case .maskPointMouth:
            self = .maskPointMouth
        case .maskPointChin:
            self = .maskPointChin
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .maskPointForehead:
            try container.encode(Kind.maskPointForehead, forKey: .type)
        case .maskPointEyes:
            try container.encode(Kind.maskPointEyes, forKey: .type)
        case .maskPointMouth:
            try container.encode(Kind.maskPointMouth, forKey: .type)
        case .maskPointChin:
            try container.encode(Kind.maskPointChin, forKey: .type)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

