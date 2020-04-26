import Foundation
import UIKit
import SwiftSignalKit
import ContextUI
import AccountContext
import Postbox
import TelegramCore
import SyncCore
import Display
import TelegramUIPreferences
import OverlayStatusController
import AlertUI
import PresentationDataUtils

func archiveContextMenuItems(context: AccountContext, groupId: PeerGroupId, chatListController: ChatListControllerImpl?) -> Signal<[ContextMenuItem], NoError> {
    let strings = context.sharedContext.currentPresentationData.with({ $0 }).strings
    return context.account.postbox.transaction { [weak chatListController] transaction -> [ContextMenuItem] in
        var items: [ContextMenuItem] = []
        
        if !transaction.getUnreadChatListPeerIds(groupId: groupId, filterPredicate: nil).isEmpty {
            items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_MarkAllAsRead, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/MarkAsRead"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                let _ = (context.account.postbox.transaction { transaction in
                    markAllChatsAsReadInteractively(transaction: transaction, viewTracker: context.account.viewTracker, groupId: groupId, filterPredicate: nil)
                }
                |> deliverOnMainQueue).start(completed: {
                    f(.default)
                })
            })))
        }
        
        let settings = transaction.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.chatArchiveSettings) as? ChatArchiveSettings ?? ChatArchiveSettings.default
        let isPinned = !settings.isHiddenByDefault
        items.append(.action(ContextMenuActionItem(text: isPinned ? strings.ChatList_Context_HideArchive : strings.ChatList_Context_UnhideArchive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: isPinned ? "Chat/Context Menu/Unpin": "Chat/Context Menu/Pin"), color: theme.contextMenu.primaryColor) }, action: { [weak chatListController] _, f in
            chatListController?.toggleArchivedFolderHiddenByDefault()
            f(.default)
        })))
        
        return items
    }
}

enum ChatContextMenuSource {
    case chatList(filter: ChatListFilter?)
    case search(ChatListSearchContextActionSource)
}

func chatContextMenuItems(context: AccountContext, peerId: PeerId, promoInfo: ChatListNodeEntryPromoInfo?, source: ChatContextMenuSource, chatListController: ChatListControllerImpl?) -> Signal<[ContextMenuItem], NoError> {
    let strings = context.sharedContext.currentPresentationData.with({ $0 }).strings
    return context.account.postbox.transaction { [weak chatListController] transaction -> [ContextMenuItem] in
        if promoInfo != nil {
            return []
        }
        
        var items: [ContextMenuItem] = []
        
        if case let .search(search) = source {
            switch search {
            case .recentPeers:
                items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_RemoveFromRecents, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.contextMenu.destructiveColor) }, action: { _, f in
                    let _ = (removeRecentPeer(account: context.account, peerId: peerId)
                    |> deliverOnMainQueue).start(completed: {
                        f(.default)
                    })
                })))
                items.append(.separator)
            case .recentSearch:
                items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_RemoveFromRecents, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.contextMenu.destructiveColor) }, action: { _, f in
                    let _ = (removeRecentlySearchedPeer(postbox: context.account.postbox, peerId: peerId)
                    |> deliverOnMainQueue).start(completed: {
                        f(.default)
                    })
                })))
                items.append(.separator)
            case .search:
                break
            }
        }
        
        let isSavedMessages = peerId == context.account.peerId
        
        let chatPeer = transaction.getPeer(peerId)
        var peer: Peer?
        if let chatPeer = chatPeer {
            if let chatPeer = chatPeer as? TelegramSecretChat {
                peer = transaction.getPeer(chatPeer.regularPeerId)
            } else {
                peer = chatPeer
            }
        }
        
        if !isSavedMessages, let peer = peer as? TelegramUser, !peer.flags.contains(.isSupport) && peer.botInfo == nil && !peer.isDeleted {
            if !transaction.isPeerContact(peerId: peer.id) {
                items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_AddToContacts, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/AddUser"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                    context.sharedContext.openAddPersonContact(context: context, peerId: peerId, pushController: { controller in
                        if let navigationController = chatListController?.navigationController as? NavigationController {
                            navigationController.pushViewController(controller)
                        }
                    }, present: { c, a in
                        if let chatListController = chatListController {
                            chatListController.present(c, in: .window(.root), with: a)
                        }
                    })
                    f(.default)
                })))
                items.append(.separator)
            }
        }
        
        if case .chatList = source {
            if let readState = transaction.getCombinedPeerReadState(peerId), readState.isUnread {
                items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_MarkAsRead, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/MarkAsRead"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                    let _ = togglePeerUnreadMarkInteractively(postbox: context.account.postbox, viewTracker: context.account.viewTracker, peerId: peerId).start()
                    f(.default)
                })))
            } else {
                items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_MarkAsUnread, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/MarkAsUnread"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                    let _ = togglePeerUnreadMarkInteractively(postbox: context.account.postbox, viewTracker: context.account.viewTracker, peerId: peerId).start()
                    f(.default)
                })))
            }
        }
        
        let groupAndIndex = transaction.getPeerChatListIndex(peerId)
        
        let archiveEnabled = !isSavedMessages && peerId != PeerId(namespace: Namespaces.Peer.CloudUser, id: 777000) && peerId == context.account.peerId
        if let (group, index) = groupAndIndex {
            if archiveEnabled {
                let isArchived = group == Namespaces.PeerGroup.archive
                items.append(.action(ContextMenuActionItem(text: isArchived ? strings.ChatList_Context_Unarchive : strings.ChatList_Context_Archive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: isArchived ? "Chat/Context Menu/Unarchive" : "Chat/Context Menu/Archive"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                    if isArchived {
                        let _ = (context.account.postbox.transaction { transaction -> Void in
                            updatePeerGroupIdInteractively(transaction: transaction, peerId: peerId, groupId: .root)
                            }
                        |> deliverOnMainQueue).start(completed: {
                            f(.default)
                        })
                    } else {
                        if let chatListController = chatListController {
                            chatListController.archiveChats(peerIds: [peerId])
                            f(.default)
                        } else {
                            let _ = (context.account.postbox.transaction { transaction -> Void in
                                updatePeerGroupIdInteractively(transaction: transaction, peerId: peerId, groupId: Namespaces.PeerGroup.archive)
                            }
                            |> deliverOnMainQueue).start(completed: {
                                f(.default)
                            })
                        }
                    }
                })))
            }
            
            if case let .chatList(filter) = source {
                let location: TogglePeerChatPinnedLocation
                if let filter = filter {
                    location = .filter(filter.id)
                } else {
                    location = .group(group)
                }
                
                let isPinned = getPinnedItemIds(transaction: transaction, location: location).contains(.peer(peerId))
                
                items.append(.action(ContextMenuActionItem(text: isPinned ? strings.ChatList_Context_Unpin : strings.ChatList_Context_Pin, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: isPinned ? "Chat/Context Menu/Unpin" : "Chat/Context Menu/Pin"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                    let _ = (toggleItemPinned(postbox: context.account.postbox, location: location, itemId: .peer(peerId))
                    |> deliverOnMainQueue).start(next: { result in
                        switch result {
                        case .done:
                            break
                        case .limitExceeded:
                            break
                        }
                        f(.default)
                    })
                })))
            }
        
            if !isSavedMessages, let notificationSettings = transaction.getPeerNotificationSettings(peerId) as? TelegramPeerNotificationSettings {
                var isMuted = false
                if case .muted = notificationSettings.muteState {
                    isMuted = true
                }
                items.append(.action(ContextMenuActionItem(text: isMuted ? strings.ChatList_Context_Unmute : strings.ChatList_Context_Mute, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: isMuted ? "Chat/Context Menu/Unmute" : "Chat/Context Menu/Muted"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                    let _ = (togglePeerMuted(account: context.account, peerId: peerId)
                    |> deliverOnMainQueue).start(completed: {
                        f(.default)
                    })
                })))
            }
        } else {
            if case .search = source {
                if let _ = peer as? TelegramChannel {
                    items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_JoinChannel, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Add"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                        var createSignal = context.peerChannelMemberCategoriesContextsManager.join(account: context.account, peerId: peerId)
                        var cancelImpl: (() -> Void)?
                        let progressSignal = Signal<Never, NoError> { subscriber in
                            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                            let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                                cancelImpl?()
                            }))
                            chatListController?.present(controller, in: .window(.root))
                            return ActionDisposable { [weak controller] in
                                Queue.mainQueue().async() {
                                    controller?.dismiss()
                                }
                            }
                        }
                        |> runOn(Queue.mainQueue())
                        |> delay(0.15, queue: Queue.mainQueue())
                        let progressDisposable = progressSignal.start()
                        
                        createSignal = createSignal
                        |> afterDisposed {
                            Queue.mainQueue().async {
                                progressDisposable.dispose()
                            }
                        }
                        let joinChannelDisposable = MetaDisposable()
                        cancelImpl = {
                            joinChannelDisposable.set(nil)
                        }
                        
                        joinChannelDisposable.set((createSignal
                        |> deliverOnMainQueue).start(next: { _ in
                            if let navigationController = (chatListController?.navigationController as? NavigationController) {
                                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peerId)))
                            }
                        }, error: { _ in
                            if let chatListController = chatListController {
                                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                chatListController.present(textAlertController(context: context, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                            }
                        }))
                        f(.default)
                    })))
                }
            }
        }
        
        if case .chatList = source, groupAndIndex != nil {
            items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_Delete, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { _, f in
                if let chatListController = chatListController {
                    chatListController.deletePeerChat(peerId: peerId)
                }
                f(.default)
            })))
        }
        
        if let item = items.last, case .separator = item {
            items.removeLast()
        }
        
        return items
    }
}
