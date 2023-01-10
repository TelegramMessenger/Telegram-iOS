import Foundation
import SwiftSignalKit
import TelegramCore
import Postbox
import AccountContext
import ReactionSelectionNode

func topMessageReactions(context: AccountContext, message: Message) -> Signal<[ReactionItem], NoError> {
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
    
    let allowedReactionsWithFiles: Signal<(reactions: AllowedReactions, files: [Int64: TelegramMediaFile])?, NoError> = peerMessageAllowedReactions(context: context, message: message)
    |> mapToSignal { allowedReactions -> Signal<(reactions: AllowedReactions, files: [Int64: TelegramMediaFile])?, NoError> in
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
                }
            })
            |> map { files -> (reactions: AllowedReactions, files: [Int64: TelegramMediaFile]) in
                return (allowedReactions, files)
            }
        } else {
            return .single((allowedReactions, [:]))
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
                }
            }
        }

        return result
    }
}
