//
//  TargetChat.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes the target chat to be opened
public indirect enum TargetChat: Codable, Equatable, Hashable {

    /// The currently opened chat and forum topic must be kept
    case targetChatCurrent

    /// The chat needs to be chosen by the user among chats of the specified types
    case targetChatChosen(TargetChatChosen)

    /// The chat needs to be open with the provided internal link
    case targetChatInternalLink(TargetChatInternalLink)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case targetChatCurrent
        case targetChatChosen
        case targetChatInternalLink
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .targetChatCurrent:
            self = .targetChatCurrent
        case .targetChatChosen:
            let value = try TargetChatChosen(from: decoder)
            self = .targetChatChosen(value)
        case .targetChatInternalLink:
            let value = try TargetChatInternalLink(from: decoder)
            self = .targetChatInternalLink(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .targetChatCurrent:
            try container.encode(Kind.targetChatCurrent, forKey: .type)
        case .targetChatChosen(let value):
            try container.encode(Kind.targetChatChosen, forKey: .type)
            try value.encode(to: encoder)
        case .targetChatInternalLink(let value):
            try container.encode(Kind.targetChatInternalLink, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// The chat needs to be chosen by the user among chats of the specified types
public struct TargetChatChosen: Codable, Equatable, Hashable {

    /// Allowed types for the chat
    public let types: TargetChatTypes


    public init(types: TargetChatTypes) {
        self.types = types
    }
}

/// The chat needs to be open with the provided internal link
public struct TargetChatInternalLink: Codable, Equatable, Hashable {

    /// An internal link pointing to the chat
    public let link: InternalLinkType


    public init(link: InternalLinkType) {
        self.link = link
    }
}

