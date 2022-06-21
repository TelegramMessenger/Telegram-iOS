import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit

public final class AvailableReactions: Equatable, Codable {
    public final class Reaction: Equatable, Codable {
        private enum CodingKeys: String, CodingKey {
            case isEnabled
            case value
            case title
            case staticIcon
            case appearAnimation
            case selectAnimation
            case activateAnimation
            case effectAnimation
            case aroundAnimation
            case centerAnimation
        }
        
        public let isEnabled: Bool
        public let value: String
        public let title: String
        public let staticIcon: TelegramMediaFile
        public let appearAnimation: TelegramMediaFile
        public let selectAnimation: TelegramMediaFile
        public let activateAnimation: TelegramMediaFile
        public let effectAnimation: TelegramMediaFile
        public let aroundAnimation: TelegramMediaFile?
        public let centerAnimation: TelegramMediaFile?
        
        public init(
            isEnabled: Bool,
            value: String,
            title: String,
            staticIcon: TelegramMediaFile,
            appearAnimation: TelegramMediaFile,
            selectAnimation: TelegramMediaFile,
            activateAnimation: TelegramMediaFile,
            effectAnimation: TelegramMediaFile,
            aroundAnimation: TelegramMediaFile?,
            centerAnimation: TelegramMediaFile?
        ) {
            self.isEnabled = isEnabled
            self.value = value
            self.title = title
            self.staticIcon = staticIcon
            self.appearAnimation = appearAnimation
            self.selectAnimation = selectAnimation
            self.activateAnimation = activateAnimation
            self.effectAnimation = effectAnimation
            self.aroundAnimation = aroundAnimation
            self.centerAnimation = centerAnimation
        }
        
        public static func ==(lhs: Reaction, rhs: Reaction) -> Bool {
            if lhs.isEnabled != rhs.isEnabled {
                return false
            }
            if lhs.value != rhs.value {
                return false
            }
            if lhs.title != rhs.title {
                return false
            }
            if lhs.staticIcon != rhs.staticIcon {
                return false
            }
            if lhs.appearAnimation != rhs.appearAnimation {
                return false
            }
            if lhs.selectAnimation != rhs.selectAnimation {
                return false
            }
            if lhs.activateAnimation != rhs.activateAnimation {
                return false
            }
            if lhs.effectAnimation != rhs.effectAnimation {
                return false
            }
            if lhs.aroundAnimation != rhs.aroundAnimation {
                return false
            }
            if lhs.centerAnimation != rhs.centerAnimation {
                return false
            }
            return true
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
            
            self.value = try container.decode(String.self, forKey: .value)
            self.title = try container.decode(String.self, forKey: .title)
            
            let staticIconData = try container.decode(AdaptedPostboxDecoder.RawObjectData.self, forKey: .staticIcon)
            self.staticIcon = TelegramMediaFile(decoder: PostboxDecoder(buffer: MemoryBuffer(data: staticIconData.data)))
            
            let appearAnimationData = try container.decode(AdaptedPostboxDecoder.RawObjectData.self, forKey: .appearAnimation)
            self.appearAnimation = TelegramMediaFile(decoder: PostboxDecoder(buffer: MemoryBuffer(data: appearAnimationData.data)))
            
            let selectAnimationData = try container.decode(AdaptedPostboxDecoder.RawObjectData.self, forKey: .selectAnimation)
            self.selectAnimation = TelegramMediaFile(decoder: PostboxDecoder(buffer: MemoryBuffer(data: selectAnimationData.data)))
            
            let activateAnimationData = try container.decode(AdaptedPostboxDecoder.RawObjectData.self, forKey: .activateAnimation)
            self.activateAnimation = TelegramMediaFile(decoder: PostboxDecoder(buffer: MemoryBuffer(data: activateAnimationData.data)))
            
            let effectAnimationData = try container.decode(AdaptedPostboxDecoder.RawObjectData.self, forKey: .effectAnimation)
            self.effectAnimation = TelegramMediaFile(decoder: PostboxDecoder(buffer: MemoryBuffer(data: effectAnimationData.data)))
            
            if let aroundAnimationData = try container.decodeIfPresent(AdaptedPostboxDecoder.RawObjectData.self, forKey: .aroundAnimation) {
                self.aroundAnimation = TelegramMediaFile(decoder: PostboxDecoder(buffer: MemoryBuffer(data: aroundAnimationData.data)))
            } else {
                self.aroundAnimation = nil
            }
            
            if let centerAnimationData = try container.decodeIfPresent(AdaptedPostboxDecoder.RawObjectData.self, forKey: .centerAnimation) {
                self.centerAnimation = TelegramMediaFile(decoder: PostboxDecoder(buffer: MemoryBuffer(data: centerAnimationData.data)))
            } else {
                self.centerAnimation = nil
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(self.isEnabled, forKey: .isEnabled)
            
            try container.encode(self.value, forKey: .value)
            try container.encode(self.title, forKey: .title)
            
            try container.encode(PostboxEncoder().encodeObjectToRawData(self.staticIcon), forKey: .staticIcon)
            try container.encode(PostboxEncoder().encodeObjectToRawData(self.appearAnimation), forKey: .appearAnimation)
            try container.encode(PostboxEncoder().encodeObjectToRawData(self.selectAnimation), forKey: .selectAnimation)
            try container.encode(PostboxEncoder().encodeObjectToRawData(self.activateAnimation), forKey: .activateAnimation)
            try container.encode(PostboxEncoder().encodeObjectToRawData(self.effectAnimation), forKey: .effectAnimation)
            if let aroundAnimation = self.aroundAnimation {
                try container.encode(PostboxEncoder().encodeObjectToRawData(aroundAnimation), forKey: .aroundAnimation)
            }
            if let centerAnimation = self.centerAnimation {
                try container.encode(PostboxEncoder().encodeObjectToRawData(centerAnimation), forKey: .centerAnimation)
            }
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case hash
        case reactions
    }
    
    public let hash: Int32
    public let reactions: [Reaction]
    
    public init(
        hash: Int32,
        reactions: [Reaction]
    ) {
        self.hash = hash
        self.reactions = reactions
    }
    
    public static func ==(lhs: AvailableReactions, rhs: AvailableReactions) -> Bool {
        if lhs.hash != rhs.hash {
            return false
        }
        if lhs.reactions != rhs.reactions {
            return false
        }
        return true
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.hash = try container.decode(Int32.self, forKey: .hash)
        self.reactions = try container.decode([Reaction].self, forKey: .reactions)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.hash, forKey: .hash)
        try container.encode(self.reactions, forKey: .reactions)
    }
}

private extension AvailableReactions.Reaction {
    convenience init?(apiReaction: Api.AvailableReaction) {
        switch apiReaction {
        case let .availableReaction(flags, reaction, title, staticIcon, appearAnimation, selectAnimation, activateAnimation, effectAnimation, aroundAnimation, centerIcon):
            guard let staticIconFile = telegramMediaFileFromApiDocument(staticIcon) else {
                return nil
            }
            guard let appearAnimationFile = telegramMediaFileFromApiDocument(appearAnimation) else {
                return nil
            }
            guard let selectAnimationFile = telegramMediaFileFromApiDocument(selectAnimation) else {
                return nil
            }
            guard let activateAnimationFile = telegramMediaFileFromApiDocument(activateAnimation) else {
                return nil
            }
            guard let effectAnimationFile = telegramMediaFileFromApiDocument(effectAnimation) else {
                return nil
            }
            let aroundAnimationFile = aroundAnimation.flatMap(telegramMediaFileFromApiDocument)
            let centerAnimationFile = centerIcon.flatMap(telegramMediaFileFromApiDocument)
            let isEnabled = (flags & (1 << 0)) == 0
            self.init(
                isEnabled: isEnabled,
                value: reaction,
                title: title,
                staticIcon: staticIconFile,
                appearAnimation: appearAnimationFile,
                selectAnimation: selectAnimationFile,
                activateAnimation: activateAnimationFile,
                effectAnimation: effectAnimationFile,
                aroundAnimation: aroundAnimationFile,
                centerAnimation: centerAnimationFile
            )
        }
    }
}

func _internal_cachedAvailableReactions(postbox: Postbox) -> Signal<AvailableReactions?, NoError> {
    return postbox.transaction { transaction -> AvailableReactions? in
        return _internal_cachedAvailableReactions(transaction: transaction)
    }
}

func _internal_cachedAvailableReactions(transaction: Transaction) -> AvailableReactions? {
    let key = ValueBoxKey(length: 8)
    key.setInt64(0, value: 0)
    
    let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.availableReactions, key: key))?.get(AvailableReactions.self)
    if let cached = cached {
        return cached
    } else {
        return nil
    }
}

func _internal_setCachedAvailableReactions(transaction: Transaction, availableReactions: AvailableReactions) {
    let key = ValueBoxKey(length: 8)
    key.setInt64(0, value: 0)
    
    if let entry = CodableEntry(availableReactions) {
        transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.availableReactions, key: key), entry: entry, collectionSpec: ItemCacheCollectionSpec(lowWaterItemCount: 10, highWaterItemCount: 10))
    }
}

func managedSynchronizeAvailableReactions(postbox: Postbox, network: Network) -> Signal<Never, NoError> {
    let poll = Signal<Never, NoError> { subscriber in
        let signal: Signal<Never, NoError> = _internal_cachedAvailableReactions(postbox: postbox)
        |> mapToSignal { current in
            return (network.request(Api.functions.messages.getAvailableReactions(hash: current?.hash ?? 0))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.messages.AvailableReactions?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { result -> Signal<Never, NoError> in
                return postbox.transaction { transaction -> Signal<Never, NoError> in
                    guard let result = result else {
                        return .complete()
                    }
                    switch result {
                    case let .availableReactions(hash, reactions):
                        let availableReactions = AvailableReactions(
                            hash: hash,
                            reactions: reactions.compactMap(AvailableReactions.Reaction.init(apiReaction:))
                        )
                        _internal_setCachedAvailableReactions(transaction: transaction, availableReactions: availableReactions)
                    case .availableReactionsNotModified:
                        break
                    }
                    
                    var signals: [Signal<Never, NoError>] = []
                    
                    if let availableReactions = _internal_cachedAvailableReactions(transaction: transaction) {
                        var resources: [MediaResource] = []
                        
                        for reaction in availableReactions.reactions {
                            resources.append(reaction.staticIcon.resource)
                            resources.append(reaction.appearAnimation.resource)
                            resources.append(reaction.selectAnimation.resource)
                            resources.append(reaction.activateAnimation.resource)
                            resources.append(reaction.effectAnimation.resource)
                            if let centerAnimation = reaction.centerAnimation {
                                resources.append(centerAnimation.resource)
                            }
                            if let aroundAnimation = reaction.aroundAnimation {
                                resources.append(aroundAnimation.resource)
                            }
                        }
                        
                        for resource in resources {
                            signals.append(
                                fetchedMediaResource(mediaBox: postbox.mediaBox, reference: .standalone(resource: resource))
                                |> ignoreValues
                                |> `catch` { _ -> Signal<Never, NoError> in
                                    return .complete()
                                }
                            )
                        }
                    }
                    
                    return combineLatest(signals)
                    |> ignoreValues
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
