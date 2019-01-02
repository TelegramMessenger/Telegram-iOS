import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

enum ChannelMembersSearchMode {
    case searchMembers
    case searchAdmins
    case searchBanned
    case searchKicked
    case banAndPromoteActions
    case inviteActions
}

private enum ChannelMembersSearchSection {
    case none
    case members
    case banned
    case contacts
    case global
    
    var chatListHeaderType: ChatListSearchItemHeaderType? {
        switch self {
            case .none:
                return nil
            case .members:
                return .members
            case .banned:
                return .exceptions
            case .contacts:
                return .contacts
            case .global:
                return .globalPeers
        }
    }
}

private enum ChannelMembersSearchContent: Equatable {
    case peer(Peer)
    case participant(participant: RenderedChannelParticipant, label: String?, revealActions: [ParticipantRevealAction], revealed: Bool, enabled: Bool)
    
    static func ==(lhs: ChannelMembersSearchContent, rhs: ChannelMembersSearchContent) -> Bool {
        switch lhs {
            case let .peer(lhsPeer):
                if case let .peer(rhsPeer) = rhs {
                    return lhsPeer.isEqual(rhsPeer)
                } else {
                    return false
                }
            case let .participant(participant, label, revealActions, revealed, enabled):
                if case .participant(participant, label, revealActions, revealed, enabled) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    var peerId: PeerId {
        switch self {
            case let .peer(peer):
                return peer.id
            case let .participant(participant, _, _, _, _):
                return participant.peer.id
        }
    }
}

private final class ChannelMembersSearchContainerInteraction {
    let peerSelected: (Peer, RenderedChannelParticipant?) -> Void
    let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    let promotePeer: (RenderedChannelParticipant) -> Void
    let restrictPeer: (RenderedChannelParticipant) -> Void
    let removePeer: (PeerId) -> Void
    
    init(peerSelected: @escaping (Peer, RenderedChannelParticipant?) -> Void, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, promotePeer: @escaping (RenderedChannelParticipant) -> Void, restrictPeer: @escaping (RenderedChannelParticipant) -> Void, removePeer: @escaping (PeerId) -> Void) {
        self.peerSelected = peerSelected
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.promotePeer = promotePeer
        self.restrictPeer = restrictPeer
        self.removePeer = removePeer
    }
}

private final class ChannelMembersSearchEntry: Comparable, Identifiable {
    let index: Int
    let content: ChannelMembersSearchContent
    let section: ChannelMembersSearchSection
    let dateTimeFormat: PresentationDateTimeFormat
    let addIcon: Bool
    
    init(index: Int, content: ChannelMembersSearchContent, section: ChannelMembersSearchSection, dateTimeFormat: PresentationDateTimeFormat, addIcon: Bool = false) {
        self.index = index
        self.content = content
        self.section = section
        self.dateTimeFormat = dateTimeFormat
        self.addIcon = addIcon
    }
    
    var stableId: PeerId {
        return self.content.peerId
    }
    
    static func ==(lhs: ChannelMembersSearchEntry, rhs: ChannelMembersSearchEntry) -> Bool {
        return lhs.index == rhs.index && lhs.content == rhs.content && lhs.section == rhs.section && lhs.addIcon == rhs.addIcon
    }
    
    static func <(lhs: ChannelMembersSearchEntry, rhs: ChannelMembersSearchEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(account: Account, theme: PresentationTheme, strings: PresentationStrings, nameSortOrder: PresentationPersonNameOrder, nameDisplayOrder: PresentationPersonNameOrder, interaction: ChannelMembersSearchContainerInteraction) -> ListViewItem {
        switch self.content {
            case let .peer(peer):
                return ContactsPeerItem(theme: theme, strings: strings, sortOrder: nameSortOrder, displayOrder: nameDisplayOrder, account: account, peerMode: .peer, peer: .peer(peer: peer, chatPeer: peer), status: .none, enabled: true, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: self.section.chatListHeaderType.flatMap({ ChatListSearchItemHeader(type: $0, theme: theme, strings: strings, actionTitle: nil, action: nil) }), action: { _ in
                    interaction.peerSelected(peer, nil)
                })
            case let .participant(participant, label, revealActions, revealed, enabled):
                let status: ContactsPeerItemStatus
                if let label = label {
                    status = .custom(label)
                } else if let presence = participant.presences[participant.peer.id], self.addIcon {
                    status = .presence(presence, dateTimeFormat)
                } else {
                    status = .none
                }
                
                var options: [ItemListPeerItemRevealOption] = []
                for action in revealActions {
                    options.append(ItemListPeerItemRevealOption(type: action.type, title: action.title, action: {
                        switch action.action {
                            case .promote:
                                interaction.promotePeer(participant)
                                break
                            case .restrict:
                                interaction.restrictPeer(participant)
                                break
                            case .remove:
                                interaction.removePeer(participant.peer.id)
                                break
                        }
                    }))
                }
                var actionIcon: ContactsPeerItemActionIcon = .none
                if self.addIcon {
                    actionIcon = .add
                }
                
                return ContactsPeerItem(theme: theme, strings: strings, sortOrder: nameSortOrder, displayOrder: nameDisplayOrder, account: account, peerMode: .peer, peer: .peer(peer: participant.peer, chatPeer: participant.peer), status: status, enabled: enabled, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: revealed), options: options, actionIcon: actionIcon, index: nil, header: self.section.chatListHeaderType.flatMap({ ChatListSearchItemHeader(type: $0, theme: theme, strings: strings, actionTitle: nil, action: nil) }), action: { _ in
                    interaction.peerSelected(participant.peer, participant)
                }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
                    interaction.setPeerIdWithRevealedOptions(peerId, fromPeerId)
                })
        }
    }
}
struct ChannelMembersSearchContainerTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let isSearching: Bool
}

private func channelMembersSearchContainerPreparedRecentTransition(from fromEntries: [ChannelMembersSearchEntry], to toEntries: [ChannelMembersSearchEntry], isSearching: Bool, account: Account, theme: PresentationTheme, strings: PresentationStrings, nameSortOrder: PresentationPersonNameOrder, nameDisplayOrder: PresentationPersonNameOrder, interaction: ChannelMembersSearchContainerInteraction) -> ChannelMembersSearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, theme: theme, strings: strings, nameSortOrder: nameSortOrder, nameDisplayOrder: nameDisplayOrder, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, theme: theme, strings: strings, nameSortOrder: nameSortOrder, nameDisplayOrder: nameDisplayOrder, interaction: interaction), directionHint: nil) }
    
    return ChannelMembersSearchContainerTransition(deletions: deletions, insertions: insertions, updates: updates, isSearching: isSearching)
}

private struct ChannelMembersSearchContainerState: Equatable {
    var revealedPeerId: PeerId?
    var removingParticipantIds = Set<PeerId>()
}

final class ChannelMembersSearchContainerNode: SearchDisplayControllerContentNode {
    private let account: Account
    private let openPeer: (Peer, RenderedChannelParticipant?) -> Void
    private let mode: ChannelMembersSearchMode
    
    private let dimNode: ASDisplayNode
    private let listNode: ListView
    
    private var enqueuedTransitions: [(ChannelMembersSearchContainerTransition, Bool)] = []
    private var hasValidLayout = false
    
    private let searchQuery = Promise<String?>()
    private let searchDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private let removeMemberDisposable = MetaDisposable()
    
    private let themeAndStringsPromise: Promise<(PresentationTheme, PresentationStrings, PresentationPersonNameOrder, PresentationPersonNameOrder, PresentationDateTimeFormat)>
    
    init(account: Account, peerId: PeerId, mode: ChannelMembersSearchMode, filters: [ChannelMembersSearchFilter], openPeer: @escaping (Peer, RenderedChannelParticipant?) -> Void, updateActivity: @escaping (Bool) -> Void, present: @escaping (ViewController, Any?) -> Void) {
        self.account = account
        self.openPeer = openPeer
        self.mode = mode
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        self.themeAndStringsPromise = Promise((self.presentationData.theme, self.presentationData.strings, self.presentationData.nameSortOrder, self.presentationData.nameDisplayOrder, self.presentationData.dateTimeFormat))
        
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        self.listNode = ListView()
        
        super.init()
        
        self.listNode.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        self.listNode.isHidden = true
        
        self.addSubnode(self.dimNode)
        self.addSubnode(self.listNode)
        
        let statePromise = ValuePromise(ChannelMembersSearchContainerState(), ignoreRepeated: true)
        let stateValue = Atomic(value: ChannelMembersSearchContainerState())
        let updateState: ((ChannelMembersSearchContainerState) -> ChannelMembersSearchContainerState) -> Void = { f in
            statePromise.set(stateValue.modify { f($0) })
        }
        
        let removeMemberDisposable = self.removeMemberDisposable
        let interaction = ChannelMembersSearchContainerInteraction(peerSelected: { peer, participant in
            openPeer(peer, participant)
        }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
            updateState { state in
                var state = state
                if (peerId == nil && fromPeerId == state.revealedPeerId) || (peerId != nil && fromPeerId == nil) {
                    state.revealedPeerId = peerId
                }
                return state
            }
        }, promotePeer: { participant in
            present(channelAdminController(account: account, peerId: peerId, adminId: participant.peer.id, initialParticipant: participant.participant, updated: { _ in
            }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        }, restrictPeer: { participant in
            present(channelBannedMemberController(account: account, peerId: peerId, memberId: participant.peer.id, initialParticipant: participant.participant, updated: { _ in
            }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        }, removePeer: { memberId in
            let signal = account.postbox.loadedPeerWithId(memberId)
            |> deliverOnMainQueue
            |> mapToSignal { peer -> Signal<Bool, NoError> in
                let result = ValuePromise<Bool>()
                result.set(true)
                return result.get()
            }
            |> mapToSignal { value -> Signal<Void, NoError> in
                if value {
                    updateState { state in
                        var state = state
                        state.removingParticipantIds.insert(memberId)
                        return state
                    }
                    
                    if peerId.namespace == Namespaces.Peer.CloudChannel {
                        return account.telegramApplicationContext.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(account: account, peerId: peerId, memberId: memberId, bannedRights: TelegramChatBannedRights(flags: [.banReadMessages], personal: false, untilDate: Int32.max))
                        |> afterDisposed {
                            Queue.mainQueue().async {
                                updateState { state in
                                    var state = state
                                    state.removingParticipantIds.remove(memberId)
                                    return state
                                }
                            }
                        }
                    }
                    
                    return removePeerMember(account: account, peerId: peerId, memberId: memberId)
                    |> deliverOnMainQueue
                    |> afterDisposed {
                        updateState { state in
                            var state = state
                            state.removingParticipantIds.remove(memberId)
                            return state
                        }
                    }
                } else {
                    return .complete()
                }
            }
            removeMemberDisposable.set(signal.start())
        })
        
        let themeAndStringsPromise = self.themeAndStringsPromise
        let foundItems = combineLatest(searchQuery.get(), account.postbox.multiplePeersView([peerId]) |> take(1))
        |> mapToSignal { query, peerView -> Signal<[ChannelMembersSearchEntry]?, NoError> in
            guard let channel = peerView.peers[peerId] as? TelegramChannel else {
                return .single(nil)
            }
            updateActivity(true)
            if let query = query, !query.isEmpty {
                let foundGroupMembers: Signal<[RenderedChannelParticipant], NoError>
                let foundMembers: Signal<[RenderedChannelParticipant], NoError>
                
                switch mode {
                    case .searchMembers, .banAndPromoteActions:
                        foundGroupMembers = Signal { subscriber in
                            let (disposable, _) = account.telegramApplicationContext.peerChannelMemberCategoriesContextsManager.recent(postbox: account.postbox, network: account.network, accountPeerId: account.peerId, peerId: peerId, searchQuery: query, updated: { state in
                                if case .ready = state.loadingState {
                                    subscriber.putNext(state.list)
                                }
                            })
                            return disposable
                        }
                        |> runOn(Queue.mainQueue())
                        foundMembers = .single([])
                    case .inviteActions:
                        foundGroupMembers = .single([])
                        foundMembers = channelMembers(postbox: account.postbox, network: account.network, accountPeerId: account.peerId, peerId: peerId, category: .recent(.search(query)))
                        |> map { $0 ?? [] }
                case .searchAdmins:
                    foundGroupMembers = Signal { subscriber in
                        let (disposable, _) = account.telegramApplicationContext.peerChannelMemberCategoriesContextsManager.admins(postbox: account.postbox, network: account.network, accountPeerId: account.peerId, peerId: peerId, searchQuery: query, updated: { state in
                            if case .ready = state.loadingState {
                                subscriber.putNext(state.list)
                                subscriber.putCompletion()
                            }
                        })
                        return disposable
                        } |> runOn(Queue.mainQueue())
                    foundMembers = .single([])
                case .searchBanned:
                    foundGroupMembers = Signal { subscriber in
                        let (disposable, _) = account.telegramApplicationContext.peerChannelMemberCategoriesContextsManager.restricted(postbox: account.postbox, network: account.network, accountPeerId: account.peerId, peerId: peerId, searchQuery: query, updated: { state in
                            if case .ready = state.loadingState {
                                subscriber.putNext(state.list)
                                subscriber.putCompletion()
                            }
                        })
                        return disposable
                    }
                    |> runOn(Queue.mainQueue())
                    foundMembers = Signal { subscriber in
                        let (disposable, _) = account.telegramApplicationContext.peerChannelMemberCategoriesContextsManager.recent(postbox: account.postbox, network: account.network, accountPeerId: account.peerId, peerId: peerId, searchQuery: query, updated: { state in
                            if case .ready = state.loadingState {
                                subscriber.putNext(state.list.filter({ participant in
                                    return participant.peer.id != account.peerId
                                }))
                            }
                        })
                        return disposable
                    }
                    |> runOn(Queue.mainQueue())
                case .searchKicked:
                    foundGroupMembers = Signal { subscriber in
                        let (disposable, _) = account.telegramApplicationContext.peerChannelMemberCategoriesContextsManager.banned(postbox: account.postbox, network: account.network, accountPeerId: account.peerId, peerId: peerId, searchQuery: query, updated: { state in
                            if case .ready = state.loadingState {
                                subscriber.putNext(state.list)
                                subscriber.putCompletion()
                            }
                        })
                        return disposable
                    }
                    |> runOn(Queue.mainQueue())
                    foundMembers = .single([])
                }
                
                let foundContacts: Signal<([Peer], [PeerId: PeerPresence]), NoError>
                let foundRemotePeers: Signal<([FoundPeer], [FoundPeer]), NoError>
                switch mode {
                    case .inviteActions, .banAndPromoteActions:
                        foundContacts = account.postbox.searchContacts(query: query.lowercased())
                        foundRemotePeers = .single(([], [])) |> then(searchPeers(account: account, query: query)
                        |> delay(0.2, queue: Queue.concurrentDefaultQueue()))
                    case .searchMembers, .searchBanned, .searchKicked, .searchAdmins:
                        foundContacts = .single(([], [:]))
                        foundRemotePeers = .single(([], []))
                }
                
                return combineLatest(foundGroupMembers, foundMembers, foundContacts, foundRemotePeers, themeAndStringsPromise.get(), statePromise.get())
                |> map { foundGroupMembers, foundMembers, foundContacts, foundRemotePeers, themeAndStrings, state -> [ChannelMembersSearchEntry]? in
                    var entries: [ChannelMembersSearchEntry] = []
                    
                    var existingPeerIds = Set<PeerId>()
                    for filter in filters {
                        switch filter {
                            case let .exclude(ids):
                                existingPeerIds = existingPeerIds.union(ids)
                            case .disable:
                                break
                        }
                    }
                    switch mode {
                        case .inviteActions, .banAndPromoteActions:
                            existingPeerIds.insert(account.peerId)
                        case .searchMembers, .searchAdmins, .searchBanned, .searchKicked:
                            break
                    }
                    
                    var index = 0
                    
                    for participant in foundGroupMembers {
                        if !existingPeerIds.contains(participant.peer.id) {
                            existingPeerIds.insert(participant.peer.id)
                            let section: ChannelMembersSearchSection
                            switch mode {
                                case .inviteActions, .banAndPromoteActions:
                                    section = .members
                                case .searchBanned:
                                    section = .banned
                                case .searchMembers, .searchKicked, .searchAdmins:
                                    section = .none
                            }
                            
                            var canPromote: Bool
                            var canRestrict: Bool
                            switch participant.participant {
                                case .creator:
                                    canPromote = false
                                    canRestrict = false
                                case let .member(_, _, adminRights, bannedRights):
                                    if channel.hasPermission(.addAdmins) {
                                        canPromote = true
                                    } else {
                                        canPromote = false
                                    }
                                    if channel.hasPermission(.banMembers) {
                                        canRestrict = true
                                    } else {
                                        canRestrict = false
                                    }
                                    if canPromote {
                                        if let bannedRights = bannedRights {
                                            if bannedRights.restrictedBy != account.peerId && !channel.flags.contains(.isCreator) {
                                                canPromote = false
                                            }
                                        }
                                    }
                                    if canRestrict {
                                        if let adminRights = adminRights {
                                            if adminRights.promotedBy != account.peerId && !channel.flags.contains(.isCreator) {
                                                canRestrict = false
                                            }
                                        }
                                    }
                            }
                            
                            var label: String?
                            var enabled = true
                            if case .banAndPromoteActions = mode {
                                if case .creator = participant.participant {
                                    label = themeAndStrings.1.Channel_Management_LabelCreator
                                    enabled = false
                                }
                            } else if case .searchMembers = mode {
                                switch participant.participant {
                                    case .creator:
                                        label = themeAndStrings.1.Channel_Management_LabelCreator
                                    case let .member(member):
                                        if member.adminInfo != nil {
                                            label = themeAndStrings.1.Channel_Management_LabelEditor
                                        }
                                }
                            }
                            
                            if state.removingParticipantIds.contains(participant.peer.id) {
                                enabled = false
                            }
                            
                            var peerActions: [ParticipantRevealAction] = []
                            if case .searchMembers = mode {
                                if canPromote {
                                    peerActions.append(ParticipantRevealAction(type: .neutral, title: themeAndStrings.1.GroupInfo_ActionPromote, action: .promote))
                                }
                                if canRestrict {
                                    peerActions.append(ParticipantRevealAction(type: .warning, title: themeAndStrings.1.GroupInfo_ActionRestrict, action: .restrict))
                                    peerActions.append(ParticipantRevealAction(type: .destructive, title: themeAndStrings.1.Common_Delete, action: .remove))
                                }
                            }
                            
                            switch mode {
                                case .searchAdmins:
                                    switch participant.participant {
                                        case .creator:
                                            label = themeAndStrings.1.Channel_Management_LabelCreator
                                        case let .member(_, _, adminInfo, _):
                                            if let adminInfo = adminInfo {
                                                if let peer = participant.peers[adminInfo.promotedBy] {
                                                    label = themeAndStrings.1.Channel_Management_PromotedBy(peer.displayTitle).0
                                                }
                                            }
                                    }
                                case .searchBanned:
                                    switch participant.participant {
                                        case let .member(_, _, _, banInfo):
                                            if let banInfo = banInfo {
                                                var exceptionsString = ""
                                                for rights in allGroupPermissionList {
                                                    if banInfo.rights.flags.contains(rights) {
                                                        if !exceptionsString.isEmpty {
                                                            exceptionsString.append(", ")
                                                        }
                                                        exceptionsString.append(compactStringForGroupPermission(strings: themeAndStrings.1, right: rights))
                                                    }
                                                }
                                                label = exceptionsString
                                            }
                                        default:
                                            break
                                    }
                                case .searchKicked:
                                    switch participant.participant {
                                        case let .member(_, _, _, banInfo):
                                            if let banInfo = banInfo, let peer = participant.peers[banInfo.restrictedBy] {
                                                label = themeAndStrings.1.Channel_Management_RemovedBy(peer.displayTitle).0
                                            }
                                        default:
                                            break
                                    }
                                default:
                                    break
                            }
                            entries.append(ChannelMembersSearchEntry(index: index, content: .participant(participant: participant, label: label, revealActions: peerActions, revealed: state.revealedPeerId == participant.peer.id, enabled: enabled), section: section, dateTimeFormat: themeAndStrings.4))
                            index += 1
                        }
                    }
                    
                    for participant in foundMembers {
                        if !existingPeerIds.contains(participant.peer.id) {
                            existingPeerIds.insert(participant.peer.id)
                            let section: ChannelMembersSearchSection
                            var addIcon = false
                            switch mode {
                                case .inviteActions, .banAndPromoteActions:
                                    section = .members
                                case .searchBanned:
                                    section = .members
                                    addIcon = true
                                case .searchMembers, .searchKicked, .searchAdmins:
                                    section = .none
                            }
                            
                            var label: String?
                            var enabled = true
                            if case .banAndPromoteActions = mode {
                                if case .creator = participant.participant {
                                    label = themeAndStrings.1.Channel_Management_LabelCreator
                                    enabled = false
                                }
                            }
                            
                            entries.append(ChannelMembersSearchEntry(index: index, content: .participant(participant: participant, label: label, revealActions: [], revealed: false, enabled: enabled), section: section, dateTimeFormat: themeAndStrings.4, addIcon: addIcon))
                            index += 1
                        }
                    }
                    
                    for peer in foundContacts.0 {
                        if !existingPeerIds.contains(peer.id) {
                            existingPeerIds.insert(peer.id)
                            entries.append(ChannelMembersSearchEntry(index: index, content: .peer(peer), section: .contacts, dateTimeFormat: themeAndStrings.4))
                            index += 1
                        }
                    }
                    
                    for foundPeer in foundRemotePeers.0 {
                        let peer = foundPeer.peer
                        if !existingPeerIds.contains(peer.id) && peer is TelegramUser {
                            existingPeerIds.insert(peer.id)
                            entries.append(ChannelMembersSearchEntry(index: index, content: .peer(peer), section: .global, dateTimeFormat: themeAndStrings.4))
                            index += 1
                        }
                    }
                    
                    for foundPeer in foundRemotePeers.1 {
                        let peer = foundPeer.peer
                        if !existingPeerIds.contains(peer.id) && peer is TelegramUser {
                            existingPeerIds.insert(peer.id)
                            entries.append(ChannelMembersSearchEntry(index: index, content: .peer(peer), section: .global, dateTimeFormat: themeAndStrings.4))
                            index += 1
                        }
                    }
                    
                    return entries
                }
            } else {
                return .single(nil)
            }
        }
        
        let previousSearchItems = Atomic<[ChannelMembersSearchEntry]?>(value: nil)

        self.searchDisposable.set((combineLatest(foundItems, self.themeAndStringsPromise.get())
            |> deliverOnMainQueue).start(next: { [weak self] entries, themeAndStrings in
                if let strongSelf = self {
                    let previousEntries = previousSearchItems.swap(entries)
                    updateActivity(false)
                    let firstTime = previousEntries == nil
                    let transition = channelMembersSearchContainerPreparedRecentTransition(from: previousEntries ?? [], to: entries ?? [], isSearching: entries != nil, account: account, theme: themeAndStrings.0, strings: themeAndStrings.1, nameSortOrder: themeAndStrings.2, nameDisplayOrder: themeAndStrings.3, interaction: interaction)
                    strongSelf.enqueueTransition(transition, firstTime: firstTime)
                }
            }))
        
        self.presentationDataDisposable = (account.telegramApplicationContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings(theme: presentationData.theme, strings: presentationData.strings)
                }
            }
        })
        
        self.listNode.beganInteractiveDragging = { [weak self] in
            self?.dismissInput?()
        }
    }
    
    deinit {
        self.searchDisposable.dispose()
        self.presentationDataDisposable?.dispose()
        self.removeMemberDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
    }
    
    private func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.listNode.backgroundColor = theme.chatList.backgroundColor
    }
    
    override func searchTextUpdated(text: String) {
        if text.isEmpty {
            self.searchQuery.set(.single(nil))
        } else {
            self.searchQuery.set(.single(text))
        }
    }
    
    private func enqueueTransition(_ transition: ChannelMembersSearchContainerTransition, firstTime: Bool) {
        enqueuedTransitions.append((transition, firstTime))
        
        if self.hasValidLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let (transition, firstTime) = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            options.insert(.PreferSynchronousDrawing)
            options.insert(.PreferSynchronousResourceLoading)
            if firstTime {
            } else {
                //options.insert(.AnimateAlpha)
            }
            
            let isSearching = transition.isSearching
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                self?.listNode.isHidden = !isSearching
                self?.dimNode.isHidden = isSearching
            })
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        let topInset = navigationBarHeight
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: layout.size.width, height: layout.size.height - topInset)))
        
        var duration: Double = 0.0
        var curve: UInt = 0
        switch transition {
            case .immediate:
                break
            case let .animated(animationDuration, animationCurve):
                duration = animationDuration
                switch animationCurve {
                    case .easeInOut:
                        break
                    case .spring:
                        curve = 7
                }
        }
        
        let listViewCurve: ListViewAnimationCurve
        if curve == 7 {
            listViewCurve = .Spring(duration: duration)
        } else {
            listViewCurve = .Default(duration: nil)
        }
        
        self.listNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: navigationBarHeight, left: 0.0, bottom: layout.insets(options: [.input]).bottom, right: 0.0), duration: duration, curve: listViewCurve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !hasValidLayout {
            hasValidLayout = true
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancel?()
        }
    }
}
