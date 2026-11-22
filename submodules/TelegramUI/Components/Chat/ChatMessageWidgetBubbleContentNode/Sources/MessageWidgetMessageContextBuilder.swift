import Foundation
import TelegramCore
import MessageWidget

/// The context of a widget message (widget-sandbox v0.2, sdk-v1 §2.13, §2.14; the v0.2 design §4 call 10): the media's
/// server flags as they are (the client derives none), the chat's type from its peer, and the account as the viewer.
/// The runtime strips what the widget may not see. `isPreview` is false here: an inline result's preview sets it.
/// `wallet` (v0.5.0, sdk-v1 §5.13): the client has Gram Wallet for the account's user (`MessageWidgetWalletAvailability`).
public func messageWidgetContext(widget: TelegramMediaWidget, chatPeer: EnginePeer?, accountPeer: EnginePeer?, accountPeerId: EnginePeer.Id, wallet: Bool = false) -> MessageWidgetContext {
    return MessageWidgetContext(isCopy: widget.isCopy, canQuery: widget.canQuery, backgroundQuery: widget.backgroundQuery, chatType: messageWidgetChatType(chatPeer), viewer: messageWidgetViewer(accountPeer: accountPeer, accountPeerId: accountPeerId), wallet: wallet)
}

/// The Bot API's `Chat.type` of a peer: a user and a secret chat are private, a basic group is a group, a channel a
/// supergroup or a channel; none for anything else.
func messageWidgetChatType(_ peer: EnginePeer?) -> MessageWidgetChatType? {
    switch peer {
    case .user, .secretChat:
        return .private
    case .legacyGroup:
        return .group
    case let .channel(channel):
        if case .broadcast = channel.info {
            return .channel
        }
        return .supergroup
    case .community, .none:
        return nil
    }
}

/// The account's own user as Mini Apps' WebAppUser; the id alone while the history list has not yet filled the account
/// peer (it comes from a signal).
func messageWidgetViewer(accountPeer: EnginePeer?, accountPeerId: EnginePeer.Id) -> MessageWidgetViewer {
    if case let .user(user)? = accountPeer {
        return MessageWidgetViewer(id: user.id.id._internalGetInt64Value(), firstName: user.firstName, lastName: user.lastName, username: user.addressName, isPremium: user.isPremium)
    }
    return MessageWidgetViewer(id: accountPeerId.id._internalGetInt64Value())
}
