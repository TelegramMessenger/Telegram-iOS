import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext

func peerMessageSelectedReactions(context: AccountContext, message: Message) -> Signal<(reactions: Set<MessageReaction.Reaction>, files: Set<MediaId>), NoError> {
    return context.engine.stickers.availableReactions()
    |> take(1)
    |> map { availableReactions -> (reactions: Set<MessageReaction.Reaction>, files: Set<MediaId>) in
        var result = Set<MediaId>()
        var reactions = Set<MessageReaction.Reaction>()
        
        if let effectiveReactions = message.effectiveReactions(isTags: message.areReactionsTags(accountPeerId: context.account.peerId)) {
            for reaction in effectiveReactions {
                if !reaction.isSelected {
                    continue
                }
                if case .stars = reaction.value {
                    continue
                }
                reactions.insert(reaction.value)
                switch reaction.value {
                case .builtin, .stars:
                    if let availableReaction = availableReactions?.reactions.first(where: { $0.value == reaction.value }) {
                        result.insert(availableReaction.selectAnimation.fileId)
                    }
                case let .custom(fileId):
                    result.insert(MediaId(namespace: Namespaces.Media.CloudFile, id: fileId))
                }
            }
        }
        
        return (reactions, result)
    }
}
