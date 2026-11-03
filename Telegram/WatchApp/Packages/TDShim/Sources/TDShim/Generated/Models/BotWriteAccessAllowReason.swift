//
//  BotWriteAccessAllowReason.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes a reason why a bot was allowed to write messages to the current user
public indirect enum BotWriteAccessAllowReason: Codable, Equatable, Hashable {

    /// The user connected a website by logging in using Telegram Login Widget on it
    case botWriteAccessAllowReasonConnectedWebsite(BotWriteAccessAllowReasonConnectedWebsite)

    /// The user added the bot to attachment or side menu using toggleBotIsAddedToAttachmentMenu
    case botWriteAccessAllowReasonAddedToAttachmentMenu

    /// The user launched a Web App using getWebAppLinkUrl
    case botWriteAccessAllowReasonLaunchedWebApp(BotWriteAccessAllowReasonLaunchedWebApp)

    /// The user accepted bot's request to send messages with allowBotToSendMessages
    case botWriteAccessAllowReasonAcceptedRequest

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case botWriteAccessAllowReasonConnectedWebsite
        case botWriteAccessAllowReasonAddedToAttachmentMenu
        case botWriteAccessAllowReasonLaunchedWebApp
        case botWriteAccessAllowReasonAcceptedRequest
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .botWriteAccessAllowReasonConnectedWebsite:
            let value = try BotWriteAccessAllowReasonConnectedWebsite(from: decoder)
            self = .botWriteAccessAllowReasonConnectedWebsite(value)
        case .botWriteAccessAllowReasonAddedToAttachmentMenu:
            self = .botWriteAccessAllowReasonAddedToAttachmentMenu
        case .botWriteAccessAllowReasonLaunchedWebApp:
            let value = try BotWriteAccessAllowReasonLaunchedWebApp(from: decoder)
            self = .botWriteAccessAllowReasonLaunchedWebApp(value)
        case .botWriteAccessAllowReasonAcceptedRequest:
            self = .botWriteAccessAllowReasonAcceptedRequest
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .botWriteAccessAllowReasonConnectedWebsite(let value):
            try container.encode(Kind.botWriteAccessAllowReasonConnectedWebsite, forKey: .type)
            try value.encode(to: encoder)
        case .botWriteAccessAllowReasonAddedToAttachmentMenu:
            try container.encode(Kind.botWriteAccessAllowReasonAddedToAttachmentMenu, forKey: .type)
        case .botWriteAccessAllowReasonLaunchedWebApp(let value):
            try container.encode(Kind.botWriteAccessAllowReasonLaunchedWebApp, forKey: .type)
            try value.encode(to: encoder)
        case .botWriteAccessAllowReasonAcceptedRequest:
            try container.encode(Kind.botWriteAccessAllowReasonAcceptedRequest, forKey: .type)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// The user connected a website by logging in using Telegram Login Widget on it
public struct BotWriteAccessAllowReasonConnectedWebsite: Codable, Equatable, Hashable {

    /// Domain name of the connected website
    public let domainName: String


    public init(domainName: String) {
        self.domainName = domainName
    }
}

/// The user launched a Web App using getWebAppLinkUrl
public struct BotWriteAccessAllowReasonLaunchedWebApp: Codable, Equatable, Hashable {

    /// Information about the Web App
    public let webApp: WebApp


    public init(webApp: WebApp) {
        self.webApp = webApp
    }
}

