import Foundation
import TelegramCore
import AccountContext
import ChatPresentationInterfaceState

/// The side list this chat shows its sidebar button for, or nil. The navigation buttons and the topics strips both ask
/// this, so the button and the strip never show together.
func chatSideListKindForChatPresentationInterfaceState(_ state: ChatPresentationInterfaceState, context: AccountContext) -> ChatSideListKind? {
    guard let peerId = state.chatLocation.peerId else {
        return nil
    }
    if case .standard(.default) = state.mode {
    } else {
        return nil
    }
    if state.subject != nil {
        return nil
    }
    let peer = state.renderedPeer?.peers[peerId] ?? state.renderedPeer?.peer
    var isForum = false
    var isSidebarForum = false
    var isMonoforum = false
    var isAdminMonoforum = false
    var isSidebarBot = false
    if let channel = peer as? TelegramChannel {
        isForum = channel.isForum
        isSidebarForum = channel.isForum && state.viewForumAsMessages && channel.flags.contains(.displayForumAsSidebar)
        isMonoforum = channel.isMonoForum
        if channel.isMonoForum, let linkedMonoforumId = channel.linkedMonoforumId, let mainChannel = state.renderedPeer?.peers[linkedMonoforumId] as? TelegramChannel, mainChannel.hasPermission(.manageDirect) {
            isAdminMonoforum = true
        }
    } else if let user = peer as? TelegramUser, let botInfo = user.botInfo, botInfo.flags.contains(.hasForum), botInfo.flags.contains(.displayForumAsSidebar) {
        isSidebarBot = true
    }
    // Saved Messages without sub-chats has nothing to list; a sub-chat always has at least itself.
    if peerId == context.account.peerId, case .peer = state.chatLocation, !state.hasSavedChats {
        return nil
    }
    return chatSideListKind(
        peerId: peerId,
        accountPeerId: context.account.peerId,
        isForum: isForum,
        isSidebarForum: isSidebarForum,
        isMonoforum: isMonoforum,
        isAdminMonoforum: isAdminMonoforum,
        isSidebarBot: isSidebarBot,
        enabled: context.usesChatSideList
    )
}
