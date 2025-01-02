import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import ItemListPeerItem
import ItemListPeerActionItem
import AvatarNode

private final class SelectivePrivacyPeersControllerArguments {
    let context: AccountContext
    
    let setPeerIdWithRevealedOptions: (EnginePeer.Id?, EnginePeer.Id?) -> Void
    let removePeer: (EnginePeer.Id) -> Void
    let addPeer: () -> Void
    let openPeer: (EnginePeer) -> Void
    let deleteAll: () -> Void
    let removePremiumUsers: () -> Void
    let removeBots: () -> Void
    
    init(context: AccountContext, setPeerIdWithRevealedOptions: @escaping (EnginePeer.Id?, EnginePeer.Id?) -> Void, removePeer: @escaping (EnginePeer.Id) -> Void, addPeer: @escaping () -> Void, openPeer: @escaping (EnginePeer) -> Void, deleteAll: @escaping () -> Void, removePremiumUsers: @escaping () -> Void, removeBots: @escaping () -> Void) {
        self.context = context
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.removePeer = removePeer
        self.addPeer = addPeer
        self.openPeer = openPeer
        self.deleteAll = deleteAll
        self.removePremiumUsers = removePremiumUsers
        self.removeBots = removeBots
    }
}

private enum SelectivePrivacyPeersSection: Int32 {
    case peers
    case delete
}

private enum SelectivePrivacyPeersEntryStableId: Hashable {
    case header
    case add
    case premiumUsers
    case bots
    case peer(EnginePeer.Id)
    case delete
}

private let premiumAvatarIcon: UIImage? = {
    return generatePremiumCategoryIcon(size: CGSize(width: 31.0, height: 31.0), cornerRadius: 8.0)
}()

private let botsIcon: UIImage? = {
    return generateAvatarImage(size: CGSize(width: 31.0, height: 31.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/Bot"), color: .white), cornerRadius: 8.0, color: .violet)
}()

private enum SelectivePrivacyPeersEntry: ItemListNodeEntry {
    case premiumUsersItem(ItemListPeerItemEditing, Bool)
    case botsItem(ItemListPeerItemEditing, Bool)
    case peerItem(Int32, PresentationDateTimeFormat, PresentationPersonNameOrder, SelectivePrivacyPeer, ItemListPeerItemEditing, Bool)
    case addItem(String, Bool)
    case headerItem(String)
    case deleteItem(String)
    
    var section: ItemListSectionId {
        switch self {
        case .addItem, .premiumUsersItem, .botsItem, .peerItem, .headerItem:
            return SelectivePrivacyPeersSection.peers.rawValue
        case .deleteItem:
            return SelectivePrivacyPeersSection.delete.rawValue
        }
    }
    
    var stableId: SelectivePrivacyPeersEntryStableId {
        switch self {
        case .premiumUsersItem:
            return .premiumUsers
        case .botsItem:
            return .bots
        case let .peerItem(_, _, _, peer, _, _):
            return .peer(peer.peer.id)
        case .addItem:
            return .add
        case .headerItem:
            return .header
        case .deleteItem:
            return .delete
        }
    }
    
    static func ==(lhs: SelectivePrivacyPeersEntry, rhs: SelectivePrivacyPeersEntry) -> Bool {
        switch lhs {
        case let .premiumUsersItem(editing, isEnabled):
            if case .premiumUsersItem(editing, isEnabled) = rhs {
                return true
            } else {
                return false
            }
        case let .botsItem(editing, isEnabled):
            if case .botsItem(editing, isEnabled) = rhs {
                return true
            } else {
                return false
            }
        case let .peerItem(lhsIndex, lhsDateTimeFormat, lhsNameOrder, lhsPeer, lhsEditing, lhsEnabled):
            if case let .peerItem(rhsIndex, rhsDateTimeFormat, rhsNameOrder, rhsPeer, rhsEditing, rhsEnabled) = rhs {
                if lhsIndex != rhsIndex {
                    return false
                }
                if lhsPeer != rhsPeer {
                    return false
                }
                if lhsDateTimeFormat != rhsDateTimeFormat {
                    return false
                }
                if lhsNameOrder != rhsNameOrder {
                    return false
                }
                if lhsEditing != rhsEditing {
                    return false
                }
                if lhsEnabled != rhsEnabled {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .addItem(lhsText, lhsEditing):
            if case let .addItem(rhsText, rhsEditing) = rhs, lhsText == rhsText, lhsEditing == rhsEditing {
                return true
            } else {
                return false
            }
        case let .headerItem(lhsText):
            if case let .headerItem(rhsText) = rhs, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .deleteItem(lhsText):
            if case let .deleteItem(rhsText) = rhs, lhsText == rhsText {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: SelectivePrivacyPeersEntry, rhs: SelectivePrivacyPeersEntry) -> Bool {
        switch lhs {
        case .deleteItem:
            return false
        case let .peerItem(index, _, _, _, _, _):
            switch rhs {
            case .deleteItem:
                return true
            case let .peerItem(rhsIndex, _, _, _, _, _):
                return index < rhsIndex
            case .addItem, .headerItem, .premiumUsersItem, .botsItem:
                return false
            }
        case .premiumUsersItem:
            switch rhs {
            case .peerItem, .deleteItem, .botsItem:
                return true
            case .premiumUsersItem, .addItem, .headerItem:
                return false
            }
        case .botsItem:
            switch rhs {
            case .peerItem, .deleteItem:
                return true
            case .botsItem, .premiumUsersItem, .addItem, .headerItem:
                return false
            }
        case .addItem:
            switch rhs {
            case .peerItem, .deleteItem, .botsItem, .premiumUsersItem:
                return true
            case .addItem, .headerItem:
                return false
            }
        case .headerItem:
            switch rhs {
            case .peerItem, .deleteItem, .botsItem, .premiumUsersItem, .addItem:
                return true
            case .headerItem:
                return false
            }
        }
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! SelectivePrivacyPeersControllerArguments
        switch self {
        case let .premiumUsersItem(editing, enabled):
            let peer: EnginePeer = .user(TelegramUser(
                id: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1)), accessHash: nil, firstName: presentationData.strings.PrivacySettings_CategoryPremiumUsers, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil))
            return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: PresentationDateTimeFormat(), nameDisplayOrder: .firstLast, context: arguments.context, peer: peer, customAvatarIcon: premiumAvatarIcon, presence: nil, text: .none, label: .none, editing: editing, switchValue: nil, enabled: enabled, selectable: true, sectionId: self.section, action: {
            }, setPeerIdWithRevealedOptions: { previousId, id in
                arguments.setPeerIdWithRevealedOptions(previousId, id)
            }, removePeer: { peerId in
                arguments.removePremiumUsers()
            })
        case let .botsItem(editing, enabled):
            let peer: EnginePeer = .user(TelegramUser(
                id: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(2)), accessHash: nil, firstName: presentationData.strings.PrivacySettings_CategoryBots, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil))
            return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: PresentationDateTimeFormat(), nameDisplayOrder: .firstLast, context: arguments.context, peer: peer, customAvatarIcon: botsIcon, presence: nil, text: .none, label: .none, editing: editing, switchValue: nil, enabled: enabled, selectable: true, sectionId: self.section, action: {
            }, setPeerIdWithRevealedOptions: { previousId, id in
                arguments.setPeerIdWithRevealedOptions(previousId, id)
            }, removePeer: { peerId in
                arguments.removeBots()
            })
        case let .peerItem(_, dateTimeFormat, nameDisplayOrder, peer, editing, enabled):
            var text: ItemListPeerItemText = .none
            if let group = peer.peer as? TelegramGroup {
                text = .text(presentationData.strings.Conversation_StatusMembers(Int32(group.participantCount)), .secondary)
            } else if let channel = peer.peer as? TelegramChannel {
                if let participantCount = peer.participantCount {
                    text = .text(presentationData.strings.Conversation_StatusMembers(Int32(participantCount)), .secondary)
                } else {
                    switch channel.info {
                        case .group:
                        text = .text(presentationData.strings.Group_Status, .secondary)
                        case .broadcast:
                        text = .text(presentationData.strings.Channel_Status, .secondary)
                    }
                }
            }
            return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, context: arguments.context, peer: EnginePeer(peer.peer), presence: nil, text: text, label: .none, editing: editing, switchValue: nil, enabled: enabled, selectable: true, sectionId: self.section, action: {
                arguments.openPeer(EnginePeer(peer.peer))
            }, setPeerIdWithRevealedOptions: { previousId, id in
                arguments.setPeerIdWithRevealedOptions(previousId, id)
            }, removePeer: { peerId in
                arguments.removePeer(peerId)
            })
        case let .addItem(text, editing):
            return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.plusIconImage(presentationData.theme), title: text, sectionId: self.section, height: .compactPeerList, editing: editing, action: {
                    arguments.addPeer()
                })
        case let .headerItem(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .deleteItem(text):
            return ItemListActionItem(presentationData: presentationData, title: text, kind: .destructive, alignment: .center, sectionId: self.section, style: .blocks, action: {
                arguments.deleteAll()
            })
        }
    }
}

private struct SelectivePrivacyPeersControllerState: Equatable {
    var enableForPremium: Bool
    var enableForBots: Bool
    var editing: Bool
    var peerIdWithRevealedOptions: EnginePeer.Id?
    
    init(enableForPremium: Bool, enableForBots: Bool, editing: Bool, peerIdWithRevealedOptions: EnginePeer.Id?) {
        self.enableForPremium = enableForPremium
        self.enableForBots = enableForBots
        self.editing = editing
        self.peerIdWithRevealedOptions = peerIdWithRevealedOptions
    }
}

private func selectivePrivacyPeersControllerEntries(presentationData: PresentationData, state: SelectivePrivacyPeersControllerState, peers: [SelectivePrivacyPeer]) -> [SelectivePrivacyPeersEntry] {
    var entries: [SelectivePrivacyPeersEntry] = []
    
    let title: String
    if peers.isEmpty {
        title = presentationData.strings.Privacy_Exceptions
    } else {
        title = presentationData.strings.Privacy_ExceptionsCount(Int32(peers.count))
    }
    entries.append(.headerItem(title))
    entries.append(.addItem(presentationData.strings.Privacy_AddNewPeer, state.editing))
    
    if state.enableForPremium {
        entries.append(.premiumUsersItem(ItemListPeerItemEditing(editable: true, editing: state.editing, revealed: state.peerIdWithRevealedOptions?.id._internalGetInt64Value() == 1), true))
    }
    
    if state.enableForBots {
        entries.append(.botsItem(ItemListPeerItemEditing(editable: true, editing: state.editing, revealed: state.peerIdWithRevealedOptions?.id._internalGetInt64Value() == 2), true))
    }
    
    var index: Int32 = 0
    for peer in peers {
        entries.append(.peerItem(index, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, peer, ItemListPeerItemEditing(editable: true, editing: state.editing, revealed: peer.peer.id == state.peerIdWithRevealedOptions), true))
        index += 1
    }
    
    if !peers.isEmpty {
        entries.append(.deleteItem(presentationData.strings.Privacy_Exceptions_DeleteAllExceptions))
    }
    
    return entries
}

public func selectivePrivacyPeersController(context: AccountContext, title: String, initialPeers: [EnginePeer.Id: SelectivePrivacyPeer], initialEnableForPremium: Bool, displayPremiumCategory: Bool, initialEnableForBots: Bool, displayBotsCategory: Bool, updated: @escaping ([EnginePeer.Id: SelectivePrivacyPeer], Bool, Bool) -> Void) -> ViewController {
    let initialState = SelectivePrivacyPeersControllerState(enableForPremium: initialEnableForPremium, enableForBots: initialEnableForBots, editing: false, peerIdWithRevealedOptions: nil)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((SelectivePrivacyPeersControllerState) -> SelectivePrivacyPeersControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var dismissImpl: (() -> Void)?
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let addPeerDisposable = MetaDisposable()
    actionsDisposable.add(addPeerDisposable)
    
    let removePeerDisposable = MetaDisposable()
    actionsDisposable.add(removePeerDisposable)
    
    let peersPromise = Promise<[SelectivePrivacyPeer]>()
    peersPromise.set(.single(Array(initialPeers.values)))
    
    let arguments = SelectivePrivacyPeersControllerArguments(context: context, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
        updateState { state in
            if (peerId == nil && fromPeerId == state.peerIdWithRevealedOptions) || (peerId != nil && fromPeerId == nil) {
                var state = state
                state.peerIdWithRevealedOptions = peerId
                return state
            } else {
                return state
            }
        }
    }, removePeer: { memberId in
        let applyPeers: Signal<Void, NoError> = peersPromise.get()
        |> take(1)
        |> deliverOnMainQueue
        |> mapToSignal { peers -> Signal<Void, NoError> in
            var updatedPeers = peers
            for i in 0 ..< updatedPeers.count {
                if updatedPeers[i].peer.id == memberId {
                    updatedPeers.remove(at: i)
                    break
                }
            }
            peersPromise.set(.single(updatedPeers))
            
            var updatedPeerDict: [EnginePeer.Id: SelectivePrivacyPeer] = [:]
            for peer in updatedPeers {
                updatedPeerDict[peer.peer.id] = peer
            }
            updated(updatedPeerDict, stateValue.with({ $0 }).enableForPremium, stateValue.with({ $0 }).enableForBots)
            
            if updatedPeerDict.isEmpty {
                dismissImpl?()
            }
            
            return .complete()
        }
        
        removePeerDisposable.set(applyPeers.start())
    }, addPeer: {
        enum AdditionalCategoryId: Int {
            case premiumUsers
            case bots
        }
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        var additionalCategories: [ChatListNodeAdditionalCategory] = []
        
        if displayPremiumCategory {
            additionalCategories = [
                ChatListNodeAdditionalCategory(
                    id: AdditionalCategoryId.premiumUsers.rawValue,
                    icon: generatePremiumCategoryIcon(size: CGSize(width: 40.0, height: 40.0), cornerRadius: 12.0),
                    smallIcon: generatePremiumCategoryIcon(size: CGSize(width: 22.0, height: 22.0), cornerRadius: 6.0),
                    title: presentationData.strings.PrivacySettings_CategoryPremiumUsers,
                    appearance: .option(sectionTitle: presentationData.strings.PrivacySettings_SearchUserTypesHeader)
                )
            ]
        }
        if displayBotsCategory {
            additionalCategories = [
                ChatListNodeAdditionalCategory(
                    id: AdditionalCategoryId.bots.rawValue,
                    icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/Bot"), color: .white), cornerRadius: 12.0, color: .violet),
                    smallIcon: generateAvatarImage(size: CGSize(width: 22.0, height: 22.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/Bot"), color: .white), iconScale: 0.6, cornerRadius: 6.0, circleCorners: true, color: .violet),
                    title: presentationData.strings.PrivacySettings_CategoryBots,
                    appearance: .option(sectionTitle: presentationData.strings.PrivacySettings_SearchUserTypesHeader)
                )
            ]
        }
        var selectedCategories = Set<Int>()
        if stateValue.with({ $0 }).enableForPremium {
            selectedCategories.insert(AdditionalCategoryId.premiumUsers.rawValue)
        }
        
        let controller = context.sharedContext.makeContactMultiselectionController(ContactMultiselectionControllerParams(context: context, mode: .chatSelection(ContactMultiselectionControllerMode.ChatSelection(
            title: presentationData.strings.PrivacySettings_SearchUsersTitle,
            searchPlaceholder: presentationData.strings.PrivacySettings_SearchUsersPlaceholder,
            selectedChats: Set(),
            additionalCategories: ContactMultiselectionControllerAdditionalCategories(categories: additionalCategories, selectedCategories: selectedCategories),
            chatListFilters: nil,
            onlyUsers: false,
            disableChannels: true,
            disableBots: false
        )), alwaysEnabled: true))
        addPeerDisposable.set((controller.result
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak controller] result in
            var peerIds: [ContactListPeerId] = []
            var premiumSelected = false
            var botsSelected = false
            if case let .result(peerIdsValue, additionalOptionIds) = result {
                peerIds = peerIdsValue
                premiumSelected = additionalOptionIds.contains(AdditionalCategoryId.premiumUsers.rawValue)
                botsSelected = additionalOptionIds.contains(AdditionalCategoryId.bots.rawValue)
            } else {
                return
            }
            
            let applyPeers: Signal<Void, NoError> = peersPromise.get()
            |> take(1)
            |> mapToSignal { peers -> Signal<[SelectivePrivacyPeer], NoError> in
                let filteredPeerIds = peerIds.compactMap { peerId -> EnginePeer.Id? in
                    if case let .peer(value) = peerId {
                        return value
                    } else {
                        return nil
                    }
                }
                return context.engine.data.get(
                    EngineDataMap(filteredPeerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)),
                    EngineDataMap(filteredPeerIds.map(TelegramEngine.EngineData.Item.Peer.ParticipantCount.init))
                )
                |> map { peerMap, participantCountMap -> [SelectivePrivacyPeer] in
                    var updatedPeers = peers
                    var existingIds = Set(updatedPeers.map { $0.peer.id })
                    for peerId in peerIds {
                        guard case let .peer(peerId) = peerId else {
                            continue
                        }
                        if let maybePeer = peerMap[peerId], let peer = maybePeer, !existingIds.contains(peerId) {
                            existingIds.insert(peerId)
                            var participantCount: Int32?
                            if case let .channel(channel) = peer, case .group = channel.info {
                                if let maybeParticipantCount = participantCountMap[peerId], let participantCountValue = maybeParticipantCount {
                                    participantCount = Int32(participantCountValue)
                                }
                            }
                            
                            updatedPeers.append(SelectivePrivacyPeer(peer: peer._asPeer(), participantCount: participantCount))
                        }
                    }
                    return updatedPeers
                }
            }
            |> deliverOnMainQueue
            |> mapToSignal { updatedPeers -> Signal<Void, NoError> in
                peersPromise.set(.single(updatedPeers))
                
                var updatedPeerDict: [EnginePeer.Id: SelectivePrivacyPeer] = [:]
                for peer in updatedPeers {
                    updatedPeerDict[peer.peer.id] = peer
                }
                updated(updatedPeerDict, premiumSelected, botsSelected)
                
                updateState { state in
                    var state = state
                    state.enableForPremium = premiumSelected
                    state.enableForBots = botsSelected
                    return state
                }
                
                return .complete()
            }
            
            removePeerDisposable.set(applyPeers.start())
            controller?.dismiss()
        }))
        presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, openPeer: { peer in
        guard let controller = context.sharedContext.makePeerInfoController(context: context, updatedPresentationData: nil, peer: peer._asPeer(), mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) else {
            return
        }
        pushControllerImpl?(controller)
    }, deleteAll: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationData: presentationData)
        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
            ActionSheetTextItem(title: presentationData.strings.Privacy_Exceptions_DeleteAllConfirmation),
            ActionSheetButtonItem(title: presentationData.strings.Privacy_Exceptions_DeleteAll, color: .destructive, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                
                let applyPeers: Signal<Void, NoError> = peersPromise.get()
                |> take(1)
                |> deliverOnMainQueue
                |> mapToSignal { _ -> Signal<Void, NoError> in
                    updateState { state in
                        var state = state
                        state.enableForPremium = false
                        return state
                    }
                    
                    peersPromise.set(.single([]))
                    updated([:], false, false)
                    
                    dismissImpl?()

                    return .complete()
                }
                
                removePeerDisposable.set(applyPeers.start())
            })
        ]), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        presentControllerImpl?(actionSheet, nil)
    }, removePremiumUsers: {
        updateState { state in
            var state = state
            state.enableForPremium = false
            return state
        }
        let applyPeers: Signal<Void, NoError> = peersPromise.get()
        |> take(1)
        |> deliverOnMainQueue
        |> mapToSignal { peers -> Signal<Void, NoError> in
            let updatedPeers = peers
            peersPromise.set(.single(updatedPeers))
            
            var updatedPeerDict: [EnginePeer.Id: SelectivePrivacyPeer] = [:]
            for peer in updatedPeers {
                updatedPeerDict[peer.peer.id] = peer
            }
            updated(updatedPeerDict, stateValue.with({ $0 }).enableForPremium, stateValue.with({ $0 }).enableForBots)
            
            if updatedPeerDict.isEmpty && !stateValue.with({ $0 }).enableForPremium && !stateValue.with({ $0 }).enableForBots {
                dismissImpl?()
            }
            
            return .complete()
        }
        
        removePeerDisposable.set(applyPeers.start())
    }, removeBots: {
        updateState { state in
            var state = state
            state.enableForBots = false
            return state
        }
        let applyPeers: Signal<Void, NoError> = peersPromise.get()
        |> take(1)
        |> deliverOnMainQueue
        |> mapToSignal { peers -> Signal<Void, NoError> in
            let updatedPeers = peers
            peersPromise.set(.single(updatedPeers))
            
            var updatedPeerDict: [EnginePeer.Id: SelectivePrivacyPeer] = [:]
            for peer in updatedPeers {
                updatedPeerDict[peer.peer.id] = peer
            }
            updated(updatedPeerDict, stateValue.with({ $0 }).enableForPremium, stateValue.with({ $0 }).enableForBots)
            
            if updatedPeerDict.isEmpty && !stateValue.with({ $0 }).enableForPremium && !stateValue.with({ $0 }).enableForBots {
                dismissImpl?()
            }
            
            return .complete()
        }
        
        removePeerDisposable.set(applyPeers.start())
    })
    
    var previousPeers: [SelectivePrivacyPeer]?
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get(), peersPromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, state, peers -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var rightNavigationButton: ItemListNavigationButton?
        if !peers.isEmpty {
            if state.editing {
                rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
                    updateState { state in
                        var state = state
                        state.editing = false
                        return state
                    }
                })
            } else {
                rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Edit), style: .regular, enabled: true, action: {
                    updateState { state in
                        var state = state
                        state.editing = true
                        return state
                    }
                })
            }
        }
        
        let previous = previousPeers
        previousPeers = peers
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: selectivePrivacyPeersControllerEntries(presentationData: presentationData, state: state, peers: peers), style: .blocks, emptyStateItem: nil, animateChanges: previous != nil && previous!.count >= peers.count)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    dismissImpl = { [weak controller] in
        if let controller = controller, let navigationController = controller.navigationController as? NavigationController {
            navigationController.filterController(controller, animated: true)
        }
    }
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window(.root), with: p)
        }
    }
    pushControllerImpl = { [weak controller] c in
        if let navigationController = controller?.navigationController as? NavigationController {
            navigationController.pushViewController(c)
        }
    }
    return controller
}
