import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

private class AdMessagesHistoryContextImpl {
    final class CachedMessage: Equatable, Codable {
        enum CodingKeys: String, CodingKey {
            case opaqueId
            case text
            case textEntities
            case media
            case authorId
            case startParam
        }

        public let opaqueId: Data
        public let text: String
        public let textEntities: [MessageTextEntity]
        public let media: [Media]
        public let authorId: PeerId
        public let startParam: String?

        public init(
            opaqueId: Data,
            text: String,
            textEntities: [MessageTextEntity],
            media: [Media],
            authorId: PeerId,
            startParam: String?
        ) {
            self.opaqueId = opaqueId
            self.text = text
            self.textEntities = textEntities
            self.media = media
            self.authorId = authorId
            self.startParam = startParam
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.opaqueId = try container.decode(Data.self, forKey: .opaqueId)

            self.text = try container.decode(String.self, forKey: .text)
            self.textEntities = try container.decode([MessageTextEntity].self, forKey: .textEntities)

            let mediaData = try container.decode([Data].self, forKey: .media)
            self.media = mediaData.compactMap { data -> Media? in
                return PostboxDecoder(buffer: MemoryBuffer(data: data)).decodeRootObject() as? Media
            }

            self.authorId = try container.decode(PeerId.self, forKey: .authorId)

            self.startParam = try container.decodeIfPresent(String.self, forKey: .startParam)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(self.opaqueId, forKey: .opaqueId)
            try container.encode(self.text, forKey: .text)
            try container.encode(self.textEntities, forKey: .textEntities)

            let mediaData = self.media.map { media -> Data in
                let encoder = PostboxEncoder()
                encoder.encodeRootObject(media)
                return encoder.makeData()
            }
            try container.encode(mediaData, forKey: .media)

            try container.encode(self.authorId, forKey: .authorId)
            try container.encodeIfPresent(self.startParam, forKey: .startParam)
        }

        public static func ==(lhs: CachedMessage, rhs: CachedMessage) -> Bool {
            if lhs.opaqueId != rhs.opaqueId {
                return false
            }
            if lhs.text != rhs.text {
                return false
            }
            if lhs.textEntities != rhs.textEntities {
                return false
            }
            if lhs.media.count != rhs.media.count {
                return false
            }
            for i in 0 ..< lhs.media.count {
                if !lhs.media[i].isEqual(to: rhs.media[i]) {
                    return false
                }
            }
            if lhs.authorId != rhs.authorId {
                return false
            }
            if lhs.startParam != rhs.startParam {
                return false
            }
            return true
        }

        func toMessage(peerId: PeerId, transaction: Transaction) -> Message {
            var attributes: [MessageAttribute] = []

            attributes.append(AdMessageAttribute(opaqueId: self.opaqueId, startParam: self.startParam))
            if !self.textEntities.isEmpty {
                let attribute = TextEntitiesMessageAttribute(entities: self.textEntities)
                attributes.append(attribute)
            }

            var messagePeers = SimpleDictionary<PeerId, Peer>()

            if let peer = transaction.getPeer(peerId) {
                messagePeers[peer.id] = peer
            }
            if let peer = transaction.getPeer(self.authorId) {
                messagePeers[peer.id] = peer
            }

            return Message(
                stableId: 0,
                stableVersion: 0,
                id: MessageId(peerId: peerId, namespace: Namespaces.Message.Local, id: 0),
                globallyUniqueId: nil,
                groupingKey: nil,
                groupInfo: nil,
                threadId: nil,
                timestamp: Int32.max - 1,
                flags: [.Incoming],
                tags: [],
                globalTags: [],
                localTags: [],
                forwardInfo: nil,
                author: transaction.getPeer(self.authorId),
                text: self.text,
                attributes: attributes,
                media: self.media,
                peers: messagePeers,
                associatedMessages: SimpleDictionary<MessageId, Message>(),
                associatedMessageIds: []
            )
        }
    }

    private let queue: Queue
    private let account: Account
    private let peerId: PeerId

    private let maskAsSeenDisposables = DisposableDict<Data>()

    struct CachedState: Codable, PostboxCoding {
        enum CodingKeys: String, CodingKey {
            case timestamp
            case messages
        }

        var timestamp: Int32
        var messages: [CachedMessage]

        init(timestamp: Int32, messages: [CachedMessage]) {
            self.timestamp = timestamp
            self.messages = messages
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.timestamp = try container.decode(Int32.self, forKey: .timestamp)
            self.messages = try container.decode([CachedMessage].self, forKey: .messages)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(self.timestamp, forKey: .timestamp)
            try container.encode(self.messages, forKey: .messages)
        }

        init(decoder: PostboxDecoder) {
            self.timestamp = decoder.decodeInt32ForKey("timestamp", orElse: 0)
            if let messagesData = decoder.decodeOptionalDataArrayForKey("messages") {
                self.messages = messagesData.compactMap { data -> CachedMessage? in
                    return try? AdaptedPostboxDecoder().decode(CachedMessage.self, from: data)
                }
            } else {
                self.messages = []
            }
        }

        func encode(_ encoder: PostboxEncoder) {
            encoder.encodeInt32(self.timestamp, forKey: "timestamp")
            encoder.encodeDataArray(self.messages.compactMap { message -> Data? in
                return try? AdaptedPostboxEncoder().encode(message)
            }, forKey: "messages")
        }

        private static let collectionSpec = ItemCacheCollectionSpec(lowWaterItemCount: 5, highWaterItemCount: 10)

        public static func getCached(postbox: Postbox, peerId: PeerId) -> Signal<CachedState?, NoError> {
            return postbox.transaction { transaction -> CachedState? in
                let key = ValueBoxKey(length: 8)
                key.setInt64(0, value: peerId.toInt64())
                if let entry = transaction.retrieveItemCacheEntryData(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedAdMessageStates, key: key)) {
                    return try? AdaptedPostboxDecoder().decode(CachedState.self, from: entry)
                } else {
                    return nil
                }
            }
        }

        public static func setCached(transaction: Transaction, peerId: PeerId, state: CachedState?) {
            let key = ValueBoxKey(length: 8)
            key.setInt64(0, value: peerId.toInt64())
            let id = ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedAdMessageStates, key: key)
            if let state = state, let stateData = try? AdaptedPostboxEncoder().encode(state) {
                transaction.putItemCacheEntryData(id: id, entry: stateData, collectionSpec: collectionSpec)
            } else {
                transaction.removeItemCacheEntry(id: id)
            }
        }
    }
    
    struct State: Equatable {
        var messages: [Message]

        static func ==(lhs: State, rhs: State) -> Bool {
            if lhs.messages.count != rhs.messages.count {
                return false
            }
            for i in 0 ..< lhs.messages.count {
                if lhs.messages[i].id != rhs.messages[i].id {
                    return false
                }
                if lhs.messages[i].stableId != rhs.messages[i].stableId {
                    return false
                }
            }
            return true
        }
    }
    
    let state = Promise<State>()
    private var stateValue: State? {
        didSet {
            if let stateValue = self.stateValue, stateValue != oldValue {
                self.state.set(.single(stateValue))
            }
        }
    }

    private let disposable = MetaDisposable()
    
    init(queue: Queue, account: Account, peerId: PeerId) {
        self.queue = queue
        self.account = account
        self.peerId = peerId

        self.stateValue = State(messages: [])

        self.state.set(CachedState.getCached(postbox: account.postbox, peerId: peerId)
        |> mapToSignal { cachedState -> Signal<State, NoError> in
            if let cachedState = cachedState, cachedState.timestamp >= Int32(Date().timeIntervalSince1970) - 5 * 60 {
                return account.postbox.transaction { transaction -> State in
                    return State(messages: cachedState.messages.map { message in
                        return message.toMessage(peerId: peerId, transaction: transaction)
                    })
                }
            } else {
                return .single(State(messages: []))
            }
        })

        let signal: Signal<[Message], NoError> = account.postbox.transaction { transaction -> Api.InputChannel? in
            return transaction.getPeer(peerId).flatMap(apiInputChannel)
        }
        |> mapToSignal { inputChannel -> Signal<[Message], NoError> in
            guard let inputChannel = inputChannel else {
                return .single([])
            }
            return account.network.request(Api.functions.channels.getSponsoredMessages(channel: inputChannel))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.messages.SponsoredMessages?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { result -> Signal<[Message], NoError> in
                guard let result = result else {
                    return .single([])
                }

                return account.postbox.transaction { transaction -> [Message] in
                    switch result {
                    case let .sponsoredMessages(messages, chats, users):
                        var peers: [Peer] = []
                        var peerPresences: [PeerId: PeerPresence] = [:]

                        for chat in chats {
                            if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                                peers.append(groupOrChannel)
                            }
                        }
                        for user in users {
                            let telegramUser = TelegramUser(user: user)
                            peers.append(telegramUser)
                            if let presence = TelegramUserPresence(apiUser: user) {
                                peerPresences[telegramUser.id] = presence
                            }
                        }

                        updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                            return updated
                        })

                        updatePeerPresences(transaction: transaction, accountPeerId: account.peerId, peerPresences: peerPresences)

                        var parsedMessages: [CachedMessage] = []

                        for message in messages {
                            switch message {
                            case let .sponsoredMessage(_, randomId, fromId, startParam, message, entities):
                                var parsedEntities: [MessageTextEntity] = []
                                if let entities = entities {
                                    parsedEntities = messageTextEntitiesFromApiEntities(entities)
                                }

                                let parsedMedia: [Media] = []
                                /*if let media = media {
                                    let (mediaValue, _) = textMediaAndExpirationTimerFromApiMedia(media, peerId)
                                    if let mediaValue = mediaValue {
                                        parsedMedia.append(mediaValue)
                                    }
                                }*/

                                parsedMessages.append(CachedMessage(
                                    opaqueId: randomId.makeData(),
                                    text: message,
                                    textEntities: parsedEntities,
                                    media: parsedMedia,
                                    authorId: fromId.peerId,
                                    startParam: startParam
                                ))
                            }
                        }

                        CachedState.setCached(transaction: transaction, peerId: peerId, state: CachedState(timestamp: Int32(Date().timeIntervalSince1970), messages: parsedMessages))

                        return parsedMessages.map { message in
                            return message.toMessage(peerId: peerId, transaction: transaction)
                        }
                    }
                }
            }
        }
        
        self.disposable.set((signal
        |> deliverOn(self.queue)).start(next: { [weak self] messages in
            guard let strongSelf = self else {
                return
            }
            strongSelf.stateValue = State(messages: messages)
        }))
    }
    
    deinit {
        self.disposable.dispose()
        self.maskAsSeenDisposables.dispose()
    }

    func markAsSeen(opaqueId: Data) {
        let signal: Signal<Never, NoError> = account.postbox.transaction { transaction -> Api.InputChannel? in
            return transaction.getPeer(self.peerId).flatMap(apiInputChannel)
        }
        |> mapToSignal { inputChannel -> Signal<Never, NoError> in
            guard let inputChannel = inputChannel else {
                return .complete()
            }
            return self.account.network.request(Api.functions.channels.viewSponsoredMessage(channel: inputChannel, randomId: Buffer(data: opaqueId)))
            |> `catch` { _ -> Signal<Api.Bool, NoError> in
                return .single(.boolFalse)
            }
            |> ignoreValues
        }
        self.maskAsSeenDisposables.set(signal.start(), forKey: opaqueId)
    }
}

public class AdMessagesHistoryContext {
    private let queue = Queue()
    private let impl: QueueLocalObject<AdMessagesHistoryContextImpl>
    
    public var state: Signal<[Message], NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.impl.with { impl in
                let stateDisposable = impl.state.get().start(next: { state in
                    subscriber.putNext(state.messages)
                })
                disposable.set(stateDisposable)
            }
            
            return disposable
        }
    }
    
    public init(account: Account, peerId: PeerId) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return AdMessagesHistoryContextImpl(queue: queue, account: account, peerId: peerId)
        })
    }

    public func markAsSeen(opaqueId: Data) {
        self.impl.with { impl in
            impl.markAsSeen(opaqueId: opaqueId)
        }
    }
}
