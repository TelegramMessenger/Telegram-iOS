//
//  ChatSource.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes a reason why an external chat is shown in a chat list
public indirect enum ChatSource: Codable, Equatable, Hashable {

    /// The chat is sponsored by the user's MTProxy server
    case chatSourceMtprotoProxy

    /// The chat contains a public service announcement
    case chatSourcePublicServiceAnnouncement(ChatSourcePublicServiceAnnouncement)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case chatSourceMtprotoProxy
        case chatSourcePublicServiceAnnouncement
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .chatSourceMtprotoProxy:
            self = .chatSourceMtprotoProxy
        case .chatSourcePublicServiceAnnouncement:
            let value = try ChatSourcePublicServiceAnnouncement(from: decoder)
            self = .chatSourcePublicServiceAnnouncement(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .chatSourceMtprotoProxy:
            try container.encode(Kind.chatSourceMtprotoProxy, forKey: .type)
        case .chatSourcePublicServiceAnnouncement(let value):
            try container.encode(Kind.chatSourcePublicServiceAnnouncement, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// The chat contains a public service announcement
public struct ChatSourcePublicServiceAnnouncement: Codable, Equatable, Hashable {

    /// The text of the announcement
    public let text: String

    /// The type of the announcement
    public let type: String


    public init(
        text: String,
        type: String
    ) {
        self.text = text
        self.type = type
    }
}

