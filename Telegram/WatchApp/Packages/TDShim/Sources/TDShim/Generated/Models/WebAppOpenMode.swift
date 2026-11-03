//
//  WebAppOpenMode.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes mode in which a Web App is opened
public indirect enum WebAppOpenMode: Codable, Equatable, Hashable {

    /// The Web App is opened in the compact mode
    case webAppOpenModeCompact

    /// The Web App is opened in the full-size mode
    case webAppOpenModeFullSize

    /// The Web App is opened in the full-screen mode
    case webAppOpenModeFullScreen

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case webAppOpenModeCompact
        case webAppOpenModeFullSize
        case webAppOpenModeFullScreen
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .webAppOpenModeCompact:
            self = .webAppOpenModeCompact
        case .webAppOpenModeFullSize:
            self = .webAppOpenModeFullSize
        case .webAppOpenModeFullScreen:
            self = .webAppOpenModeFullScreen
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .webAppOpenModeCompact:
            try container.encode(Kind.webAppOpenModeCompact, forKey: .type)
        case .webAppOpenModeFullSize:
            try container.encode(Kind.webAppOpenModeFullSize, forKey: .type)
        case .webAppOpenModeFullScreen:
            try container.encode(Kind.webAppOpenModeFullScreen, forKey: .type)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

