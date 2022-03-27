import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit

//# inactive:flags.0?true bot_id:long attach_menu_name:string attach_menu_icon:Document = AttachMenuBot;
public final class AttachMenuBots: Equatable, Codable {
    public final class Bot: Equatable, Codable {
        private enum CodingKeys: String, CodingKey {
            case peerId
            case name
            case icon
        }
        
        public let peerId: PeerId
        public let name: String
        public let icon: TelegramMediaFile
        
        public init(
            peerId: PeerId,
            name: String,
            icon: TelegramMediaFile
        ) {
            self.peerId = peerId
            self.name = name
            self.icon = icon
        }
        
        public static func ==(lhs: Bot, rhs: Bot) -> Bool {
            if lhs.peerId != rhs.peerId {
                return false
            }
            if lhs.name != rhs.name {
                return false
            }
            if lhs.icon != rhs.icon {
                return false
            }
            return true
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            let peerIdValue = try container.decode(Int64.self, forKey: .peerId)
            self.peerId = PeerId(peerIdValue)
            
            self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
            
            let iconData = try container.decode(AdaptedPostboxDecoder.RawObjectData.self, forKey: .icon)
            self.icon = TelegramMediaFile(decoder: PostboxDecoder(buffer: MemoryBuffer(data: iconData.data)))
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(self.peerId.toInt64(), forKey: .peerId)
            try container.encode(self.name, forKey: .name)
            try container.encode(PostboxEncoder().encodeObjectToRawData(self.icon), forKey: .icon)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case hash
        case bots
    }
    
    public let hash: Int64
    public let bots: [Bot]
    
    public init(
        hash: Int64,
        bots: [Bot]
    ) {
        self.hash = hash
        self.bots = bots
    }
    
    public static func ==(lhs: AttachMenuBots, rhs: AttachMenuBots) -> Bool {
        if lhs.hash != rhs.hash {
            return false
        }
        if lhs.bots != rhs.bots {
            return false
        }
        return true
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.hash = try container.decode(Int64.self, forKey: .hash)
        self.bots = try container.decode([Bot].self, forKey: .bots)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.hash, forKey: .hash)
        try container.encode(self.bots, forKey: .bots)
    }
}

private func cachedAttachMenuBots(postbox: Postbox) -> Signal<AttachMenuBots?, NoError> {
    return postbox.transaction { transaction -> AttachMenuBots? in
        return cachedAttachMenuBots(transaction: transaction)
    }
}

private func cachedAttachMenuBots(transaction: Transaction) -> AttachMenuBots? {
    let key = ValueBoxKey(length: 8)
    key.setInt64(0, value: 0)

    let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.attachMenuBots, key: key))?.get(AttachMenuBots.self)
    if let cached = cached {
        return cached
    } else {
        return nil
    }
}

private func setCachedAttachMenuBots(transaction: Transaction, attachMenuBots: AttachMenuBots) {
    let key = ValueBoxKey(length: 8)
    key.setInt64(0, value: 0)
    
    let entryId = ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.attachMenuBots, key: key)
    if let entry = CodableEntry(attachMenuBots) {
        transaction.putItemCacheEntry(id: entryId, entry: entry, collectionSpec: ItemCacheCollectionSpec(lowWaterItemCount: 10, highWaterItemCount: 10))
    } else {
        transaction.removeItemCacheEntry(id: entryId)
    }
}

func managedSynchronizeAttachMenuBots(postbox: Postbox, network: Network) -> Signal<Never, NoError> {
    let poll = Signal<Never, NoError> { subscriber in
        let signal: Signal<Never, NoError> = cachedAttachMenuBots(postbox: postbox)
        |> mapToSignal { current in
            return (network.request(Api.functions.messages.getAttachMenuBots(hash: current?.hash ?? 0))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.AttachMenuBots?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { result -> Signal<Never, NoError> in
                guard let result = result else {
                    return .complete()
                }
                return postbox.transaction { transaction in
                    switch result {
                        case let .attachMenuBots(hash, bots, users):
                            var peers: [Peer] = []
                            for user in users {
                                let telegramUser = TelegramUser(user: user)
                                peers.append(telegramUser)
                            }
                            updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                                return updated
                            })

                            var resultBots: [AttachMenuBots.Bot] = []
                            for bot in bots {
                                switch bot {
                                    case let .attachMenuBot(_, botId, name, attachMenuIcon):
                                        if let icon = telegramMediaFileFromApiDocument(attachMenuIcon) {
                                            resultBots.append(AttachMenuBots.Bot(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(botId)), name: name, icon: icon))
                                        }
                                }
                            }
                            
                            let attachMenuBots = AttachMenuBots(hash: hash, bots: resultBots)
                            setCachedAttachMenuBots(transaction: transaction, attachMenuBots: attachMenuBots)
                        case .attachMenuBotsNotModified:
                            break
                    }
                } |> ignoreValues
            })
        }
                
        return signal.start(completed: {
            subscriber.putCompletion()
        })
    }
    
    return (
        poll
        |> then(
            .complete()
            |> suspendAwareDelay(2.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue())
        )
    )
    |> restart
}

func _internal_addBotToAttachMenu(postbox: Postbox, network: Network, peerId: PeerId) -> Signal<Bool, NoError> {
    return postbox.transaction { transaction -> Signal<Bool, NoError> in
        guard let peer = transaction.getPeer(peerId), let inputUser = apiInputUser(peer) else {
            return .complete()
        }
        return network.request(Api.functions.messages.toggleBotInAttachMenu(bot: inputUser, enabled: .boolTrue))
        |> map { value -> Bool in
            switch value {
                case .boolTrue:
                    return true
                default:
                    return false
            }
        }
        |> `catch` { error -> Signal<Bool, NoError> in
            return .single(false)
        }
        |> afterCompleted {
            let _ = (managedSynchronizeAttachMenuBots(postbox: postbox, network: network)
            |> take(1)).start()
        }
    }
    |> switchToLatest
}

func _internal_removeBotFromAttachMenu(postbox: Postbox, network: Network, peerId: PeerId) -> Signal<Bool, NoError> {
    return postbox.transaction { transaction -> Signal<Bool, NoError> in
        guard let peer = transaction.getPeer(peerId), let inputUser = apiInputUser(peer) else {
            return .complete()
        }
        return network.request(Api.functions.messages.toggleBotInAttachMenu(bot: inputUser, enabled: .boolFalse))
        |> map { value -> Bool in
            switch value {
                case .boolTrue:
                    return true
                default:
                    return false
            }
        }
        |> `catch` { error -> Signal<Bool, NoError> in
            return .single(false)
        }
        |> afterCompleted {
            let _ = (managedSynchronizeAttachMenuBots(postbox: postbox, network: network)
            |> take(1)).start()
        }
    }
    |> switchToLatest
}

public struct AttachMenuBot {
    public let peer: Peer
    public let icon: TelegramMediaFile
    
    init(peer: Peer, icon: TelegramMediaFile) {
        self.peer = peer
        self.icon = icon
    }
}

func _internal_attachMenuBots(postbox: Postbox) -> Signal<[AttachMenuBot], NoError> {
    return postbox.transaction { transaction -> [AttachMenuBot] in
        guard let cachedBots = cachedAttachMenuBots(transaction: transaction)?.bots else {
            return []
        }
        var resultBots: [AttachMenuBot] = []
        for bot in cachedBots {
            if let peer = transaction.getPeer(bot.peerId) {
                resultBots.append(AttachMenuBot(peer: peer, icon: bot.icon))
            }
        }
        return resultBots
    }
}
