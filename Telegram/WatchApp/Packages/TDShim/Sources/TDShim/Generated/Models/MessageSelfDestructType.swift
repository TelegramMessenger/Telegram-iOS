//
//  MessageSelfDestructType.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes when a message will be self-destructed
public indirect enum MessageSelfDestructType: Codable, Equatable, Hashable {

    /// The message will be self-destructed in the specified time after its content was opened
    case messageSelfDestructTypeTimer(MessageSelfDestructTypeTimer)

    /// The message can be opened only once and will be self-destructed once closed
    case messageSelfDestructTypeImmediately

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case messageSelfDestructTypeTimer
        case messageSelfDestructTypeImmediately
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .messageSelfDestructTypeTimer:
            let value = try MessageSelfDestructTypeTimer(from: decoder)
            self = .messageSelfDestructTypeTimer(value)
        case .messageSelfDestructTypeImmediately:
            self = .messageSelfDestructTypeImmediately
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .messageSelfDestructTypeTimer(let value):
            try container.encode(Kind.messageSelfDestructTypeTimer, forKey: .type)
            try value.encode(to: encoder)
        case .messageSelfDestructTypeImmediately:
            try container.encode(Kind.messageSelfDestructTypeImmediately, forKey: .type)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// The message will be self-destructed in the specified time after its content was opened
public struct MessageSelfDestructTypeTimer: Codable, Equatable, Hashable {

    /// The message's self-destruct time, in seconds; must be between 0 and 60 in private chats
    public let selfDestructTime: Int


    public init(selfDestructTime: Int) {
        self.selfDestructTime = selfDestructTime
    }
}

