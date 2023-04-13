import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import ItemListUI
import PresentationDataUtils
import OverlayStatusController
import AccountContext
import ItemListPeerItem
import UndoUI
import ContextUI
import ItemListPeerActionItem

private enum StorageUsageExceptionsEntryTag: Hashable, ItemListItemTag {
    case peer(EnginePeer.Id)
    
    public func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? StorageUsageExceptionsEntryTag, self == other {
            return true
        } else {
            return false
        }
    }
}

private final class StorageUsageExceptionsScreenArguments {
    let context: AccountContext
    let openAddException: () -> Void
    let openPeerMenu: (EnginePeer.Id, Int32) -> Void
    
    init(
        context: AccountContext,
        openAddException: @escaping () -> Void,
        openPeerMenu: @escaping (EnginePeer.Id, Int32) -> Void
    ) {
        self.context = context
        self.openAddException = openAddException
        self.openPeerMenu = openPeerMenu
    }
}

private enum StorageUsageExceptionsSection: Int32 {
    case add
    case items
}

private enum StorageUsageExceptionsEntry: ItemListNodeEntry {
    enum SortIndex: Equatable, Comparable {
        case index(Int)
        case peer(index: Int, peerId: EnginePeer.Id)
        
        static func <(lhs: SortIndex, rhs: SortIndex) -> Bool {
            switch lhs {
            case let .index(index):
                if case let .index(rhsIndex) = rhs {
                    return index < rhsIndex
                } else {
                    return true
                }
            case let .peer(index, peerId):
                if case let .peer(rhsIndex, rhsPeerId) = rhs {
                    if index != rhsIndex {
                        return index < rhsIndex
                    } else {
                        return peerId < rhsPeerId
                    }
                } else {
                    return false
                }
            }
        }
    }
    
    enum StableId: Hashable {
        case index(Int)
        case peer(EnginePeer.Id)
    }
    
    case addException(String)
    case exceptionsHeader(String)
    case peer(index: Int, peer: FoundPeer, value: Int32)
    
    var section: ItemListSectionId {
        switch self {
        case .addException:
            return StorageUsageExceptionsSection.add.rawValue
        case .exceptionsHeader, .peer:
            return StorageUsageExceptionsSection.items.rawValue
        }
    }
    
    var stableId: StableId {
        switch self {
        case .addException:
            return .index(0)
        case .exceptionsHeader:
            return .index(1)
        case let .peer(_, peer, _):
            return .peer(peer.peer.id)
        }
    }
    
    var sortIndex: SortIndex {
        switch self {
        case .addException:
            return .index(0)
        case .exceptionsHeader:
            return .index(1)
        case let .peer(index, peer, _):
            return .peer(index: index, peerId: peer.peer.id)
        }
    }
    
    static func ==(lhs: StorageUsageExceptionsEntry, rhs: StorageUsageExceptionsEntry) -> Bool {
        switch lhs {
        case let .addException(text):
            if case .addException(text) = rhs {
                return true
            } else {
                return false
            }
        case let .exceptionsHeader(text):
            if case .exceptionsHeader(text) = rhs {
                return true
            } else {
                return false
            }
        case let .peer(index, peer, value):
            if case .peer(index, peer, value) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: StorageUsageExceptionsEntry, rhs: StorageUsageExceptionsEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! StorageUsageExceptionsScreenArguments
        switch self {
        case let .addException(text):
            let icon: UIImage? = PresentationResourcesItemList.createGroupIcon(presentationData.theme)
            return ItemListPeerActionItem(presentationData: presentationData, icon: icon, title: text, alwaysPlain: false, sectionId: self.section, editing: false, action: {
                arguments.openAddException()
            })
        case let .exceptionsHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .peer(_, peer, value):
            var additionalDetailLabel: String?
            if let subscribers = peer.subscribers {
                additionalDetailLabel = presentationData.strings.VoiceChat_Panel_Members(subscribers)
            }
            let optionText: String
            if value == Int32.max {
                optionText = presentationData.strings.ClearCache_Forever
            } else {
                optionText = timeIntervalString(strings: presentationData.strings, value: value)
            }
            
            let title: String
            if peer.peer.id == arguments.context.account.peerId {
                title = presentationData.strings.DialogList_SavedMessages
            } else {
                title = EnginePeer(peer.peer).displayTitle(strings: presentationData.strings, displayOrder: .firstLast)
            }
            
            return ItemListDisclosureItem(presentationData: presentationData, icon: nil, context: arguments.context, iconPeer: EnginePeer(peer.peer), title: title, enabled: true, titleFont: .bold, label: optionText, labelStyle: .text, additionalDetailLabel: additionalDetailLabel, sectionId: self.section, style: .blocks, disclosureStyle: .optionArrows, action: {
                arguments.openPeerMenu(peer.peer.id, value)
            }, tag: StorageUsageExceptionsEntryTag.peer(peer.peer.id))
        }
    }
}

private struct StorageUsageExceptionsState: Equatable {
}

private func storageUsageExceptionsScreenEntries(
    presentationData: PresentationData,
    peerExceptions: [(peer: FoundPeer, value: Int32)],
    state: StorageUsageExceptionsState
) -> [StorageUsageExceptionsEntry] {
    var entries: [StorageUsageExceptionsEntry] = []
    
    entries.append(.addException(presentationData.strings.Notification_Exceptions_AddException))
    
    if !peerExceptions.isEmpty {
        entries.append(.exceptionsHeader(presentationData.strings.Notifications_CategoryExceptions(Int32(peerExceptions.count)).uppercased()))
        
        var index = 100
        for item in peerExceptions {
            entries.append(.peer(index: index, peer: item.peer, value: item.value))
            index += 1
        }
    }
    
    return entries
}

public func storageUsageExceptionsScreen(
    context: AccountContext,
    category: CacheStorageSettings.PeerStorageCategory,
    isModal: Bool = false
) -> ViewController {
    let statePromise = ValuePromise(StorageUsageExceptionsState())
    let stateValue = Atomic(value: StorageUsageExceptionsState())
    let updateState: ((StorageUsageExceptionsState) -> StorageUsageExceptionsState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    let _ = updateState
    
    let cacheSettingsPromise = Promise<CacheStorageSettings>()
    cacheSettingsPromise.set(context.sharedContext.accountManager.sharedData(keys: [SharedDataKeys.cacheStorageSettings])
    |> map { sharedData -> CacheStorageSettings in
        let cacheSettings: CacheStorageSettings
        if let value = sharedData.entries[SharedDataKeys.cacheStorageSettings]?.get(CacheStorageSettings.self) {
            cacheSettings = value
        } else {
            cacheSettings = CacheStorageSettings.defaultSettings
        }
        
        return cacheSettings
    })
    
    let viewKey: PostboxViewKey = .preferences(keys: Set([PreferencesKeys.accountSpecificCacheStorageSettings]))
    let accountSpecificSettings: Signal<AccountSpecificCacheStorageSettings, NoError> = context.account.postbox.combinedView(keys: [viewKey])
    |> map { views -> AccountSpecificCacheStorageSettings in
        let cacheSettings: AccountSpecificCacheStorageSettings
        if let view = views.views[viewKey] as? PreferencesView, let value = view.values[PreferencesKeys.accountSpecificCacheStorageSettings]?.get(AccountSpecificCacheStorageSettings.self) {
            cacheSettings = value
        } else {
            cacheSettings = AccountSpecificCacheStorageSettings.defaultSettings
        }

        return cacheSettings
    }
    |> distinctUntilChanged
    
    let peerExceptions: Signal<[(peer: FoundPeer, value: Int32)], NoError> = accountSpecificSettings
    |> mapToSignal { accountSpecificSettings -> Signal<[(peer: FoundPeer, value: Int32)], NoError> in
        return context.account.postbox.transaction { transaction -> [(peer: FoundPeer, value: Int32)] in
            var result: [(peer: FoundPeer, value: Int32)] = []
            
            for item in accountSpecificSettings.peerStorageTimeoutExceptions {
                let peerId = item.key
                let value = item.value
                
                guard let peer = transaction.getPeer(peerId) else {
                    continue
                }
                let peerCategory: CacheStorageSettings.PeerStorageCategory
                var subscriberCount: Int32?
                if peer is TelegramUser {
                    peerCategory = .privateChats
                } else if peer is TelegramGroup {
                    peerCategory = .groups
                    
                    if let cachedData = transaction.getPeerCachedData(peerId: peerId) as? CachedGroupData {
                        subscriberCount = (cachedData.participants?.participants.count).flatMap(Int32.init)
                    }
                } else if let channel = peer as? TelegramChannel {
                    if case .group = channel.info {
                        peerCategory = .groups
                    } else {
                        peerCategory = .channels
                    }
                    if peerCategory == category {
                        if let cachedData = transaction.getPeerCachedData(peerId: peerId) as? CachedChannelData {
                            subscriberCount = cachedData.participantsSummary.memberCount
                        }
                    }
                } else {
                    continue
                }
                    
                if peerCategory != category {
                    continue
                }
                
                result.append((peer: FoundPeer(peer: peer, subscribers: subscriberCount), value: value))
            }
            
            return result.sorted(by: { lhs, rhs in
                if lhs.value != rhs.value {
                    return lhs.value < rhs.value
                }
                return lhs.peer.peer.debugDisplayTitle < rhs.peer.peer.debugDisplayTitle
            })
        }
    }
    
    var presentControllerImpl: ((ViewController, PresentationContextType, Any?) -> Void)?
    let _ = presentControllerImpl
    var pushControllerImpl: ((ViewController) -> Void)?
    
    var findPeerReferenceNode: ((EnginePeer.Id) -> ItemListDisclosureItemNode?)?
    let _ = findPeerReferenceNode
    
    var presentInGlobalOverlay: ((ViewController) -> Void)?
    let _ = presentInGlobalOverlay
    
    let actionDisposables = DisposableSet()
    
    let clearDisposable = MetaDisposable()
    actionDisposables.add(clearDisposable)
    
    let arguments = StorageUsageExceptionsScreenArguments(
        context: context,
        openAddException: {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            var filter: ChatListNodePeersFilter = [.excludeRecent, .doNotSearchMessages, .removeSearchHeader]
            switch category {
            case .groups:
                filter.insert(.onlyGroups)
            case .privateChats:
                filter.insert(.onlyPrivateChats)
                filter.insert(.excludeSecretChats)
            case .channels:
                filter.insert(.onlyChannels)
            }
            let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: filter, hasContactSelector: false, title: presentationData.strings.Notifications_AddExceptionTitle))
            controller.peerSelected = { [weak controller] peer, _ in
                let peerId = peer.id
                
                let _ = updateAccountSpecificCacheStorageSettingsInteractively(postbox: context.account.postbox, { settings in
                    var settings = settings
                    
                    for i in 0 ..< settings.peerStorageTimeoutExceptions.count {
                        if settings.peerStorageTimeoutExceptions[i].key == peerId {
                            settings.peerStorageTimeoutExceptions.remove(at: i)
                            break
                        }
                    }
                    settings.peerStorageTimeoutExceptions.append(AccountSpecificCacheStorageSettings.Value(key: peerId, value: Int32.max))
                    
                    return settings
                }).start()
                
                controller?.dismiss()
            }
            pushControllerImpl?(controller)
        },
        openPeerMenu: { peerId, currentValue in
            let applyValue: (Int32?) -> Void = { value in
                let _ = updateAccountSpecificCacheStorageSettingsInteractively(postbox: context.account.postbox, { settings in
                    var settings = settings
                    
                    if let value = value {
                        var found = false
                        for i in 0 ..< settings.peerStorageTimeoutExceptions.count {
                            if settings.peerStorageTimeoutExceptions[i].key == peerId {
                                found = true
                                settings.peerStorageTimeoutExceptions[i] = AccountSpecificCacheStorageSettings.Value(key: peerId, value: value)
                                break
                            }
                        }
                        if !found {
                            settings.peerStorageTimeoutExceptions.append(AccountSpecificCacheStorageSettings.Value(key: peerId, value: value))
                        }
                    } else {
                        for i in 0 ..< settings.peerStorageTimeoutExceptions.count {
                            if settings.peerStorageTimeoutExceptions[i].key == peerId {
                                settings.peerStorageTimeoutExceptions.remove(at: i)
                                break
                            }
                        }
                    }
                    
                    return settings
                }).start()
            }
            
            var subItems: [ContextMenuItem] = []
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            let presetValues: [Int32] = [
                Int32.max,
                31 * 24 * 60 * 60,
                7 * 24 * 60 * 60,
                1 * 24 * 60 * 60
            ]
            
            for value in presetValues {
                let optionText: String
                if value == Int32.max {
                    optionText = presentationData.strings.ClearCache_Forever
                } else {
                    optionText = timeIntervalString(strings: presentationData.strings, value: value)
                }
                subItems.append(.action(ContextMenuActionItem(text: optionText, icon: { theme in
                    if currentValue == value {
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                    } else {
                        return nil
                    }
                }, action: { _, f in
                    applyValue(value)
                    f(.default)
                })))
            }
            
            subItems.append(.separator)
            subItems.append(.action(ContextMenuActionItem(text: presentationData.strings.VoiceChat_RemovePeer, textColor: .destructive, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
            }, action: { _, f in
                f(.default)
                
                applyValue(nil)
            })))
            
            if let sourceNode = findPeerReferenceNode?(peerId) {
                let items: Signal<ContextController.Items, NoError> = .single(ContextController.Items(content: .list(subItems)))
                let source: ContextContentSource = .reference(StorageUsageExceptionsContextReferenceContentSource(sourceView: sourceNode.labelNode.view))
                
                let contextController = ContextController(
                    account: context.account,
                    presentationData: presentationData,
                    source: source,
                    items: items,
                    gesture: nil
                )
                sourceNode.updateHasContextMenu(hasContextMenu: true)
                contextController.dismissed = { [weak sourceNode] in
                    sourceNode?.updateHasContextMenu(hasContextMenu: false)
                }
                presentInGlobalOverlay?(contextController)
            }
        }
    )
    
    let _ = cacheSettingsPromise
    
    var dismissImpl: (() -> Void)?
    
    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        peerExceptions,
        statePromise.get()
    )
    |> deliverOnMainQueue
    |> map { presentationData, peerExceptions, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let leftNavigationButton = isModal ? ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            dismissImpl?()
        }) : nil
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.Notifications_ExceptionsTitle), leftNavigationButton: leftNavigationButton, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: storageUsageExceptionsScreenEntries(presentationData: presentationData, peerExceptions: peerExceptions, state: state), style: .blocks, emptyStateItem: nil, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionDisposables.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    if isModal {
        controller.navigationPresentation = .modal
        controller.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    }
    presentControllerImpl = { [weak controller] c, contextType, a in
        controller?.present(c, in: contextType, with: a)
    }
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    presentInGlobalOverlay = { [weak controller] c in
        controller?.presentInGlobalOverlay(c, with: nil)
    }
    findPeerReferenceNode = { [weak controller] peerId in
        guard let controller else {
            return nil
        }
        
        let targetTag: StorageUsageExceptionsEntryTag = .peer(peerId)
        var resultItemNode: ItemListItemNode?
        controller.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ItemListItemNode {
                if let tag = itemNode.tag, tag.isEqual(to: targetTag) {
                    resultItemNode = itemNode
                    return
                }
            }
        }
        
        if let resultItemNode = resultItemNode as? ItemListDisclosureItemNode {
            return resultItemNode
        } else {
            return nil
        }
    }
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    return controller
}

private final class StorageUsageExceptionsContextReferenceContentSource: ContextReferenceContentSource {
    private let sourceView: UIView
    
    init(sourceView: UIView) {
        self.sourceView = sourceView
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds, insets: UIEdgeInsets(top: -4.0, left: 0.0, bottom: -4.0, right: 0.0))
    }
}
