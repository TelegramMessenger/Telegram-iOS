import Foundation
import UIKit
import Display
import TelegramCore
import TelegramPresentationData
import AccountContext
import AvatarNode
import ComponentFlow
import AlertComponent
import AlertHeaderComponent
import AvatarComponent

public func deleteChatPeerAlertContent(context: AccountContext, peer: EnginePeer, chatPeer: EnginePeer, action: DeleteChatPeerAction?, title: String? = nil) -> [AnyComponentWithIdentity<AlertComponentEnvironment>] {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings

    var overrideImage: AvatarNodeImageOverride?
    if chatPeer.id == context.account.peerId {
        overrideImage = .savedMessagesIcon
    } else if chatPeer.id.isReplies {
        overrideImage = .repliesIcon
    } else if chatPeer.id.isAnonymousSavedMessages {
        overrideImage = .anonymousSavedMessagesIcon(isColored: true)
    } else if chatPeer.isDeleted {
        overrideImage = .deletedIcon
    }

    var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
    content.append(AnyComponentWithIdentity(
        id: "header",
        component: AnyComponent(
            AlertHeaderComponent(
                component: AnyComponentWithIdentity(id: "avatar", component: AnyComponent(
                    AvatarComponent(
                        context: context,
                        theme: presentationData.theme,
                        peer: peer,
                        overrideImage: overrideImage
                    )
                ))
            )
        )
    ))

    let resolvedTitle: String?
    if let title {
        resolvedTitle = title
    } else if let action {
        switch action {
        case .delete, .deleteAndLeave, .deleteSavedPeer:
            resolvedTitle = strings.ChatList_DeleteChat
        case .clearHistory:
            resolvedTitle = strings.DialogList_ClearHistoryConfirmation
        case .clearCache, .clearCacheSuggestion:
            resolvedTitle = strings.Conversation_ClearCache
        case .removeFromGroup, .removeFromChannel:
            resolvedTitle = nil
        }
    } else {
        resolvedTitle = peer.displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder)
    }
    if let resolvedTitle {
        content.append(AnyComponentWithIdentity(
            id: "title",
            component: AnyComponent(
                AlertTitleComponent(title: resolvedTitle)
            )
        ))
    }

    if let action, let text = deleteChatPeerConfirmationText(context: context, peer: peer, chatPeer: chatPeer, action: action, strings: strings, nameDisplayOrder: presentationData.nameDisplayOrder) {
        let markdownText = NSMutableString(string: text.string)
        for range in text.ranges.map({ $0.range }).sorted(by: { $0.location > $1.location }) {
            markdownText.insert("**", at: range.location + range.length)
            markdownText.insert("**", at: range.location)
        }
        content.append(AnyComponentWithIdentity(
            id: "text",
            component: AnyComponent(
                AlertTextComponent(content: .plain(markdownText as String))
            )
        ))
    }

    return content
}

public func deleteChatPeerAlertScreen(context: AccountContext, peer: EnginePeer, chatPeer: EnginePeer, action: DeleteChatPeerAction?, title: String? = nil, actions: [AlertScreen.Action]) -> AlertScreen {
    return AlertScreen(
        context: context,
        configuration: AlertScreen.Configuration(actionAlignment: .vertical),
        content: deleteChatPeerAlertContent(context: context, peer: peer, chatPeer: chatPeer, action: action, title: title),
        actions: actions
    )
}
