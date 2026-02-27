import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public enum EmojiGameInfo: Codable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case type
        case info
    }
    
    public struct Info: Codable, Equatable {
        public let gameHash: String
        public let previousStake: Int64
        public let currentStreak: Int32
        public let parameters: [Int32]
        public let playsLeft: Int32?
    }
    
    case available(Info)
    case unavailable
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        
        let type = try container.decode(Int32.self, forKey: .type)
        switch type {
        case 1:
            self = .available(try container.decode(Info.self, forKey: .info))
        default:
            self = .unavailable
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .available(info):
            try container.encode(Int32(1), forKey: .type)
            try container.encode(info, forKey: .info)
        case .unavailable:
            try container.encode(Int32(0), forKey: .type)
        }
    }
}

extension EmojiGameInfo {
    init(apiEmojiGameInfo: Api.messages.EmojiGameInfo) {
        switch apiEmojiGameInfo {
        case let .emojiGameDiceInfo(emojiGameDiceInfoData):
            let (gameHash, prevStake, currentStreak, params, playsLeft) = (emojiGameDiceInfoData.gameHash, emojiGameDiceInfoData.prevStake, emojiGameDiceInfoData.currentStreak, emojiGameDiceInfoData.params, emojiGameDiceInfoData.playsLeft)
            self = .available(Info(gameHash: gameHash, previousStake: prevStake, currentStreak: currentStreak, parameters: params, playsLeft: playsLeft))
        case .emojiGameUnavailable:
            self = .unavailable
        }
    }
}


public func currentEmojiGameInfo(transaction: Transaction) -> EmojiGameInfo {
    if let entry = transaction.getPreferencesEntry(key: PreferencesKeys.emojiGameInfo())?.get(EmojiGameInfo.self) {
        return entry
    } else {
        return .unavailable
    }
}

func updateEmojiGameInfo(transaction: Transaction, _ f: (EmojiGameInfo) -> EmojiGameInfo) {
    let current = currentEmojiGameInfo(transaction: transaction)
    let updated = f(current)
    if updated != current {
        transaction.setPreferencesEntry(key: PreferencesKeys.emojiGameInfo(), value: PreferencesEntry(updated))
    }
}

func updateEmojiGameInfoOnce(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    return network.request(Api.functions.messages.getEmojiGameInfo())
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.messages.EmojiGameInfo?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<Void, NoError> in
        guard let result else {
            return .complete()
        }
        return postbox.transaction { transaction -> Void in
            let info = EmojiGameInfo(apiEmojiGameInfo: result)
            updateEmojiGameInfo(transaction: transaction) { _ in
                return info
            }
        }
    }
}

func managedEmojiGameUpdates(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let poll = Signal<Void, NoError> { subscriber in
        return updateEmojiGameInfoOnce(postbox: postbox, network: network).start(completed: {
            subscriber.putCompletion()
        })
    }
    return (poll |> then(.complete() |> suspendAwareDelay(1.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}
