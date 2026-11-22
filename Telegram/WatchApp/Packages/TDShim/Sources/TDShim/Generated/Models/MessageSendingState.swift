//
//  MessageSendingState.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Contains information about the sending state of the message
public indirect enum MessageSendingState: Codable, Equatable, Hashable {

    /// The message is being sent now, but has not yet been delivered to the server
    case messageSendingStatePending(MessageSendingStatePending)

    /// The message failed to be sent
    case messageSendingStateFailed(MessageSendingStateFailed)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case messageSendingStatePending
        case messageSendingStateFailed
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .messageSendingStatePending:
            let value = try MessageSendingStatePending(from: decoder)
            self = .messageSendingStatePending(value)
        case .messageSendingStateFailed:
            let value = try MessageSendingStateFailed(from: decoder)
            self = .messageSendingStateFailed(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .messageSendingStatePending(let value):
            try container.encode(Kind.messageSendingStatePending, forKey: .type)
            try value.encode(to: encoder)
        case .messageSendingStateFailed(let value):
            try container.encode(Kind.messageSendingStateFailed, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// The message is being sent now, but has not yet been delivered to the server
public struct MessageSendingStatePending: Codable, Equatable, Hashable {

    /// Non-persistent message sending identifier, specified by the application
    public let sendingId: Int


    public init(sendingId: Int) {
        self.sendingId = sendingId
    }
}

/// The message failed to be sent
public struct MessageSendingStateFailed: Codable, Equatable, Hashable {

    /// True, if the message can be re-sent using resendMessages or readdQuickReplyShortcutMessages
    public let canRetry: Bool

    /// The cause of the message sending failure
    public let error: TDError

    /// True, if the message can be re-sent only if another quote is chosen in the message that is replied by the given message
    public let needAnotherReplyQuote: Bool

    /// True, if the message can be re-sent only on behalf of a different sender
    public let needAnotherSender: Bool

    /// True, if the message can be re-sent only if the message to be replied is removed. This will be done automatically by resendMessages
    public let needDropReply: Bool

    /// The number of Telegram Stars that must be paid to send the message; 0 if the current amount is correct
    public let requiredPaidMessageStarCount: Int64

    /// Time left before the message can be re-sent, in seconds. No update is sent when this field changes
    public let retryAfter: Double


    public init(
        canRetry: Bool,
        error: TDError,
        needAnotherReplyQuote: Bool,
        needAnotherSender: Bool,
        needDropReply: Bool,
        requiredPaidMessageStarCount: Int64,
        retryAfter: Double
    ) {
        self.canRetry = canRetry
        self.error = error
        self.needAnotherReplyQuote = needAnotherReplyQuote
        self.needAnotherSender = needAnotherSender
        self.needDropReply = needDropReply
        self.requiredPaidMessageStarCount = requiredPaidMessageStarCount
        self.retryAfter = retryAfter
    }
}

