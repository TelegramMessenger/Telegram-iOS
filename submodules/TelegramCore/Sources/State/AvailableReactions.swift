import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit

private func generateStarsReactionFile(kind: Int, isAnimatedSticker: Bool) -> TelegramMediaFile {
    let baseId: Int64 = 52343278047832950 + 10
    let fileId = baseId + Int64(kind)
    
    var attributes: [TelegramMediaFileAttribute] = []
    attributes.append(TelegramMediaFileAttribute.FileName(fileName: isAnimatedSticker ? "sticker.tgs" : "sticker.webp"))
    if !isAnimatedSticker {
        attributes.append(.CustomEmoji(isPremium: false, isSingleColor: false, alt: ".", packReference: nil))
    }
    
    return TelegramMediaFile(
        fileId: MediaId(namespace: Namespaces.Media.CloudFile, id: fileId),
        partialReference: nil,
        resource: LocalFileMediaResource(fileId: fileId),
        previewRepresentations: [],
        videoThumbnails: [],
        immediateThumbnailData: nil,
        mimeType: isAnimatedSticker ? "application/x-tgsticker" : "image/webp",
        size: nil,
        attributes: attributes,
        alternativeRepresentations: []
    )
}

private func generateStarsReaction() -> AvailableReactions.Reaction {
    return AvailableReactions.Reaction(
        isEnabled: false,
        isPremium: false,
        value: .stars,
        title: "Star",
        staticIcon: generateStarsReactionFile(kind: 0, isAnimatedSticker: true),
        appearAnimation: generateStarsReactionFile(kind: 1, isAnimatedSticker: true),
        selectAnimation: generateStarsReactionFile(kind: 2, isAnimatedSticker: true),
        activateAnimation: generateStarsReactionFile(kind: 3, isAnimatedSticker: true),
        effectAnimation: generateStarsReactionFile(kind: 4, isAnimatedSticker: true),
        aroundAnimation: generateStarsReactionFile(kind: 5, isAnimatedSticker: true),
        centerAnimation: generateStarsReactionFile(kind: 6, isAnimatedSticker: true)
    )
}

public final class AvailableReactions: Equatable, Codable {
    public final class Reaction: Equatable, Codable {
        private enum CodingKeys: String, CodingKey {
            case isEnabled
            case isPremium
            case value
            case title
            case staticIcon
            case appearAnimation
            case selectAnimation
            case activateAnimation
            case effectAnimation
            case aroundAnimation
            case centerAnimation
            case isStars
        }
        
        public let isEnabled: Bool
        public let isPremium: Bool
        public let value: MessageReaction.Reaction
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
            isPremium: Bool,
            value: MessageReaction.Reaction,
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
            self.isPremium = isPremium
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
            if lhs.isPremium != rhs.isPremium {
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
            self.isPremium = try container.decodeIfPresent(Bool.self, forKey: .isPremium) ?? false
            
            let isStars = try container.decodeIfPresent(Bool.self, forKey: .isStars) ?? false
            if isStars {
                self.value = .stars
            } else {
                self.value = .builtin(try container.decode(String.self, forKey: .value))
            }
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
            try container.encode(self.isPremium, forKey: .isPremium)
            
            switch self.value {
            case let .builtin(value):
                try container.encode(value, forKey: .value)
            case .custom:
                break
            case .stars:
                try container.encode(true, forKey: .isStars)
            }
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
        case newHash
        case reactions
    }
    
    public let hash: Int32
    public let reactions: [Reaction]
    
    public init(
        hash: Int32,
        reactions: [Reaction]
    ) {
        self.hash = hash
        
        var reactions = reactions
        reactions.removeAll(where: { if case .stars = $0.value { return true } else { return false } })
        reactions.append(generateStarsReaction())
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
        
        self.hash = try container.decodeIfPresent(Int32.self, forKey: .newHash) ?? 0
        
        var reactions = try container.decode([Reaction].self, forKey: .reactions)
        reactions.removeAll(where: { if case .stars = $0.value { return true } else { return false } })
        reactions.append(generateStarsReaction())
        self.reactions = reactions
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.hash, forKey: .newHash)
        try container.encode(self.reactions, forKey: .reactions)
    }
}

private extension AvailableReactions.Reaction {
    convenience init?(apiReaction: Api.AvailableReaction) {
        switch apiReaction {
        case let .availableReaction(flags, reaction, title, staticIcon, appearAnimation, selectAnimation, activateAnimation, effectAnimation, aroundAnimation, centerIcon):
            guard let staticIconFile = telegramMediaFileFromApiDocument(staticIcon, altDocuments: []) else {
                return nil
            }
            guard let appearAnimationFile = telegramMediaFileFromApiDocument(appearAnimation, altDocuments: []) else {
                return nil
            }
            guard let selectAnimationFile = telegramMediaFileFromApiDocument(selectAnimation, altDocuments: []) else {
                return nil
            }
            guard let activateAnimationFile = telegramMediaFileFromApiDocument(activateAnimation, altDocuments: []) else {
                return nil
            }
            guard let effectAnimationFile = telegramMediaFileFromApiDocument(effectAnimation, altDocuments: []) else {
                return nil
            }
            let aroundAnimationFile = aroundAnimation.flatMap { telegramMediaFileFromApiDocument($0, altDocuments: []) }
            let centerAnimationFile = centerIcon.flatMap { telegramMediaFileFromApiDocument($0, altDocuments: []) }
            let isEnabled = (flags & (1 << 0)) == 0
            let isPremium = (flags & (1 << 2)) != 0
            self.init(
                isEnabled: isEnabled,
                isPremium: isPremium,
                value: .builtin(reaction),
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
        transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.availableReactions, key: key), entry: entry)
    }
}

func managedSynchronizeAvailableReactions(postbox: Postbox, network: Network) -> Signal<Never, NoError> {
    let starsReaction = generateStarsReaction()
    let mapping: [String: KeyPath<AvailableReactions.Reaction, TelegramMediaFile>] = [
        "star_reaction_activate.tgs": \.activateAnimation,
        "star_reaction_appear.tgs": \.appearAnimation,
        "star_reaction_effect.tgs": \.effectAnimation,
        "star_reaction_select.tgs": \.selectAnimation,
        "star_reaction_static_icon.webp": \.staticIcon
    ]
    let optionalMapping: [String: KeyPath<AvailableReactions.Reaction, TelegramMediaFile?>] = [
        "star_reaction_center.tgs": \.centerAnimation,
        "star_reaction_effect.tgs": \.aroundAnimation
    ]
    for (key, path) in mapping {
        if let filePath = Bundle.main.path(forResource: key, ofType: nil), let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) {
            postbox.mediaBox.storeResourceData(starsReaction[keyPath: path].resource.id, data: data)
        }
    }
    for (key, path) in optionalMapping {
        if let filePath = Bundle.main.path(forResource: key, ofType: nil), let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) {
            if let file = starsReaction[keyPath: path] {
                postbox.mediaBox.storeResourceData(file.resource.id, data: data)
            }
        }
    }
    
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
                                fetchedMediaResource(mediaBox: postbox.mediaBox, userLocation: .other, userContentType: .other, reference: .standalone(resource: resource))
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
