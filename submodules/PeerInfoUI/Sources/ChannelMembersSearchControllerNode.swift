import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import AccountContext
import TemporaryCachedPeerDataManager
import SearchBarNode
import ContactsPeerItem
import SearchUI
import ItemListUI
import ContactListUI
import ChatListSearchItemHeader

private final class ChannelMembersSearchInteraction {
    let openPeer: (Peer, RenderedChannelParticipant?) -> Void
    let copyInviteLink: () -> Void
    
    init(
        openPeer: @escaping (Peer, RenderedChannelParticipant?) -> Void,
        copyInviteLink: @escaping () -> Void
    ) {
        self.openPeer = openPeer
        self.copyInviteLink = copyInviteLink
    }
}

private enum ChannelMembersSearchEntryId: Hashable {
    case copyInviteLink
    case peer(PeerId)
    case contact(PeerId)
}

private enum ChannelMembersSearchEntry: Comparable, Identifiable {
    case copyInviteLink
    case peer(Int, RenderedChannelParticipant, ContactsPeerItemEditing, String?, Bool, Bool, Bool)
    case contact(Int, Peer, TelegramUserPresence?)
    
    var stableId: ChannelMembersSearchEntryId {
        switch self {
        case .copyInviteLink:
            return .copyInviteLink
        case let .peer(_, participant, _, _, _, _, _):
            return .peer(participant.peer.id)
        case let .contact(_, peer, _):
            return .contact(peer.id)
        }
    }
    
    static func ==(lhs: ChannelMembersSearchEntry, rhs: ChannelMembersSearchEntry) -> Bool {
        switch lhs {
        case .copyInviteLink:
            if case .copyInviteLink = rhs {
                return true
            } else {
                return false
            }
        case let .peer(lhsIndex, lhsParticipant, lhsEditing, lhsLabel, lhsEnabled, lhsIsChannel, lhsIsContact):
            if case .peer(lhsIndex, lhsParticipant, lhsEditing, lhsLabel, lhsEnabled, lhsIsChannel, lhsIsContact) = rhs {
                return true
            } else {
                return false
            }
        case let .contact(lhsIndex, lhsPeer, lhsPresence):
            if case let .contact(rhsIndex, rhsPeer, rhsPresence) = rhs {
                if lhsIndex != rhsIndex {
                    return false
                }
                if !lhsPeer.isEqual(rhsPeer) {
                    return false
                }
                if lhsPresence != rhsPresence {
                    return false
                }
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: ChannelMembersSearchEntry, rhs: ChannelMembersSearchEntry) -> Bool {
        switch lhs {
        case .copyInviteLink:
            if case .copyInviteLink = rhs {
                return false
            } else {
                return true
            }
        case let .peer(lhsIndex, _, _, _, _, _, _):
            if case .copyInviteLink = rhs {
                return false
            } else if case let .peer(rhsIndex, _, _, _, _, _, _) = rhs {
                return lhsIndex < rhsIndex
            } else if case .contact = rhs {
                return true
            } else {
                return false
            }
        case let .contact(lhsIndex, _, _):
            if case .copyInviteLink = rhs {
                return false
            } else if case .peer = rhs {
                return false
            } else if case let .contact(rhsIndex, _, _) = rhs {
                return lhsIndex < rhsIndex
            } else {
                return false
            }
        }
    }
    
    func item(context: AccountContext, presentationData: PresentationData, nameSortOrder: PresentationPersonNameOrder, nameDisplayOrder: PresentationPersonNameOrder, interaction: ChannelMembersSearchInteraction) -> ListViewItem {
        switch self {
        case .copyInviteLink:
            let icon: ContactListActionItemIcon
            if let iconImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Link"), color: presentationData.theme.list.itemAccentColor) {
                icon = .generic(iconImage)
            } else {
                icon = .none
            }
            return ContactListActionItem(presentationData: ItemListPresentationData(presentationData), title: presentationData.strings.VoiceChat_CopyInviteLink, icon: icon, clearHighlightAutomatically: true, header: nil, action: {
                interaction.copyInviteLink()
            })
        case let .peer(_, participant, editing, label, enabled, isChannel, isContact):
            let status: ContactsPeerItemStatus
            if let label = label {
                status = .custom(string: label, multiline: false)
            } else if participant.peer.id != context.account.peerId {
                let presence = participant.presences[participant.peer.id] ?? TelegramUserPresence(status: .none, lastActivity: 0)
                status = .presence(EnginePeer.Presence(presence), presentationData.dateTimeFormat)
            } else {
                status = .none
            }
            
            let headerType: ChatListSearchItemHeaderType
            if isContact {
                headerType = .contacts
            } else {
                headerType = isChannel ? .subscribers : .groupMembers
            }
            
            return ContactsPeerItem(presentationData: ItemListPresentationData(presentationData), sortOrder: nameSortOrder, displayOrder: nameDisplayOrder, context: context, peerMode: .peer, peer: .peer(peer: EnginePeer(participant.peer), chatPeer: nil), status: status, enabled: enabled, selection: .none, editing: editing, index: nil, header: ChatListSearchItemHeader(type: headerType, theme: presentationData.theme, strings: presentationData.strings), action: { _ in
                interaction.openPeer(participant.peer, participant)
            })
        case let .contact(_, peer, presence):
            let status: ContactsPeerItemStatus
            if peer.id != context.account.peerId, let presence = presence {
                status = .presence(EnginePeer.Presence(presence), presentationData.dateTimeFormat)
            } else {
                status = .none
            }
            
            return ContactsPeerItem(presentationData: ItemListPresentationData(presentationData), sortOrder: nameSortOrder, displayOrder: nameDisplayOrder, context: context, peerMode: .peer, peer: .peer(peer: EnginePeer(peer), chatPeer: nil), status: status, enabled: true, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: ChatListSearchItemHeader(type: .contacts, theme: presentationData.theme, strings: presentationData.strings), action: { _ in
                interaction.openPeer(peer, nil)
            })
        }
    }
}

private struct ChannelMembersSearchTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let initial: Bool
}

private func preparedTransition(from fromEntries: [ChannelMembersSearchEntry]?, to toEntries: [ChannelMembersSearchEntry], context: AccountContext, presentationData: PresentationData, nameSortOrder: PresentationPersonNameOrder, nameDisplayOrder: PresentationPersonNameOrder, interaction: ChannelMembersSearchInteraction) -> ChannelMembersSearchTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries ?? [], rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, nameSortOrder: nameSortOrder, nameDisplayOrder: nameDisplayOrder, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, nameSortOrder: nameSortOrder, nameDisplayOrder: nameDisplayOrder, interaction: interaction), directionHint: nil) }
    
    return ChannelMembersSearchTransition(deletions: deletions, insertions: insertions, updates: updates, initial: fromEntries == nil)
}

class ChannelMembersSearchControllerNode: ASDisplayNode {
    private let context: AccountContext
    private let peerId: PeerId
    private let mode: ChannelMembersSearchControllerMode
    private let filters: [ChannelMembersSearchFilter]
    let listNode: ListView
    var navigationBar: NavigationBar?
    
    private var enqueuedTransitions: [ChannelMembersSearchTransition] = []
    
    private(set) var searchDisplayController: SearchDisplayController?
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    var requestActivateSearch: (() -> Void)?
    var requestDeactivateSearch: (() -> Void)?
    var requestOpenPeerFromSearch: ((Peer, RenderedChannelParticipant?) -> Void)?
    var requestCopyInviteLink: (() -> Void)?
    var pushController: ((ViewController) -> Void)?
    
    private let forceTheme: PresentationTheme?
    var presentationData: PresentationData

    private var disposable: Disposable?
    private var listControl: PeerChannelMemberCategoryControl?
    
    init(context: AccountContext, presentationData: PresentationData, forceTheme: PresentationTheme?, peerId: PeerId, mode: ChannelMembersSearchControllerMode, filters: [ChannelMembersSearchFilter]) {
        self.context = context
        self.listNode = ListView()
        self.peerId = peerId
        self.mode = mode
        self.filters = filters
        self.presentationData = presentationData
        self.forceTheme = forceTheme
        if let forceTheme = forceTheme {
            self.presentationData = self.presentationData.withUpdated(theme: forceTheme)
        }
        
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        
        self.addSubnode(self.listNode)
        
        let interaction = ChannelMembersSearchInteraction(
            openPeer: { [weak self] peer, participant in
                self?.requestOpenPeerFromSearch?(peer, participant)
                self?.listNode.clearHighlightAnimated(true)
            },
            copyInviteLink: { [weak self] in
                self?.requestCopyInviteLink?()
                self?.listNode.clearHighlightAnimated(true)
            }
        )
        
        let previousEntries = Atomic<[ChannelMembersSearchEntry]?>(value: nil)
        
        let disposableAndLoadMoreControl: (Disposable, PeerChannelMemberCategoryControl?)
        let contactsDisposableAndLoadMoreControl: (Disposable, PeerChannelMemberCategoryControl?)?
        let additionalDisposable = MetaDisposable()
        
        if peerId.namespace == Namespaces.Peer.CloudGroup {
            let disposable = combineLatest(queue: Queue.mainQueue(),
                context.account.postbox.peerView(id: peerId),
                context.engine.data.subscribe(
                    TelegramEngine.EngineData.Item.Contacts.List(includePresences: true)
                )
            ).start(next: { [weak self] peerView, contactsView in
                guard let strongSelf = self else {
                    return
                }
                guard let cachedData = peerView.cachedData as? CachedGroupData, let participants = cachedData.participants else {
                    return
                }
                var creatorPeer: Peer?
                for participant in participants.participants {
                    if let peer = peerView.peers[participant.peerId] {
                        switch participant {
                            case .creator:
                                creatorPeer = peer
                            default:
                                break
                        }
                    }
                }
                guard let creator = creatorPeer else {
                    return
                }
                var entries: [ChannelMembersSearchEntry] = []
                
                var canInviteByLink = false
                if let peer = peerViewMainPeer(peerView) {
                    if !(peer.addressName?.isEmpty ?? true) {
                        canInviteByLink = true
                    } else if let peer = peer as? TelegramChannel {
                        if peer.flags.contains(.isCreator) || (peer.adminRights?.rights.contains(.canInviteUsers) == true) {
                            canInviteByLink = true
                        }
                    } else if let peer = peer as? TelegramGroup {
                        if case .creator = peer.role {
                            canInviteByLink = true
                        } else if case let .admin(rights, _) = peer.role, rights.rights.contains(.canInviteUsers) {
                            canInviteByLink = true
                        }
                    }
                }
                
                if case .inviteToCall = mode, canInviteByLink,
                   !filters.contains(where: { filter in
                    if case .excludeNonMembers = filter {
                        return true
                    } else {
                        return false
                    }
                }) {
                    entries.append(.copyInviteLink)
                }
                
                var index = 0
                for participant in participants.participants {
                    guard let peer = peerView.peers[participant.peerId] else {
                        continue
                    }
                    if peer.isDeleted {
                        continue
                    }
                    var label: String?
                    var enabled = true
                    switch mode {
                        case .ban:
                            if peer.id == context.account.peerId {
                                continue
                            }
                            for filter in filters {
                                switch filter {
                                    case let .exclude(ids):
                                        if ids.contains(peer.id) {
                                            continue
                                        }
                                    case let .disable(ids):
                                        if ids.contains(peer.id) {
                                            enabled = false
                                        }
                                    case .excludeNonMembers:
                                        break
                                    case .excludeBots:
                                        if let user = peer as? TelegramUser, user.botInfo != nil {
                                            continue
                                        }
                                }
                            }
                        case .promote:
                            if peer.id == context.account.peerId {
                                continue
                            }
                            for filter in filters {
                                switch filter {
                                    case let .exclude(ids):
                                        if ids.contains(peer.id) {
                                            continue
                                        }
                                    case let .disable(ids):
                                        if ids.contains(peer.id) {
                                            enabled = false
                                        }
                                    case .excludeNonMembers:
                                        break
                                    case .excludeBots:
                                        if let user = peer as? TelegramUser, user.botInfo != nil {
                                            continue
                                        }
                                }
                            }
                            if case .creator = participant {
                                label = strongSelf.presentationData.strings.Channel_Management_LabelOwner
                                enabled = false
                            }
                        case .inviteToCall:
                            if peer.id == context.account.peerId {
                                continue
                            }
                            if let user = peer as? TelegramUser, user.botInfo != nil || user.flags.contains(.isSupport) {
                                continue
                            }
                            for filter in filters {
                                switch filter {
                                    case let .exclude(ids):
                                        if ids.contains(peer.id) {
                                            continue
                                        }
                                    case let .disable(ids):
                                        if ids.contains(peer.id) {
                                            enabled = false
                                        }
                                    case .excludeNonMembers:
                                        break
                                    case .excludeBots:
                                        if let user = peer as? TelegramUser, user.botInfo != nil {
                                            continue
                                        }
                                }
                            }
                    }
                    let renderedParticipant: RenderedChannelParticipant
                    switch participant {
                        case .creator:
                            renderedParticipant = RenderedChannelParticipant(participant: .creator(id: peer.id, adminInfo: nil, rank: nil), peer: peer, presences: peerView.peerPresences)
                        case .admin:
                            var peers: [PeerId: Peer] = [:]
                            peers[creator.id] = creator
                            peers[peer.id] = peer
                            renderedParticipant = RenderedChannelParticipant(participant: .member(id: peer.id, invitedAt: 0, adminInfo: ChannelParticipantAdminInfo(rights: TelegramChatAdminRights(rights: .groupSpecific), promotedBy: creator.id, canBeEditedByAccountPeer: creator.id == context.account.peerId), banInfo: nil, rank: nil), peer: peer, peers: peers, presences: peerView.peerPresences)
                        case .member:
                            var peers: [PeerId: Peer] = [:]
                            peers[peer.id] = peer
                            renderedParticipant = RenderedChannelParticipant(participant: .member(id: peer.id, invitedAt: 0, adminInfo: nil, banInfo: nil, rank: nil), peer: peer, peers: peers, presences: peerView.peerPresences)
                    }
                    
                    entries.append(.peer(index, renderedParticipant, ContactsPeerItemEditing(editable: false, editing: false, revealed: false), label, enabled, false, false))
                    index += 1
                }
                
                if case .inviteToCall = mode, !filters.contains(where: { filter in
                    if case .excludeNonMembers = filter {
                        return true
                    } else {
                        return false
                    }
                }) {
                    for peer in contactsView.peers {
                        entries.append(ChannelMembersSearchEntry.contact(index, peer._asPeer(), contactsView.presences[peer.id]?._asPresence()))
                        index += 1
                    }
                }
                
                let previous = previousEntries.swap(entries)
                
                strongSelf.enqueueTransition(preparedTransition(from: previous, to: entries, context: context, presentationData: strongSelf.presentationData, nameSortOrder: strongSelf.presentationData.nameSortOrder, nameDisplayOrder: strongSelf.presentationData.nameDisplayOrder, interaction: interaction))
            })
            disposableAndLoadMoreControl = (disposable, nil)
            contactsDisposableAndLoadMoreControl = nil
        } else {
            let membersState = Promise<ChannelMemberListState>()
            
            disposableAndLoadMoreControl = context.peerChannelMemberCategoriesContextsManager.recent(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId, updated: { state in
                membersState.set(.single(state))
            })
            
            let contactsState = Promise<ChannelMemberListState>()
            contactsDisposableAndLoadMoreControl = context.peerChannelMemberCategoriesContextsManager.contacts(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId, searchQuery: nil, updated: { state in
                contactsState.set(.single(state))
            })
            
            additionalDisposable.set((combineLatest(queue: .mainQueue(),
               membersState.get(),
               contactsState.get(),
               context.account.postbox.peerView(id: peerId),
               context.engine.data.subscribe(
                   TelegramEngine.EngineData.Item.Contacts.List(includePresences: true)
               )
            ).start(next: { [weak self] state, contactsState, peerView, contactsView in
                guard let strongSelf = self else {
                    return
                }
                var entries: [ChannelMembersSearchEntry] = []
                
                var canInviteByLink = false
                var isChannel = false
                if let peer = peerViewMainPeer(peerView) {
                    if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                        isChannel = true
                    }
                    if !(peer.addressName?.isEmpty ?? true) {
                        canInviteByLink = true
                    } else if let peer = peer as? TelegramChannel {
                        if peer.flags.contains(.isCreator) || (peer.adminRights?.rights.contains(.canInviteUsers) == true) {
                            canInviteByLink = true
                        }
                    } else if let peer = peer as? TelegramGroup {
                        if case .creator = peer.role {
                            canInviteByLink = true
                        } else if case let .admin(rights, _) = peer.role, rights.rights.contains(.canInviteUsers) {
                            canInviteByLink = true
                        }
                    }
                }
                
                var index = 0
                var existingPeersIds = Set<PeerId>()
                if case .inviteToCall = mode, canInviteByLink, !filters.contains(where: { filter in
                    if case .excludeNonMembers = filter {
                        return true
                    } else {
                        return false
                    }
                }) {
                    entries.append(.copyInviteLink)
                } else {
                    contactsLoop: for participant in contactsState.list {
                        if participant.peer.isDeleted {
                            continue contactsLoop
                        }
                        
                        var label: String?
                        var enabled = true
                        for filter in filters {
                            switch filter {
                            case let .exclude(ids):
                                if ids.contains(participant.peer.id) {
                                    continue contactsLoop
                                }
                            case let .disable(ids):
                                if ids.contains(participant.peer.id) {
                                    enabled = false
                                }
                            case .excludeNonMembers:
                                break
                            case .excludeBots:
                                if let user = participant.peer as? TelegramUser, user.botInfo != nil {
                                    continue contactsLoop
                                }
                            }
                        }
                        if case .promote = mode, case .creator = participant.participant {
                            label = strongSelf.presentationData.strings.Channel_Management_LabelOwner
                            enabled = false
                        }
                        
                        entries.append(.peer(index, participant, ContactsPeerItemEditing(editable: false, editing: false, revealed: false), label, enabled, isChannel, true))
                        index += 1
                        
                        existingPeersIds.insert(participant.peer.id)
                    }
                }
                
                participantsLoop: for participant in state.list {
                    if participant.peer.isDeleted || existingPeersIds.contains(participant.peer.id) {
                        continue participantsLoop
                    }
                    
                    var label: String?
                    var enabled = true
                    switch mode {
                        case .ban, .promote:
                            if participant.peer.id == context.account.peerId {
                                continue participantsLoop
                            }
                            for filter in filters {
                                switch filter {
                                case let .exclude(ids):
                                    if ids.contains(participant.peer.id) {
                                        continue participantsLoop
                                    }
                                case let .disable(ids):
                                    if ids.contains(participant.peer.id) {
                                        enabled = false
                                    }
                                case .excludeNonMembers:
                                    break
                                case .excludeBots:
                                    if let user = participant.peer as? TelegramUser, user.botInfo != nil {
                                        continue participantsLoop
                                    }
                                }
                            }
                            if case .promote = mode, case .creator = participant.participant {
                                label = strongSelf.presentationData.strings.Channel_Management_LabelOwner
                                enabled = false
                            }
                        case .inviteToCall:
                            if participant.peer.id == context.account.peerId {
                                continue
                            }
                            if let user = participant.peer as? TelegramUser, user.botInfo != nil || user.flags.contains(.isSupport) {
                                continue
                            }
                            for filter in filters {
                                switch filter {
                                case let .exclude(ids):
                                    if ids.contains(participant.peer.id) {
                                        continue participantsLoop
                                    }
                                case let .disable(ids):
                                    if ids.contains(participant.peer.id) {
                                        enabled = false
                                    }
                                case .excludeNonMembers:
                                    break
                                case .excludeBots:
                                    if let user = participant.peer as? TelegramUser, user.botInfo != nil {
                                        continue participantsLoop
                                    }
                                }
                            }
                    }
                    entries.append(.peer(index, participant, ContactsPeerItemEditing(editable: false, editing: false, revealed: false), label, enabled, isChannel, false))
                    index += 1
                }
                
                if case .inviteToCall = mode, !filters.contains(where: { filter in
                    if case .excludeNonMembers = filter {
                        return true
                    } else {
                        return false
                    }
                }) {
                    for peer in contactsView.peers {
                        entries.append(ChannelMembersSearchEntry.contact(index, peer._asPeer(), contactsView.presences[peer.id]?._asPresence()))
                        index += 1
                    }
                }
                
                let previous = previousEntries.swap(entries)
                
                strongSelf.enqueueTransition(preparedTransition(from: previous, to: entries, context: context, presentationData: strongSelf.presentationData, nameSortOrder: strongSelf.presentationData.nameSortOrder, nameDisplayOrder: strongSelf.presentationData.nameDisplayOrder, interaction: interaction))
            })))
        }
        
        let combinedDisposable = DisposableSet()
        combinedDisposable.add(disposableAndLoadMoreControl.0)
        combinedDisposable.add(additionalDisposable)
        if let disposable = contactsDisposableAndLoadMoreControl?.0 {
            combinedDisposable.add(disposable)
        }
        
        self.disposable = combinedDisposable
        self.listControl = disposableAndLoadMoreControl.1
        
        if peerId.namespace == Namespaces.Peer.CloudChannel {
            self.listNode.visibleBottomContentOffsetChanged = { offset in
                if case let .known(value) = offset, value < 40.0 {
                    context.peerChannelMemberCategoriesContextsManager.loadMore(peerId: peerId, control: disposableAndLoadMoreControl.1)
                }
            }
        }
        
        self.listNode.beganInteractiveDragging = { [weak self] _ in
            self?.view.endEditing(true)
        }
    }
    
    deinit {
        self.disposable?.dispose()
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        if let forceTheme = forceTheme {
            self.presentationData = self.presentationData.withUpdated(theme: forceTheme)
        }
        self.searchDisplayController?.updatePresentationData(self.presentationData)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, actualNavigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let hadValidLayout = self.containerLayout != nil
        self.containerLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        
        var headerInsets = layout.insets(options: [.input])
        headerInsets.top += actualNavigationBarHeight
        
        self.listNode.bounds = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        self.listNode.position = CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0)

        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, headerInsets: headerInsets, duration: duration, curve: curve)
        
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
        
        if !hadValidLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    func activateSearch(placeholderNode: SearchBarPlaceholderNode) {
        guard let (containerLayout, navigationBarHeight) = self.containerLayout, let navigationBar = self.navigationBar, self.searchDisplayController == nil else {
            return
        }
        
        self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, contentNode: ChannelMembersSearchContainerNode(context: self.context, forceTheme: self.forceTheme, peerId: self.peerId, mode: .banAndPromoteActions, filters: self.filters, searchContext: nil, openPeer: { [weak self] peer, participant in
            self?.requestOpenPeerFromSearch?(peer, participant)
        }, updateActivity: { value in
            
        }, pushController: { [weak self] c in
            self?.pushController?(c)
        }), cancel: { [weak self] in
            if let requestDeactivateSearch = self?.requestDeactivateSearch {
                requestDeactivateSearch()
            }
        })
        
        self.searchDisplayController?.containerLayoutUpdated(containerLayout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        self.searchDisplayController?.activate(insertSubnode: { [weak self, weak placeholderNode] subnode, isSearchBar in
            if let strongSelf = self, let strongPlaceholderNode = placeholderNode {
                if isSearchBar {
                    strongPlaceholderNode.supernode?.insertSubnode(subnode, aboveSubnode: strongPlaceholderNode)
                } else {
                    strongSelf.insertSubnode(subnode, belowSubnode: navigationBar)
                }
            }
        }, placeholder: placeholderNode)
    }
    
    func deactivateSearch(placeholderNode: SearchBarPlaceholderNode, animated: Bool) {
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.deactivate(placeholder: placeholderNode)
            self.searchDisplayController = nil
        }
    }
    
    func animateIn() {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { _ in
            completion?()
        })
    }
    
    private func enqueueTransition(_ transition: ChannelMembersSearchTransition) {
        enqueuedTransitions.append(transition)
        
        if self.containerLayout != nil {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let transition = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            let options = ListViewDeleteAndInsertOptions()
            if transition.initial {
                //options.insert(.Synchronous)
                //options.insert(.LowLatency)
            } else {
                //options.insert(.AnimateTopItemPosition)
                //options.insert(.AnimateCrossfade)
            }
            
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { _ in
            })
        }
    }
    
    func scrollToTop() {
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
    }
}
