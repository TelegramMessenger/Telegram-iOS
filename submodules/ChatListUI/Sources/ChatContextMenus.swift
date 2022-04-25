import Foundation
import UIKit
import SwiftSignalKit
import ContextUI
import AccountContext
import Postbox
import TelegramCore
import Display
import TelegramUIPreferences
import OverlayStatusController
import AlertUI
import PresentationDataUtils
import UndoUI

func archiveContextMenuItems(context: AccountContext, groupId: PeerGroupId, chatListController: ChatListControllerImpl?) -> Signal<[ContextMenuItem], NoError> {
    let presentationData = context.sharedContext.currentPresentationData.with({ $0 })
    let strings = presentationData.strings
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
        
        let settings = transaction.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.chatArchiveSettings)?.get(ChatArchiveSettings.self) ?? ChatArchiveSettings.default
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

func chatContextMenuItems(context: AccountContext, peerId: PeerId, promoInfo: ChatListNodeEntryPromoInfo?, source: ChatContextMenuSource, chatListController: ChatListControllerImpl?, joined: Bool) -> Signal<[ContextMenuItem], NoError> {
    let presentationData = context.sharedContext.currentPresentationData.with({ $0 })
    let strings = presentationData.strings

    return combineLatest(
        context.account.postbox.transaction { transaction -> (PeerGroupId, ChatListIndex)? in
            transaction.getPeerChatListIndex(peerId)
        },
        context.engine.peers.recentlySearchedPeers() |> take(1)
    )
    |> mapToSignal { groupAndIndex, recentlySearchedPeers -> Signal<[ContextMenuItem], NoError> in
        let location: TogglePeerChatPinnedLocation
        var chatListFilter: ChatListFilter?
        if case let .chatList(filter) = source, let chatFilter = filter {
            chatListFilter = chatFilter
            location = .filter(chatFilter.id)
        } else {
            if let (group, _) = groupAndIndex {
                location = .group(group)
            } else {
                location = .group(.root)
            }
        }

        return combineLatest(
            context.engine.peers.updatedChatListFilters()
            |> take(1),
            context.engine.peers.getPinnedItemIds(location: location)
        )
        |> mapToSignal { filters, pinnedItemIds -> Signal<[ContextMenuItem], NoError> in
            let isPinned = pinnedItemIds.contains(.peer(peerId))

            return context.account.postbox.transaction { [weak chatListController] transaction -> [ContextMenuItem] in
                if promoInfo != nil {
                    return []
                }

                var items: [ContextMenuItem] = []

                if case let .search(search) = source {
                    switch search {
                    case .recentPeers:
                        items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_RemoveFromRecents, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.contextMenu.destructiveColor) }, action: { _, f in
                            let _ = (context.engine.peers.removeRecentPeer(peerId: peerId)
                            |> deliverOnMainQueue).start(completed: {
                                f(.default)
                            })
                        })))
                        items.append(.separator)
                    case .recentSearch:
                        items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_RemoveFromRecents, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.contextMenu.destructiveColor) }, action: { _, f in
                            let _ = (context.engine.peers.removeRecentlySearchedPeer(peerId: peerId)
                            |> deliverOnMainQueue).start(completed: {
                                f(.default)
                            })
                        })))
                        items.append(.separator)
                    case .search:
                        if recentlySearchedPeers.contains(where: { $0.peer.peerId == peerId }) {
                            items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_RemoveFromRecents, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.contextMenu.destructiveColor) }, action: { _, f in
                                let _ = (context.engine.peers.removeRecentlySearchedPeer(peerId: peerId)
                                |> deliverOnMainQueue).start(completed: {
                                    f(.default)
                                })
                            })))
                            items.append(.separator)
                        }
                    }
                }

                let isSavedMessages = peerId == context.account.peerId

                let chatPeer = transaction.getPeer(peerId)
                var maybePeer: Peer?
                if let chatPeer = chatPeer {
                    if let chatPeer = chatPeer as? TelegramSecretChat {
                        maybePeer = transaction.getPeer(chatPeer.regularPeerId)
                    } else {
                        maybePeer = chatPeer
                    }
                }

                guard let peer = maybePeer else {
                    return []
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

                var isMuted = false
                if let notificationSettings = transaction.getPeerNotificationSettings(peerId) as? TelegramPeerNotificationSettings {
                    if case .muted = notificationSettings.muteState {
                        isMuted = true
                    }
                }

                var isUnread = false
                if let readState = transaction.getCombinedPeerReadState(peerId), readState.isUnread {
                    isUnread = true
                }

                let isContact = transaction.isPeerContact(peerId: peerId)

                if case let .chatList(currentFilter) = source {
                    if let currentFilter = currentFilter {
                        items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_RemoveFromFolder, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/RemoveFromFolder"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                            let _ = (context.engine.peers.updateChatListFiltersInteractively { filters in
                                var filters = filters
                                for i in 0 ..< filters.count {
                                    if filters[i].id == currentFilter.id {
                                        let _ = filters[i].data.addExcludePeer(peerId: peer.id)
                                        break
                                    }
                                }
                                return filters
                            }
                            |> deliverOnMainQueue).start(completed: {
                                c.dismiss(completion: {
                                    chatListController?.present(UndoOverlayController(presentationData: presentationData, content: .chatRemovedFromFolder(chatTitle: EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), folderTitle: currentFilter.title), elevatedLayout: false, animateInAsReplacement: true, action: { _ in
                                        return false
                                    }), in: .current)
                                })
                            })
                        })))
                    } else {
                        var hasFolders = false

                        for filter in filters {
                            let predicate = chatListFilterPredicate(filter: filter.data)
                            if predicate.includes(peer: peer, groupId: .root, isRemovedFromTotalUnreadCount: isMuted, isUnread: isUnread, isContact: isContact, messageTagSummaryResult: false) {
                                continue
                            }

                            var data = filter.data
                            if data.addIncludePeer(peerId: peer.id) {
                                hasFolders = true
                                break
                            }
                        }

                        if hasFolders {
                            items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_AddToFolder, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Folder"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                                var updatedItems: [ContextMenuItem] = []

                                for filter in filters {
                                    let predicate = chatListFilterPredicate(filter: filter.data)
                                    if predicate.includes(peer: peer, groupId: .root, isRemovedFromTotalUnreadCount: isMuted, isUnread: isUnread, isContact: isContact, messageTagSummaryResult: false) {
                                        continue
                                    }

                                    var data = filter.data
                                    if !data.addIncludePeer(peerId: peer.id) {
                                        continue
                                    }

                                    let filterType = chatListFilterType(filter)
                                    updatedItems.append(.action(ContextMenuActionItem(text: filter.title, icon: { theme in
                                        let imageName: String
                                        switch filterType {
                                        case .generic:
                                            imageName = "Chat/Context Menu/List"
                                        case .unmuted:
                                            imageName = "Chat/Context Menu/Unmute"
                                        case .unread:
                                            imageName = "Chat/Context Menu/MarkAsUnread"
                                        case .channels:
                                            imageName = "Chat/Context Menu/Channels"
                                        case .groups:
                                            imageName = "Chat/Context Menu/Groups"
                                        case .bots:
                                            imageName = "Chat/Context Menu/Bots"
                                        case .contacts:
                                            imageName = "Chat/Context Menu/User"
                                        case .nonContacts:
                                            imageName = "Chat/Context Menu/UnknownUser"
                                        }
                                        return generateTintedImage(image: UIImage(bundleImageName: imageName), color: theme.contextMenu.primaryColor)
                                    }, action: { c, f in
                                        c.dismiss(completion: {
                                            let _ = (context.engine.peers.updateChatListFiltersInteractively { filters in
                                                var filters = filters
                                                for i in 0 ..< filters.count {
                                                    if filters[i].id == filter.id {
                                                        let _ = filters[i].data.addIncludePeer(peerId: peer.id)
                                                        break
                                                    }
                                                }
                                                return filters
                                            }).start()

                                            chatListController?.present(UndoOverlayController(presentationData: presentationData, content: .chatAddedToFolder(chatTitle: EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), folderTitle: filter.title), elevatedLayout: false, animateInAsReplacement: true, action: { _ in
                                                return false
                                            }), in: .current)
                                        })
                                    })))
                                }

                                updatedItems.append(.separator)
                                updatedItems.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_Back, icon: { theme in
                                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.contextMenu.primaryColor)
                                }, action: { c, _ in
                                    c.setItems(chatContextMenuItems(context: context, peerId: peerId, promoInfo: promoInfo, source: source, chatListController: chatListController, joined: joined) |> map { ContextController.Items(content: .list($0)) }, minHeight: nil)
                                })))

                                c.setItems(.single(ContextController.Items(content: .list(updatedItems))), minHeight: nil)
                            })))
                        }
                    }
                }

                if isUnread {
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

                let archiveEnabled = !isSavedMessages && peerId != PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(777000)) && peerId == context.account.peerId
                if let (group, _) = groupAndIndex {
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

                    if isPinned || chatListFilter == nil || peerId.namespace != Namespaces.Peer.SecretChat {
                        items.append(.action(ContextMenuActionItem(text: isPinned ? strings.ChatList_Context_Unpin : strings.ChatList_Context_Pin, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: isPinned ? "Chat/Context Menu/Unpin" : "Chat/Context Menu/Pin"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                            let _ = (context.engine.peers.toggleItemPinned(location: location, itemId: .peer(peerId))
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
                            let _ = (context.engine.peers.togglePeerMuted(peerId: peerId)
                            |> deliverOnMainQueue).start(completed: {
                                f(.default)
                            })
                        })))
                    }
                } else {
                    if case .search = source {
                        if let peer = peer as? TelegramChannel {
                            let text: String
                            if case .broadcast = peer.info {
                                text = strings.ChatList_Context_JoinChannel
                            } else {
                                text = strings.ChatList_Context_JoinChat
                            }
                            items.append(.action(ContextMenuActionItem(text: text, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Add"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                                var createSignal = context.peerChannelMemberCategoriesContextsManager.join(engine: context.engine, peerId: peerId, hash: nil)
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
                                }, error: { _ in
                                    if let chatListController = chatListController {
                                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                        chatListController.present(textAlertController(context: context, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                    }
                                }, completed: {
                                    if let navigationController = (chatListController?.navigationController as? NavigationController) {
                                        context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(id: peerId)))
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
                            chatListController.deletePeerChat(peerId: peerId, joined: joined)
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
    }
}
