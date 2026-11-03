//
//  InviteLinkChatType.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes the type of chat to which points an invite link
public indirect enum InviteLinkChatType: Codable, Equatable, Hashable {

    /// The link is an invite link for a basic group
    case inviteLinkChatTypeBasicGroup

    /// The link is an invite link for a supergroup
    case inviteLinkChatTypeSupergroup

    /// The link is an invite link for a channel
    case inviteLinkChatTypeChannel

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case inviteLinkChatTypeBasicGroup
        case inviteLinkChatTypeSupergroup
        case inviteLinkChatTypeChannel
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .inviteLinkChatTypeBasicGroup:
            self = .inviteLinkChatTypeBasicGroup
        case .inviteLinkChatTypeSupergroup:
            self = .inviteLinkChatTypeSupergroup
        case .inviteLinkChatTypeChannel:
            self = .inviteLinkChatTypeChannel
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .inviteLinkChatTypeBasicGroup:
            try container.encode(Kind.inviteLinkChatTypeBasicGroup, forKey: .type)
        case .inviteLinkChatTypeSupergroup:
            try container.encode(Kind.inviteLinkChatTypeSupergroup, forKey: .type)
        case .inviteLinkChatTypeChannel:
            try container.encode(Kind.inviteLinkChatTypeChannel, forKey: .type)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

