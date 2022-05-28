import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

private class AdMessagesHistoryContextImpl {
    final class CachedMessage: Equatable, Codable {
        enum CodingKeys: String, CodingKey {
            case opaqueId
            case messageType
            case text
            case textEntities
            case media
            case target
            case messageId
            case startParam
        }
        
        enum MessageType: Int32, Codable {
            case sponsored = 0
            case recommended = 1
        }
        
        enum Target: Equatable, Codable {
            enum DecodingError: Error {
                case generic
            }
            
            enum CodingKeys: String, CodingKey {
                case peer
                case invite
            }
            
            struct Invite: Equatable, Codable {
                var title: String
                var joinHash: String
            }
            
            case peer(PeerId)
            case invite(Invite)
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                if let peer = try container.decodeIfPresent(Int64.self, forKey: .peer) {
                    self = .peer(PeerId(peer))
                } else if let invite = try container.decodeIfPresent(Invite.self, forKey: .invite) {
                    self = .invite(invite)
                } else {
                    throw DecodingError.generic
                }
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                switch self {
                case let .peer(peerId):
                    try container.encode(peerId.toInt64(), forKey: .peer)
                case let .invite(invite):
                    try container.encode(invite, forKey: .invite)
                }
            }
        }

        public let opaqueId: Data
        public let messageType: MessageType
        public let text: String
        public let textEntities: [MessageTextEntity]
        public let media: [Media]
        public let target: Target
        public let messageId: MessageId?
        public let startParam: String?

        public init(
            opaqueId: Data,
            messageType: MessageType,
            text: String,
            textEntities: [MessageTextEntity],
            media: [Media],
            target: Target,
            messageId: MessageId?,
            startParam: String?
        ) {
            self.opaqueId = opaqueId
            self.messageType = messageType
            self.text = text
            self.textEntities = textEntities
            self.media = media
            self.target = target
            self.messageId = messageId
            self.startParam = startParam
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.opaqueId = try container.decode(Data.self, forKey: .opaqueId)
            
            if let messageType = try container.decodeIfPresent(Int32.self, forKey: .messageType) {
                self.messageType = MessageType(rawValue: messageType) ?? .sponsored
            } else {
                self.messageType = .sponsored
            }
            
            self.text = try container.decode(String.self, forKey: .text)
            self.textEntities = try container.decode([MessageTextEntity].self, forKey: .textEntities)

            let mediaData = try container.decode([Data].self, forKey: .media)
            self.media = mediaData.compactMap { data -> Media? in
                return PostboxDecoder(buffer: MemoryBuffer(data: data)).decodeRootObject() as? Media
            }

            self.target = try container.decode(Target.self, forKey: .target)
            self.messageId = try container.decodeIfPresent(MessageId.self, forKey: .messageId)
            self.startParam = try container.decodeIfPresent(String.self, forKey: .startParam)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(self.opaqueId, forKey: .opaqueId)
            try container.encode(self.messageType.rawValue, forKey: .messageType)
            try container.encode(self.text, forKey: .text)
            try container.encode(self.textEntities, forKey: .textEntities)

            let mediaData = self.media.map { media -> Data in
                let encoder = PostboxEncoder()
                encoder.encodeRootObject(media)
                return encoder.makeData()
            }
            try container.encode(mediaData, forKey: .media)

            try container.encode(self.target, forKey: .target)
            try container.encodeIfPresent(self.messageId, forKey: .messageId)
            try container.encodeIfPresent(self.startParam, forKey: .startParam)
        }

        public static func ==(lhs: CachedMessage, rhs: CachedMessage) -> Bool {
            if lhs.opaqueId != rhs.opaqueId {
                return false
            }
            if lhs.messageType != rhs.messageType {
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
            if lhs.target != rhs.target {
                return false
            }
            if lhs.messageId != rhs.messageId {
                return false
            }
            if lhs.startParam != rhs.startParam {
                return false
            }
            return true
        }

        func toMessage(peerId: PeerId, transaction: Transaction) -> Message? {
            var attributes: [MessageAttribute] = []

            let target: AdMessageAttribute.MessageTarget
            switch self.target {
            case let .peer(peerId):
                target = .peer(id: peerId, message: self.messageId, startParam: self.startParam)
            case let .invite(invite):
                target = .join(title: invite.title, joinHash: invite.joinHash)
            }
            let mappedMessageType: AdMessageAttribute.MessageType
            switch self.messageType {
            case .sponsored:
                mappedMessageType = .sponsored
            case .recommended:
                mappedMessageType = .recommended
            }
            attributes.append(AdMessageAttribute(opaqueId: self.opaqueId, messageType: mappedMessageType, target: target))
            if !self.textEntities.isEmpty {
                let attribute = TextEntitiesMessageAttribute(entities: self.textEntities)
                attributes.append(attribute)
            }

            var messagePeers = SimpleDictionary<PeerId, Peer>()

            if let peer = transaction.getPeer(peerId) {
                messagePeers[peer.id] = peer
            }
            
            let author: Peer
            switch self.target {
            case let .peer(peerId):
                if let peer = transaction.getPeer(peerId) {
                    author = peer
                } else {
                    return nil
                }
            case let .invite(invite):
                author = TelegramChannel(
                    id: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(1)),
                    accessHash: nil,
                    title: invite.title,
                    username: nil,
                    photo: [],
                    creationDate: 0,
                    version: 0,
                    participationStatus: .left,
                    info: .broadcast(TelegramChannelBroadcastInfo(flags: [])),
                    flags: [],
                    restrictionInfo: nil,
                    adminRights: nil,
                    bannedRights: nil,
                    defaultBannedRights: nil
                )
            }
            
            messagePeers[author.id] = author

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
                author: author,
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

        public static func getCached(postbox: Postbox, peerId: PeerId) -> Signal<CachedState?, NoError> {
            return postbox.transaction { transaction -> CachedState? in
                let key = ValueBoxKey(length: 8)
                key.setInt64(0, value: peerId.toInt64())
                if let entry = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedAdMessageStates, key: key))?.get(CachedState.self) {
                    return entry
                } else {
                    return nil
                }
            }
        }

        public static func setCached(transaction: Transaction, peerId: PeerId, state: CachedState?) {
            let key = ValueBoxKey(length: 8)
            key.setInt64(0, value: peerId.toInt64())
            let id = ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedAdMessageStates, key: key)
            if let state = state, let entry = CodableEntry(state) {
                transaction.putItemCacheEntry(id: id, entry: entry)
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
                    return State(messages: cachedState.messages.compactMap { message -> Message? in
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
                            case let .sponsoredMessage(flags, randomId, fromId, chatInvite, chatInviteHash, channelPost, startParam, message, entities):
                                var parsedEntities: [MessageTextEntity] = []
                                if let entities = entities {
                                    parsedEntities = messageTextEntitiesFromApiEntities(entities)
                                }
                                
                                let isRecommended = (flags & (1 << 5)) != 0
                                
                                let _ = chatInvite
                                let _ = chatInviteHash
                                
                                var target: CachedMessage.Target?
                                if let fromId = fromId {
                                    target = .peer(fromId.peerId)
                                } else if let chatInvite = chatInvite, let chatInviteHash = chatInviteHash {
                                    switch chatInvite {
                                    case let .chatInvite(flags, title, _, photo, participantsCount, participants):
                                        let photo = telegramMediaImageFromApiPhoto(photo).flatMap({ smallestImageRepresentation($0.representations) })
                                        let flags: ExternalJoiningChatState.Invite.Flags = .init(isChannel: (flags & (1 << 0)) != 0, isBroadcast: (flags & (1 << 1)) != 0, isPublic: (flags & (1 << 2)) != 0, isMegagroup: (flags & (1 << 3)) != 0, requestNeeded: (flags & (1 << 6)) != 0)
                                        
                                        let _ = photo
                                        let _ = flags
                                        let _ = participantsCount
                                        let _ = participants
                                        
                                        target = .invite(CachedMessage.Target.Invite(
                                            title: title,
                                            joinHash: chatInviteHash
                                        ))
                                    case let .chatInvitePeek(chat, _):
                                        if let peer = parseTelegramGroupOrChannel(chat: chat) {
                                            target = .invite(CachedMessage.Target.Invite(
                                                title: peer.debugDisplayTitle,
                                                joinHash: chatInviteHash
                                            ))
                                        }
                                    case let .chatInviteAlready(chat):
                                        if let peer = parseTelegramGroupOrChannel(chat: chat) {
                                            target = .invite(CachedMessage.Target.Invite(
                                                title: peer.debugDisplayTitle,
                                                joinHash: chatInviteHash
                                            ))
                                        }
                                    }
                                }
                                
                                var messageId: MessageId?
                                if let fromId = fromId, let channelPost = channelPost {
                                    messageId = MessageId(peerId: fromId.peerId, namespace: Namespaces.Message.Cloud, id: channelPost)
                                }

                                if let target = target {
                                    parsedMessages.append(CachedMessage(
                                        opaqueId: randomId.makeData(),
                                        messageType: isRecommended ? .recommended : .sponsored,
                                        text: message,
                                        textEntities: parsedEntities,
                                        media: [],
                                        target: target,
                                        messageId: messageId,
                                        startParam: startParam
                                    ))
                                }
                            }
                        }

                        CachedState.setCached(transaction: transaction, peerId: peerId, state: CachedState(timestamp: Int32(Date().timeIntervalSince1970), messages: parsedMessages))

                        return parsedMessages.compactMap { message -> Message? in
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
