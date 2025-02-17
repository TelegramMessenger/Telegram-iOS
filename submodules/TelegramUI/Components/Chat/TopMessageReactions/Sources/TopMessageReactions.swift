import Foundation
import SwiftSignalKit
import TelegramCore
import Postbox
import AccountContext
import ReactionSelectionNode

public enum AllowedReactions {
    case set(Set<MessageReaction.Reaction>)
    case all
}

public func peerMessageAllowedReactions(context: AccountContext, message: Message) -> Signal<(allowedReactions: AllowedReactions?, areStarsEnabled: Bool), NoError> {
    if message.id.peerId == context.account.peerId {
        return .single((.all, false))
    }
    
    if message.containsSecretMedia {
        return .single((AllowedReactions.set(Set()), false))
    }
    
    return combineLatest(
        context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: message.id.peerId),
            TelegramEngine.EngineData.Item.Peer.ReactionSettings(id: message.id.peerId)
        ),
        context.engine.stickers.availableReactions() |> take(1)
    )
    |> map { data, availableReactions -> (allowedReactions: AllowedReactions?, areStarsEnabled: Bool) in
        let (peer, reactionSettings) = data
        
        let maxReactionCount: Int
        if let value = reactionSettings.knownValue?.maxReactionCount {
            maxReactionCount = Int(value)
        } else {
            maxReactionCount = 11
        }
        
        var areStarsEnabled: Bool = false
        if let value = reactionSettings.knownValue?.starsAllowed {
            areStarsEnabled = value
        }
        
        if let effectiveReactions = message.effectiveReactions(isTags: message.areReactionsTags(accountPeerId: context.account.peerId)), effectiveReactions.count >= maxReactionCount {
            return (.set(Set(effectiveReactions.map(\.value))), areStarsEnabled)
        }
        
        switch reactionSettings {
        case .unknown:
            if case let .channel(channel) = peer, case .broadcast = channel.info {
                if let availableReactions = availableReactions {
                    return (.set(Set(availableReactions.reactions.map(\.value))), areStarsEnabled)
                } else {
                    return (.set(Set()), areStarsEnabled)
                }
            }
            return (.all, areStarsEnabled)
        case let .known(value):
            switch value.allowedReactions {
            case .all:
                if case let .channel(channel) = peer, case .broadcast = channel.info {
                    if let availableReactions = availableReactions {
                        return (.set(Set(availableReactions.reactions.map(\.value))), areStarsEnabled)
                    } else {
                        return (.set(Set()), areStarsEnabled)
                    }
                }
                return (.all, areStarsEnabled)
            case let .limited(reactions):
                return (.set(Set(reactions)), areStarsEnabled)
            case .empty:
                return (.set(Set()), areStarsEnabled)
            }
        }
    }
}

public func tagMessageReactions(context: AccountContext, subPeerId: EnginePeer.Id?) -> Signal<[ReactionItem], NoError> {
    let topTags: Signal<([MessageReaction.Reaction], [Int64: TelegramMediaFile]), NoError> = context.engine.data.get(TelegramEngine.EngineData.Item.Messages.SavedMessageTagStats(peerId: context.account.peerId, threadId: subPeerId?.toInt64()))
    |> mapToSignal { tagStats -> Signal<([MessageReaction.Reaction], [Int64: TelegramMediaFile]), NoError> in
        let reactions = tagStats.sorted(by: { lhs, rhs in
            if lhs.value != rhs.value {
                return lhs.value > rhs.value
            }
            return lhs.key < rhs.key
        }).filter({ $0.value > 0 }).map(\.key)
        
        var customFileIds: [Int64] = []
        for reaction in reactions {
            if case let .custom(fileId) = reaction {
                if !customFileIds.contains(fileId) {
                    customFileIds.append(fileId)
                }
            }
        }
        
        return context.engine.stickers.resolveInlineStickersLocal(fileIds: customFileIds)
        |> map { files -> ([MessageReaction.Reaction], [Int64: TelegramMediaFile]) in
            return (reactions, files)
        }
    }
    
    return combineLatest(
        context.engine.stickers.availableReactions(),
        context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudDefaultTagReactions], namespaces: [ItemCollectionId.Namespace.max - 1], aroundIndex: nil, count: 10000000),
        topTags
    )
    |> take(1)
    |> map { availableReactions, view, topTags -> [ReactionItem] in
        var defaultTagReactions: OrderedItemListView?
        for orderedView in view.orderedItemListsViews {
            if orderedView.collectionId == Namespaces.OrderedItemList.CloudDefaultTagReactions {
                defaultTagReactions = orderedView
            }
        }
        
        var result: [ReactionItem] = []
        var existingIds = Set<MessageReaction.Reaction>()
        
        for reactionValue in topTags.0 {
            switch reactionValue {
            case let .builtin(value):
                if let reaction = availableReactions?.reactions.first(where: { $0.value == .builtin(value) }) {
                    guard let centerAnimation = reaction.centerAnimation else {
                        continue
                    }
                    guard let aroundAnimation = reaction.aroundAnimation else {
                        continue
                    }
                    
                    if existingIds.contains(reaction.value) {
                        continue
                    }
                    existingIds.insert(reaction.value)
                    
                    result.append(ReactionItem(
                        reaction: ReactionItem.Reaction(rawValue: reaction.value),
                        appearAnimation: reaction.appearAnimation,
                        stillAnimation: reaction.selectAnimation,
                        listAnimation: centerAnimation,
                        largeListAnimation: reaction.activateAnimation,
                        applicationAnimation: aroundAnimation,
                        largeApplicationAnimation: reaction.effectAnimation,
                        isCustom: false
                    ))
                } else {
                    continue
                }
            case let .custom(fileId):
                guard let file = topTags.1[fileId] else {
                    continue
                }
                
                if existingIds.contains(.custom(file.fileId.id)) {
                    continue
                }
                existingIds.insert(.custom(file.fileId.id))
                
                let itemFile = TelegramMediaFile.Accessor(file)
                result.append(ReactionItem(
                    reaction: ReactionItem.Reaction(rawValue: .custom(file.fileId.id)),
                    appearAnimation: itemFile,
                    stillAnimation: itemFile,
                    listAnimation: itemFile,
                    largeListAnimation: itemFile,
                    applicationAnimation: nil,
                    largeApplicationAnimation: nil,
                    isCustom: true
                ))
            case .stars:
                continue
            }
        }
        
        if let defaultTagReactions {
            for item in defaultTagReactions.items {
                guard let topReaction = item.contents.get(RecentReactionItem.self) else {
                    continue
                }
                switch topReaction.content {
                case let .builtin(value):
                    if let reaction = availableReactions?.reactions.first(where: { $0.value == .builtin(value) }) {
                        guard let centerAnimation = reaction.centerAnimation else {
                            continue
                        }
                        guard let aroundAnimation = reaction.aroundAnimation else {
                            continue
                        }
                        
                        if existingIds.contains(reaction.value) {
                            continue
                        }
                        existingIds.insert(reaction.value)
                        
                        result.append(ReactionItem(
                            reaction: ReactionItem.Reaction(rawValue: reaction.value),
                            appearAnimation: reaction.appearAnimation,
                            stillAnimation: reaction.selectAnimation,
                            listAnimation: centerAnimation,
                            largeListAnimation: reaction.activateAnimation,
                            applicationAnimation: aroundAnimation,
                            largeApplicationAnimation: reaction.effectAnimation,
                            isCustom: false
                        ))
                    } else {
                        continue
                    }
                case let .custom(file):
                    if existingIds.contains(.custom(file.fileId.id)) {
                        continue
                    }
                    existingIds.insert(.custom(file.fileId.id))
                    
                    result.append(ReactionItem(
                        reaction: ReactionItem.Reaction(rawValue: .custom(file.fileId.id)),
                        appearAnimation: file,
                        stillAnimation: file,
                        listAnimation: file,
                        largeListAnimation: file,
                        applicationAnimation: nil,
                        largeApplicationAnimation: nil,
                        isCustom: true
                    ))
                case .stars:
                    if let reaction = availableReactions?.reactions.first(where: { $0.value == .stars }) {
                        guard let centerAnimation = reaction.centerAnimation else {
                            continue
                        }
                        guard let aroundAnimation = reaction.aroundAnimation else {
                            continue
                        }
                        
                        if existingIds.contains(reaction.value) {
                            continue
                        }
                        existingIds.insert(reaction.value)
                        
                        result.append(ReactionItem(
                            reaction: ReactionItem.Reaction(rawValue: reaction.value),
                            appearAnimation: reaction.appearAnimation,
                            stillAnimation: reaction.selectAnimation,
                            listAnimation: centerAnimation,
                            largeListAnimation: reaction.activateAnimation,
                            applicationAnimation: aroundAnimation,
                            largeApplicationAnimation: reaction.effectAnimation,
                            isCustom: false
                        ))
                    } else {
                        continue
                    }
                }
            }
        }
        
        return result
    }
}

public func topMessageReactions(context: AccountContext, message: Message, subPeerId: EnginePeer.Id?) -> Signal<[ReactionItem], NoError> {
    if message.id.peerId == context.account.peerId {
        var loadTags = false
        if let effectiveReactionsAttribute = message.effectiveReactionsAttribute(isTags: message.areReactionsTags(accountPeerId: context.account.peerId)) {
            loadTags = true
            if !effectiveReactionsAttribute.reactions.isEmpty {
                if !effectiveReactionsAttribute.isTags {
                    loadTags = false
                }
            }
        } else {
            loadTags = true
        }
        
        if loadTags {
            return tagMessageReactions(context: context, subPeerId: subPeerId)
        }
    }
    
    let viewKey: PostboxViewKey = .orderedItemList(id: Namespaces.OrderedItemList.CloudTopReactions)
    let topReactions = context.account.postbox.combinedView(keys: [viewKey])
    |> map { views -> [RecentReactionItem] in
        guard let view = views.views[viewKey] as? OrderedItemListView else {
            return []
        }
        return view.items.compactMap { item -> RecentReactionItem? in
            return item.contents.get(RecentReactionItem.self)
        }
    }
    
    let allowedReactionsWithFiles: Signal<(reactions: AllowedReactions, files: [Int64: TelegramMediaFile], areStarsEnabled: Bool)?, NoError> = peerMessageAllowedReactions(context: context, message: message)
    |> mapToSignal { allowedReactions, areStarsEnabled -> Signal<(reactions: AllowedReactions, files: [Int64: TelegramMediaFile], areStarsEnabled: Bool)?, NoError> in
        guard let allowedReactions = allowedReactions else {
            return .single(nil)
        }
        
        if case let .set(reactions) = allowedReactions {
            return context.engine.stickers.resolveInlineStickers(fileIds: reactions.compactMap { item -> Int64? in
                switch item {
                case .builtin:
                    return nil
                case let .custom(fileId):
                    return fileId
                case .stars:
                    return nil
                }
            })
            |> map { files -> (reactions: AllowedReactions, files: [Int64: TelegramMediaFile], areStarsEnabled: Bool) in
                return (.set(reactions), files, areStarsEnabled)
            }
        } else {
            return .single((allowedReactions, [:], areStarsEnabled))
        }
    }

    return combineLatest(
        context.engine.stickers.availableReactions(),
        allowedReactionsWithFiles,
        topReactions
    )
    |> take(1)
    |> map { availableReactions, allowedReactionsAndFiles, topReactions -> [ReactionItem] in
        guard let availableReactions = availableReactions, let allowedReactionsAndFiles = allowedReactionsAndFiles else {
            return []
        }
        
        var result: [ReactionItem] = []
        var existingIds = Set<MessageReaction.Reaction>()
        
        for topReaction in topReactions {
            switch topReaction.content {
            case let .builtin(value):
                if let reaction = availableReactions.reactions.first(where: { $0.value == .builtin(value) }) {
                    guard let centerAnimation = reaction.centerAnimation else {
                        continue
                    }
                    guard let aroundAnimation = reaction.aroundAnimation else {
                        continue
                    }
                    
                    if existingIds.contains(reaction.value) {
                        continue
                    }
                    existingIds.insert(reaction.value)
                    
                    switch allowedReactionsAndFiles.reactions {
                    case let .set(set):
                        if !set.contains(reaction.value) {
                            continue
                        }
                    case .all:
                        break
                    }
                    
                    result.append(ReactionItem(
                        reaction: ReactionItem.Reaction(rawValue: reaction.value),
                        appearAnimation: reaction.appearAnimation,
                        stillAnimation: reaction.selectAnimation,
                        listAnimation: centerAnimation,
                        largeListAnimation: reaction.activateAnimation,
                        applicationAnimation: aroundAnimation,
                        largeApplicationAnimation: reaction.effectAnimation,
                        isCustom: false
                    ))
                } else {
                    continue
                }
            case let .custom(file):
                switch allowedReactionsAndFiles.reactions {
                case let .set(set):
                    if !set.contains(.custom(file.fileId.id)) {
                        continue
                    }
                case .all:
                    break
                }
                
                if existingIds.contains(.custom(file.fileId.id)) {
                    continue
                }
                existingIds.insert(.custom(file.fileId.id))
                
                result.append(ReactionItem(
                    reaction: ReactionItem.Reaction(rawValue: .custom(file.fileId.id)),
                    appearAnimation: file,
                    stillAnimation: file,
                    listAnimation: file,
                    largeListAnimation: file,
                    applicationAnimation: nil,
                    largeApplicationAnimation: nil,
                    isCustom: true
                ))
            case .stars:
                break
            }
        }
        
        for reaction in availableReactions.reactions {
            guard let centerAnimation = reaction.centerAnimation else {
                continue
            }
            guard let aroundAnimation = reaction.aroundAnimation else {
                continue
            }
            if !reaction.isEnabled {
                continue
            }

            switch allowedReactionsAndFiles.reactions {
            case let .set(set):
                if !set.contains(reaction.value) {
                    continue
                }
            case .all:
                continue
            }
            
            if existingIds.contains(reaction.value) {
                continue
            }
            existingIds.insert(reaction.value)
            
            result.append(ReactionItem(
                reaction: ReactionItem.Reaction(rawValue: reaction.value),
                appearAnimation: reaction.appearAnimation,
                stillAnimation: reaction.selectAnimation,
                listAnimation: centerAnimation,
                largeListAnimation: reaction.activateAnimation,
                applicationAnimation: aroundAnimation,
                largeApplicationAnimation: reaction.effectAnimation,
                isCustom: false
            ))
        }
        
        if case let .set(reactions) = allowedReactionsAndFiles.reactions {
            for reaction in reactions {
                if existingIds.contains(reaction) {
                    continue
                }
                existingIds.insert(reaction)
                
                switch reaction {
                case .builtin:
                    break
                case let .custom(fileId):
                    if let file = allowedReactionsAndFiles.files[fileId] {
                        let file = TelegramMediaFile.Accessor(file)
                        result.append(ReactionItem(
                            reaction: ReactionItem.Reaction(rawValue: .custom(file.fileId.id)),
                            appearAnimation: file,
                            stillAnimation: file,
                            listAnimation: file,
                            largeListAnimation: file,
                            applicationAnimation: nil,
                            largeApplicationAnimation: nil,
                            isCustom: true
                        ))
                    }
                case .stars:
                    break
                }
            }
        }
        
        if allowedReactionsAndFiles.areStarsEnabled {
            result.removeAll(where: { $0.reaction.rawValue == .stars })
            if let reaction = availableReactions.reactions.first(where: { $0.value == .stars }) {
                if let centerAnimation = reaction.centerAnimation, let aroundAnimation = reaction.aroundAnimation {
                    existingIds.insert(reaction.value)
                    
                    result.insert(ReactionItem(
                        reaction: ReactionItem.Reaction(rawValue: reaction.value),
                        appearAnimation: reaction.appearAnimation,
                        stillAnimation: reaction.selectAnimation,
                        listAnimation: centerAnimation,
                        largeListAnimation: reaction.activateAnimation,
                        applicationAnimation: aroundAnimation,
                        largeApplicationAnimation: reaction.effectAnimation,
                        isCustom: false
                    ), at: 0)
                }
            }
        }

        return result
    }
}

public func effectMessageReactions(context: AccountContext) -> Signal<[ReactionItem], NoError> {
    return context.engine.stickers.availableMessageEffects()
    |> take(1)
    |> map { availableMessageEffects -> [ReactionItem] in
        guard let availableMessageEffects else {
            return []
        }
        
        var result: [ReactionItem] = []
        var existingIds = Set<Int64>()
        
        for messageEffect in availableMessageEffects.messageEffects {
            if existingIds.contains(messageEffect.id) {
                continue
            }
            existingIds.insert(messageEffect.id)
            
            let mainFile = TelegramMediaFile.Accessor(messageEffect.effectSticker)
            
            result.append(ReactionItem(
                reaction: ReactionItem.Reaction(rawValue: .custom(messageEffect.id)),
                appearAnimation: mainFile,
                stillAnimation: mainFile,
                listAnimation: mainFile,
                largeListAnimation: mainFile,
                applicationAnimation: nil,
                largeApplicationAnimation: nil,
                isCustom: true
            ))
        }

        return result
    }
}
