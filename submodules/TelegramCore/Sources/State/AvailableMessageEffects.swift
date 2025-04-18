import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit

public final class AvailableMessageEffects: Equatable, Codable {
    public final class MessageEffect: Equatable, Codable {
        private enum CodingKeys: String, CodingKey {
            case id
            case isPremium
            case emoticon
            case staticIcon
            case effectSticker
            case effectAnimation
        }
        
        public let id: Int64
        public let isPremium: Bool
        public let emoticon: String
        public let staticIcon: TelegramMediaFile?
        public let effectSticker: TelegramMediaFile
        public let effectAnimation: TelegramMediaFile?
        
        public init(
            id: Int64,
            isPremium: Bool,
            emoticon: String,
            staticIcon: TelegramMediaFile?,
            effectSticker: TelegramMediaFile,
            effectAnimation: TelegramMediaFile?
        ) {
            self.id = id
            self.isPremium = isPremium
            self.emoticon = emoticon
            self.staticIcon = staticIcon
            self.effectSticker = effectSticker
            self.effectAnimation = effectAnimation
        }
        
        public static func ==(lhs: MessageEffect, rhs: MessageEffect) -> Bool {
            if lhs.id != rhs.id {
                return false
            }
            if lhs.isPremium != rhs.isPremium {
                return false
            }
            if lhs.emoticon != rhs.emoticon {
                return false
            }
            if lhs.staticIcon != rhs.staticIcon {
                return false
            }
            if lhs.effectSticker != rhs.effectSticker {
                return false
            }
            if lhs.effectAnimation != rhs.effectAnimation {
                return false
            }
            return true
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.id = try container.decode(Int64.self, forKey: .id)
            self.isPremium = try container.decodeIfPresent(Bool.self, forKey: .isPremium) ?? false
            self.emoticon = try container.decode(String.self, forKey: .emoticon)
            
            if let staticIconData = try container.decodeIfPresent(AdaptedPostboxDecoder.RawObjectData.self, forKey: .staticIcon) {
                self.staticIcon = TelegramMediaFile(decoder: PostboxDecoder(buffer: MemoryBuffer(data: staticIconData.data)))
            } else {
                self.staticIcon = nil
            }
            
            do {
                let effectStickerData = try container.decode(AdaptedPostboxDecoder.RawObjectData.self, forKey: .effectSticker)
                self.effectSticker = TelegramMediaFile(decoder: PostboxDecoder(buffer: MemoryBuffer(data: effectStickerData.data)))
            }
            
            if let effectAnimationData = try container.decodeIfPresent(AdaptedPostboxDecoder.RawObjectData.self, forKey: .effectAnimation) {
                self.effectAnimation = TelegramMediaFile(decoder: PostboxDecoder(buffer: MemoryBuffer(data: effectAnimationData.data)))
            } else {
                self.effectAnimation = nil
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(self.id, forKey: .id)
            try container.encode(self.emoticon, forKey: .emoticon)
            try container.encode(self.isPremium, forKey: .isPremium)
            
            if let staticIcon = self.staticIcon {
                try container.encode(PostboxEncoder().encodeObjectToRawData(staticIcon), forKey: .staticIcon)
            }
            try container.encode(PostboxEncoder().encodeObjectToRawData(self.effectSticker), forKey: .effectSticker)
            if let effectAnimation = self.effectAnimation {
                try container.encode(PostboxEncoder().encodeObjectToRawData(effectAnimation), forKey: .effectAnimation)
            }
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case newHash
        case messageEffects
    }
    
    public let hash: Int32
    public let messageEffects: [MessageEffect]
    
    public init(
        hash: Int32,
        messageEffects: [MessageEffect]
    ) {
        self.hash = hash
        self.messageEffects = messageEffects
    }
    
    public static func ==(lhs: AvailableMessageEffects, rhs: AvailableMessageEffects) -> Bool {
        if lhs.hash != rhs.hash {
            return false
        }
        if lhs.messageEffects != rhs.messageEffects {
            return false
        }
        return true
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.hash = try container.decodeIfPresent(Int32.self, forKey: .newHash) ?? 0
        self.messageEffects = try container.decode([MessageEffect].self, forKey: .messageEffects)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.hash, forKey: .newHash)
        try container.encode(self.messageEffects, forKey: .messageEffects)
    }
}

//availableEffect flags:# premium_required:flags.2?true id:long emoticon:string static_icon_id:flags.0?long effect_sticker_id:long effect_animation_id:flags.1?long = AvailableEffect;

private extension AvailableMessageEffects.MessageEffect {
    convenience init?(apiMessageEffect: Api.AvailableEffect, files: [Int64: TelegramMediaFile]) {
        switch apiMessageEffect {
        case let .availableEffect(flags, id, emoticon, staticIconId, effectStickerId, effectAnimationId):
            guard let effectSticker = files[effectStickerId] else {
                return nil
            }
            
            let isPremium = (flags & (1 << 2)) != 0
            self.init(
                id: id,
                isPremium: isPremium,
                emoticon: emoticon,
                staticIcon: staticIconId.flatMap({ files[$0] }),
                effectSticker: effectSticker,
                effectAnimation: effectAnimationId.flatMap({ files[$0] })
            )
        }
    }
}

func _internal_cachedAvailableMessageEffects(postbox: Postbox) -> Signal<AvailableMessageEffects?, NoError> {
    return postbox.transaction { transaction -> AvailableMessageEffects? in
        return _internal_cachedAvailableMessageEffects(transaction: transaction)
    }
}

func _internal_cachedAvailableMessageEffects(transaction: Transaction) -> AvailableMessageEffects? {
    let key = ValueBoxKey(length: 8)
    key.setInt64(0, value: 0)
    
    let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.availableMessageEffects, key: key))?.get(AvailableMessageEffects.self)
    if let cached = cached {
        return cached
    } else {
        return nil
    }
}

func _internal_setCachedAvailableMessageEffects(transaction: Transaction, availableMessageEffects: AvailableMessageEffects) {
    let key = ValueBoxKey(length: 8)
    key.setInt64(0, value: 0)
    
    if let entry = CodableEntry(availableMessageEffects) {
        transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.availableMessageEffects, key: key), entry: entry)
    }
}

func managedSynchronizeAvailableMessageEffects(postbox: Postbox, network: Network) -> Signal<Never, NoError> {
    let poll = Signal<Never, NoError> { subscriber in
        let signal: Signal<Never, NoError> = _internal_cachedAvailableMessageEffects(postbox: postbox)
        |> mapToSignal { current in
            let sourceHash: Int32
            #if DEBUG
            sourceHash = 0
            #else
            sourceHash = current?.hash ?? 0
            #endif
            return (network.request(Api.functions.messages.getAvailableEffects(hash: sourceHash))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.messages.AvailableEffects?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { result -> Signal<Never, NoError> in
                return postbox.transaction { transaction -> Signal<Never, NoError> in
                    guard let result = result else {
                        return .complete()
                    }
                    switch result {
                    case let .availableEffects(hash, effects, documents):
                        var files: [Int64: TelegramMediaFile] = [:]
                        for document in documents {
                            if let file = telegramMediaFileFromApiDocument(document, altDocuments: []) {
                                files[file.fileId.id] = file
                            }
                        }
                        
                        var parsedEffects: [AvailableMessageEffects.MessageEffect] = []
                        for effect in effects {
                            if let parsedEffect = AvailableMessageEffects.MessageEffect(apiMessageEffect: effect, files: files) {
                                parsedEffects.append(parsedEffect)
                            }
                        }
                        _internal_setCachedAvailableMessageEffects(transaction: transaction, availableMessageEffects: AvailableMessageEffects(
                            hash: hash,
                            messageEffects: parsedEffects
                        ))
                    case .availableEffectsNotModified:
                        break
                    }
                    
                    /*var signals: [Signal<Never, NoError>] = []
                    
                    if let availableMessageEffects = _internal_cachedAvailableMessageEffects(transaction: transaction) {
                        var resources: [MediaResource] = []
                        
                        for messageEffect in availableMessageEffects.messageEffects {
                            if let staticIcon = messageEffect.staticIcon {
                                resources.append(staticIcon.resource)
                            }
                            if messageEffect.effectSticker.isPremiumSticker {
                                if let effectFile = messageEffect.effectSticker.videoThumbnails.first {
                                    resources.append(effectFile.resource)
                                }
                            } else {
                                if let effectAnimation = messageEffect.effectAnimation {
                                    resources.append(effectAnimation.resource)
                                }
                            }
                        }
                        
                        for resource in resources {
                            signals.append(
                                fetchedMediaResource(mediaBox: postbox.mediaBox, userLocation: .other, userContentType: .other, reference: .standalone(resource: resource))
                                |> ignoreValues
                                |> `catch` { _ -> Signal<Never, NoError> in
                                    return .complete()
                                }
                            )
                        }
                    }
                    
                    return combineLatest(signals)
                    |> ignoreValues*/
                    
                    return .complete()
                }
                |> switchToLatest
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
    		|> suspendAwareDelay(1.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue())
    	)
    )
    |> restart
}

public extension Message {
    func messageEffect(availableMessageEffects: AvailableMessageEffects?) -> AvailableMessageEffects.MessageEffect? {
        guard let availableMessageEffects else {
            return nil
        }
        for attribute in self.attributes {
            if let attribute = attribute as? EffectMessageAttribute {
                for effect in availableMessageEffects.messageEffects {
                    if effect.id == attribute.id {
                        return effect
                    }
                }
                break
            }
        }
        return nil
    }
}
