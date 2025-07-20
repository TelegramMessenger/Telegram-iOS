import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

private class AdMessagesHistoryContextImpl {
    final class CachedMessage: Equatable, Codable {
        enum CodingKeys: String, CodingKey {
            case opaqueId
            case messageType
            case title
            case text
            case textEntities
            case media
            case contentMedia
            case color
            case backgroundEmojiId
            case url
            case buttonText
            case sponsorInfo
            case additionalInfo
            case canReport
            case minDisplayDuration
            case maxDisplayDuration
        }
        
        enum MessageType: Int32, Codable {
            case sponsored = 0
            case recommended = 1
        }
        
        public let opaqueId: Data
        public let messageType: MessageType
        public let title: String
        public let text: String
        public let textEntities: [MessageTextEntity]
        public let media: [Media]
        public let contentMedia: [Media]
        public let color: PeerNameColor?
        public let backgroundEmojiId: Int64?
        public let url: String
        public let buttonText: String
        public let sponsorInfo: String?
        public let additionalInfo: String?
        public let canReport: Bool
        public let minDisplayDuration: Int32?
        public let maxDisplayDuration: Int32?
        
        public init(
            opaqueId: Data,
            messageType: MessageType,
            title: String,
            text: String,
            textEntities: [MessageTextEntity],
            media: [Media],
            contentMedia: [Media],
            color: PeerNameColor?,
            backgroundEmojiId: Int64?,
            url: String,
            buttonText: String,
            sponsorInfo: String?,
            additionalInfo: String?,
            canReport: Bool,
            minDisplayDuration: Int32?,
            maxDisplayDuration: Int32?
        ) {
            self.opaqueId = opaqueId
            self.messageType = messageType
            self.title = title
            self.text = text
            self.textEntities = textEntities
            self.media = media
            self.contentMedia = contentMedia
            self.color = color
            self.backgroundEmojiId = backgroundEmojiId
            self.url = url
            self.buttonText = buttonText
            self.sponsorInfo = sponsorInfo
            self.additionalInfo = additionalInfo
            self.canReport = canReport
            self.minDisplayDuration = minDisplayDuration
            self.maxDisplayDuration = maxDisplayDuration
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.opaqueId = try container.decode(Data.self, forKey: .opaqueId)
            
            if let messageType = try container.decodeIfPresent(Int32.self, forKey: .messageType) {
                self.messageType = MessageType(rawValue: messageType) ?? .sponsored
            } else {
                self.messageType = .sponsored
            }
            
            self.title = try container.decode(String.self, forKey: .title)
            self.text = try container.decode(String.self, forKey: .text)
            self.textEntities = try container.decode([MessageTextEntity].self, forKey: .textEntities)

            let mediaData = try container.decode([Data].self, forKey: .media)
            self.media = mediaData.compactMap { data -> Media? in
                return PostboxDecoder(buffer: MemoryBuffer(data: data)).decodeRootObject() as? Media
            }
            
            let contentMediaData = try container.decode([Data].self, forKey: .contentMedia)
            self.contentMedia = contentMediaData.compactMap { data -> Media? in
                return PostboxDecoder(buffer: MemoryBuffer(data: data)).decodeRootObject() as? Media
            }
            
            self.color = try container.decodeIfPresent(Int32.self, forKey: .color).flatMap { PeerNameColor(rawValue: $0) }
            self.backgroundEmojiId = try container.decodeIfPresent(Int64.self, forKey: .backgroundEmojiId)

            self.url = try container.decode(String.self, forKey: .url)
            self.buttonText = try container.decode(String.self, forKey: .buttonText)
            
            self.sponsorInfo = try container.decodeIfPresent(String.self, forKey: .sponsorInfo)
            self.additionalInfo = try container.decodeIfPresent(String.self, forKey: .additionalInfo)
            
            self.canReport = try container.decodeIfPresent(Bool.self, forKey: .canReport) ?? false
            
            self.minDisplayDuration = try container.decodeIfPresent(Int32.self, forKey: .minDisplayDuration)
            self.maxDisplayDuration = try container.decodeIfPresent(Int32.self, forKey: .maxDisplayDuration)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(self.opaqueId, forKey: .opaqueId)
            try container.encode(self.messageType.rawValue, forKey: .messageType)
            try container.encode(self.title, forKey: .title)
            try container.encode(self.text, forKey: .text)
            try container.encode(self.textEntities, forKey: .textEntities)

            let mediaData = self.media.map { media -> Data in
                let encoder = PostboxEncoder()
                encoder.encodeRootObject(media)
                return encoder.makeData()
            }
            try container.encode(mediaData, forKey: .media)
            
            let contentMediaData = self.contentMedia.map { media -> Data in
                let encoder = PostboxEncoder()
                encoder.encodeRootObject(media)
                return encoder.makeData()
            }
            try container.encode(contentMediaData, forKey: .contentMedia)

            try container.encodeIfPresent(self.color?.rawValue, forKey: .color)
            try container.encodeIfPresent(self.backgroundEmojiId, forKey: .backgroundEmojiId)
            
            try container.encode(self.url, forKey: .url)
            try container.encode(self.buttonText, forKey: .buttonText)
            
            try container.encodeIfPresent(self.sponsorInfo, forKey: .sponsorInfo)
            try container.encodeIfPresent(self.additionalInfo, forKey: .additionalInfo)
            
            try container.encode(self.canReport, forKey: .canReport)
            
            try container.encodeIfPresent(self.minDisplayDuration, forKey: .minDisplayDuration)
            try container.encodeIfPresent(self.maxDisplayDuration, forKey: .maxDisplayDuration)
        }

        public static func ==(lhs: CachedMessage, rhs: CachedMessage) -> Bool {
            if lhs.opaqueId != rhs.opaqueId {
                return false
            }
            if lhs.messageType != rhs.messageType {
                return false
            }
            if lhs.title != rhs.title {
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
            if lhs.contentMedia.count != rhs.contentMedia.count {
                return false
            }
            for i in 0 ..< lhs.contentMedia.count {
                if !lhs.contentMedia[i].isEqual(to: rhs.contentMedia[i]) {
                    return false
                }
            }
            if lhs.url != rhs.url {
                return false
            }
            if lhs.buttonText != rhs.buttonText {
                return false
            }
            if lhs.sponsorInfo != rhs.sponsorInfo {
                return false
            }
            if lhs.additionalInfo != rhs.additionalInfo {
                return false
            }
            if lhs.canReport != rhs.canReport {
                return false
            }
            if lhs.minDisplayDuration != rhs.minDisplayDuration {
                return false
            }
            if lhs.maxDisplayDuration != rhs.maxDisplayDuration {
                return false
            }
            return true
        }

        func toMessage(peerId: PeerId, transaction: Transaction) -> Message? {
            var attributes: [MessageAttribute] = []

            let mappedMessageType: AdMessageAttribute.MessageType
            switch self.messageType {
            case .sponsored:
                mappedMessageType = .sponsored
            case .recommended:
                mappedMessageType = .recommended
            }
            let adAttribute = AdMessageAttribute(
                opaqueId: self.opaqueId,
                messageType: mappedMessageType,
                url: self.url,
                buttonText: self.buttonText,
                sponsorInfo: self.sponsorInfo,
                additionalInfo: self.additionalInfo,
                canReport: self.canReport,
                hasContentMedia: !self.contentMedia.isEmpty,
                minDisplayDuration: self.minDisplayDuration,
                maxDisplayDuration: self.maxDisplayDuration
            )
            attributes.append(adAttribute)
            if !self.textEntities.isEmpty {
                let entitiesAttribute = TextEntitiesMessageAttribute(entities: self.textEntities)
                attributes.append(entitiesAttribute)
            }

            var messagePeers = SimpleDictionary<PeerId, Peer>()

            if let peer = transaction.getPeer(peerId) {
                messagePeers[peer.id] = peer
            }
            
            let author: Peer = TelegramChannel(
                id: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(1)),
                accessHash: nil,
                title: self.title,
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
                defaultBannedRights: nil,
                usernames: [],
                storiesHidden: nil,
                nameColor: self.color ?? .blue,
                backgroundEmojiId: self.backgroundEmojiId,
                profileColor: nil,
                profileBackgroundEmojiId: nil,
                emojiStatus: nil,
                approximateBoostLevel: nil,
                subscriptionUntilDate: nil,
                verificationIconFileId: nil,
                sendPaidMessageStars: nil,
                linkedMonoforumId: nil
            )
            messagePeers[author.id] = author
            
            let messageHash = (self.text.hashValue &+ 31 &* peerId.hashValue) &* 31 &+ author.id.hashValue
            let messageStableVersion = UInt32(bitPattern: Int32(truncatingIfNeeded: messageHash))
            
            return Message(
                stableId: 0,
                stableVersion: messageStableVersion,
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
                customTags: [],
                forwardInfo: nil,
                author: author,
                text: self.text,
                attributes: attributes,
                media: !self.contentMedia.isEmpty ? self.contentMedia : self.media,
                peers: messagePeers,
                associatedMessages: SimpleDictionary<MessageId, Message>(),
                associatedMessageIds: [],
                associatedMedia: [:],
                associatedThreadInfo: nil,
                associatedStories: [:]
            )
        }
    }

    private let queue: Queue
    private let account: Account
    private let peerId: EnginePeer.Id
    private let messageId: EngineMessage.Id?

    private let maskAsSeenDisposables = DisposableDict<Data>()

    struct CachedState: Codable, PostboxCoding {
        enum CodingKeys: String, CodingKey {
            case timestamp
            case interPostInterval
            case messages
        }

        var timestamp: Int32
        var interPostInterval: Int32?
        var messages: [CachedMessage]

        init(timestamp: Int32, interPostInterval: Int32?, messages: [CachedMessage]) {
            self.timestamp = timestamp
            self.interPostInterval = interPostInterval
            self.messages = messages
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.timestamp = try container.decode(Int32.self, forKey: .timestamp)
            self.interPostInterval = try container.decodeIfPresent(Int32.self, forKey: .interPostInterval)
            self.messages = try container.decode([CachedMessage].self, forKey: .messages)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(self.timestamp, forKey: .timestamp)
            try container.encodeIfPresent(self.interPostInterval, forKey: .interPostInterval)
            try container.encode(self.messages, forKey: .messages)
        }

        init(decoder: PostboxDecoder) {
            self.timestamp = decoder.decodeInt32ForKey("timestamp", orElse: 0)
            self.interPostInterval = decoder.decodeOptionalInt32ForKey("interPostInterval")
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
            if let interPostInterval = self.interPostInterval {
                encoder.encodeInt32(interPostInterval, forKey: "interPostInterval")
            } else {
                encoder.encodeNil(forKey: "interPostInterval")
            }
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
        var interPostInterval: Int32?
        var startDelay: Int32?
        var betweenDelay: Int32?
        var messages: [Message]

        static func ==(lhs: State, rhs: State) -> Bool {
            if lhs.interPostInterval != rhs.interPostInterval {
                return false
            }
            if lhs.startDelay != rhs.startDelay {
                return false
            }
            if lhs.betweenDelay != rhs.betweenDelay {
                return false
            }
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
    
    init(queue: Queue, account: Account, peerId: EnginePeer.Id, messageId: EngineMessage.Id?) {
        self.queue = queue
        self.account = account
        self.peerId = peerId
        self.messageId = messageId
        
        let accountPeerId = account.peerId

        self.stateValue = State(interPostInterval: nil, messages: [])

        if messageId == nil {
            self.state.set(CachedState.getCached(postbox: account.postbox, peerId: peerId)
            |> mapToSignal { cachedState -> Signal<State, NoError> in
                if let cachedState = cachedState, cachedState.timestamp >= Int32(Date().timeIntervalSince1970) - 5 * 60 {
                    return account.postbox.transaction { transaction -> State in
                        return State(interPostInterval: cachedState.interPostInterval, messages: cachedState.messages.compactMap { message -> Message? in
                            return message.toMessage(peerId: peerId, transaction: transaction)
                        })
                    }
                } else {
                    return .single(State(interPostInterval: nil, messages: []))
                }
            })
        }

        let signal: Signal<(interPostInterval: Int32?, startDelay: Int32?, betweenDelay: Int32?, messages: [Message]), NoError> = account.postbox.transaction { transaction -> Api.InputPeer? in
            return transaction.getPeer(peerId).flatMap(apiInputPeer)
        }
        |> mapToSignal { inputPeer -> Signal<(interPostInterval: Int32?, startDelay: Int32?, betweenDelay: Int32?, messages: [Message]), NoError> in
            guard let inputPeer else {
                return .single((nil, nil, nil, []))
            }
            var flags: Int32 = 0
            if let _ = messageId {
                flags |= (1 << 0)
            }
            return account.network.request(Api.functions.messages.getSponsoredMessages(flags: flags, peer: inputPeer, msgId: messageId?.id))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.messages.SponsoredMessages?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { result -> Signal<(interPostInterval: Int32?, startDelay: Int32?, betweenDelay: Int32?, messages: [Message]), NoError> in
                guard let result = result else {
                    return .single((nil, nil, nil, []))
                }

                return account.postbox.transaction { transaction -> (interPostInterval: Int32?, startDelay: Int32?, betweenDelay: Int32?, messages: [Message]) in
                    switch result {
                    case let .sponsoredMessages(_, postsBetween, startDelay, betweenDelay, messages, chats, users):
                        let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                        updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)

                        var parsedMessages: [CachedMessage] = []

                        for message in messages {
                            switch message {
                            case let .sponsoredMessage(flags, randomId, url, title, message, entities, photo, media, color, buttonText, sponsorInfo, additionalInfo, minDisplayDuration, maxDisplayDuration):
                                var parsedEntities: [MessageTextEntity] = []
                                if let entities = entities {
                                    parsedEntities = messageTextEntitiesFromApiEntities(entities)
                                }
                                
                                let isRecommended = (flags & (1 << 5)) != 0
                                let canReport = (flags & (1 << 12)) != 0
                                
                                var nameColorIndex: Int32?
                                var backgroundEmojiId: Int64?
                                if let color = color {
                                    switch color {
                                    case let .peerColor(_, color, backgroundEmojiIdValue):
                                        nameColorIndex = color
                                        backgroundEmojiId = backgroundEmojiIdValue
                                    }
                                }
                                
                                let photo = photo.flatMap { telegramMediaImageFromApiPhoto($0) }
                                let contentMedia = textMediaAndExpirationTimerFromApiMedia(media, peerId).media
                                
                                parsedMessages.append(CachedMessage(
                                    opaqueId: randomId.makeData(),
                                    messageType: isRecommended ? .recommended : .sponsored,
                                    title: title,
                                    text: message,
                                    textEntities: parsedEntities,
                                    media: photo.flatMap { [$0] } ?? [],
                                    contentMedia: contentMedia.flatMap { [$0] } ?? [],
                                    color: nameColorIndex.flatMap { PeerNameColor(rawValue: $0) },
                                    backgroundEmojiId: backgroundEmojiId,
                                    url: url,
                                    buttonText: buttonText,
                                    sponsorInfo: sponsorInfo,
                                    additionalInfo: additionalInfo,
                                    canReport: canReport,
                                    minDisplayDuration: minDisplayDuration,
                                    maxDisplayDuration: maxDisplayDuration
                                ))
                            }
                        }

                        if messageId == nil {
                            CachedState.setCached(transaction: transaction, peerId: peerId, state: CachedState(timestamp: Int32(Date().timeIntervalSince1970), interPostInterval: postsBetween, messages: parsedMessages))
                        }
                        
                        return (postsBetween, startDelay, betweenDelay, parsedMessages.compactMap { message -> Message? in
                            return message.toMessage(peerId: peerId, transaction: transaction)
                        })
                    case .sponsoredMessagesEmpty:
                        return (nil, nil, nil, [])
                    }
                }
            }
        }
        
        self.disposable.set((signal
        |> deliverOn(self.queue)).start(next: { [weak self] interPostInterval, startDelay, betweenDelay, messages in
            guard let strongSelf = self else {
                return
            }
            strongSelf.stateValue = State(interPostInterval: interPostInterval, startDelay: startDelay, betweenDelay: betweenDelay, messages: messages)
        }))
    }
    
    deinit {
        self.disposable.dispose()
        self.maskAsSeenDisposables.dispose()
    }

    func markAsSeen(opaqueId: Data) {
        let signal: Signal<Never, NoError> = self.account.network.request(Api.functions.messages.viewSponsoredMessage(randomId: Buffer(data: opaqueId)))
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> ignoreValues
        self.maskAsSeenDisposables.set(signal.start(), forKey: opaqueId)
    }
    
    func markAction(opaqueId: Data, media: Bool, fullscreen: Bool) {
        _internal_markAdAction(account: self.account, opaqueId: opaqueId, media: media, fullscreen: fullscreen)
    }
    
    func remove(opaqueId: Data) {
        if var stateValue = self.stateValue {
            if let index = stateValue.messages.firstIndex(where: { $0.adAttribute?.opaqueId == opaqueId }) {
                stateValue.messages.remove(at: index)
                self.stateValue = stateValue
            }
        }
        
        let peerId = self.peerId
        let _ = (self.account.postbox.transaction { transaction -> Void in
            let key = ValueBoxKey(length: 8)
            key.setInt64(0, value: peerId.toInt64())
            let id = ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedAdMessageStates, key: key)
            guard var cachedState = transaction.retrieveItemCacheEntry(id: id)?.get(CachedState.self) else {
                return
            }
            if let index = cachedState.messages.firstIndex(where: { $0.opaqueId == opaqueId }) {
                cachedState.messages.remove(at: index)
                if let entry = CodableEntry(cachedState) {
                    transaction.putItemCacheEntry(id: id, entry: entry)
                }
            }
        }).start()
    }
}

public class AdMessagesHistoryContext {
    private let queue = Queue()
    private let impl: QueueLocalObject<AdMessagesHistoryContextImpl>
    public let peerId: EnginePeer.Id
    public let messageId: EngineMessage.Id?
    
    public var state: Signal<(interPostInterval: Int32?, messages: [Message], startDelay: Int32?, betweenDelay: Int32?), NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.impl.with { impl in
                let stateDisposable = impl.state.get().start(next: { state in
                    subscriber.putNext((state.interPostInterval, state.messages, state.startDelay, state.betweenDelay))
                })
                disposable.set(stateDisposable)
            }
            
            return disposable
        }
    }
    
    public init(account: Account, peerId: EnginePeer.Id, messageId: EngineMessage.Id? = nil) {
        self.peerId = peerId
        self.messageId = messageId
        
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return AdMessagesHistoryContextImpl(queue: queue, account: account, peerId: peerId, messageId: messageId)
        })
    }

    public func markAsSeen(opaqueId: Data) {
        self.impl.with { impl in
            impl.markAsSeen(opaqueId: opaqueId)
        }
    }
    
    public func markAction(opaqueId: Data, media: Bool, fullscreen: Bool) {
        self.impl.with { impl in
            impl.markAction(opaqueId: opaqueId, media: media, fullscreen: fullscreen)
        }
    }
    
    public func remove(opaqueId: Data) {
        self.impl.with { impl in
            impl.remove(opaqueId: opaqueId)
        }
    }
}


func _internal_markAdAction(account: Account, opaqueId: Data, media: Bool, fullscreen: Bool) {
    var flags: Int32 = 0
    if media {
        flags |= (1 << 0)
    }
    if fullscreen {
        flags |= (1 << 1)
    }
    let signal = account.network.request(Api.functions.messages.clickSponsoredMessage(flags: flags, randomId: Buffer(data: opaqueId)))
    |> `catch` { _ -> Signal<Api.Bool, NoError> in
        return .single(.boolFalse)
    }
    |> ignoreValues
    let _ = signal.start()
}

func _internal_markAdAsSeen(account: Account, opaqueId: Data) {
    let signal = account.network.request(Api.functions.messages.viewSponsoredMessage(randomId: Buffer(data: opaqueId)))
    |> `catch` { _ -> Signal<Api.Bool, NoError> in
        return .single(.boolFalse)
    }
    |> ignoreValues
    let _ = signal.start()
}
